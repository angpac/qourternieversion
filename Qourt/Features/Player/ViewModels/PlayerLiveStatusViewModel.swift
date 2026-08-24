//
//  PlayerLiveStatusViewModel.swift
//  Qourt
//

import Foundation
import Supabase

struct PlayerMatchScore: Identifiable {
    let id: UUID
    let scoreA: Int
    let scoreB: Int
    let myTeam: String
    let opponentNames: String
    var won: Bool { myTeam == "a" ? scoreA > scoreB : scoreB > scoreA }
    var myScore: Int { myTeam == "a" ? scoreA : scoreB }
    var opponentScore: Int { myTeam == "a" ? scoreB : scoreA }
}

@Observable
final class PlayerLiveStatusViewModel {
    let game: Game

    var myPlayer: GamePlayer?
    var queuePosition: Int?
    var queuedPlayers: [GamePlayer] = []
    var myCourt: Court?
    var currentMatch: MatchWithPlayers?
    var myMatches: [PlayerMatchScore] = []
    var announcements: [Announcement] = []
    var prepEndsAt: Date?
    var errorMessage: String?
    var isLoading = true
    var isConnected = true
    var isStartingPickerMatch = false

    /// Peg Board only: the player at the front of the queue picks 3 others
    /// to build a match, so this is a player action, not an admin one.
    var isPicker: Bool {
        game.format == .pegBoard && myPlayer?.status == .queued && queuedPlayers.first?.id == myPlayer?.id
    }

    var pickerPool: [GamePlayer] {
        Array(queuedPlayers.dropFirst().prefix(game.pickerPoolSize))
    }

    /// How many players (including the Picker) the match about to be built
    /// needs, doubled minus one for the "picker + N others" shape:
    /// 3 for a doubles court (1 partner + 2 opponents), 1 for a singles
    /// court (just the opponent). Mirrors the server's own court-selection
    /// logic — same lowest-position open court, same singles_override
    /// fallback to the game's overall setting — so what's shown here always
    /// matches what pick_board_start_match will actually require.
    var pickerTeammatesNeeded: Int = 3

    @MainActor
    private func loadPickerRequiredTeammates() async {
        struct CourtRow: Decodable {
            let id: UUID
            let position: Int
            let singles_override: Bool?
        }
        let courts: [CourtRow] = (try? await supabase.from("courts")
            .select("id, position, singles_override")
            .eq("game_id", value: game.id)
            .order("position")
            .execute()
            .value) ?? []

        struct MatchRow: Decodable { let court_id: UUID? }
        let activeMatches: [MatchRow] = (try? await supabase.from("matches")
            .select("court_id")
            .eq("game_id", value: game.id)
            .in("status", values: [MatchStatus.inProgress.rawValue, MatchStatus.awaitingConfirmation.rawValue])
            .execute()
            .value) ?? []
        let busyCourtIDs = Set(activeMatches.compactMap(\.court_id))

        let nextCourt = courts.first { !busyCourtIDs.contains($0.id) }
        let required: Int
        if let override = nextCourt?.singles_override {
            required = override ? 1 : 2
        } else {
            required = game.isDoubles ? 2 : 1
        }
        pickerTeammatesNeeded = 2 * required - 1
    }

    /// A rough "how many matches until mine" hint, on top of the raw
    /// individual queue position — useful for doubles, where "#7 in line"
    /// alone doesn't say much. Skipped for Peg Board: the Picker chooses
    /// from a pool further down the line rather than the next N players in
    /// order, so "the next 4 are a match" doesn't hold there.
    var groupsAheadText: String? {
        guard game.format != .pegBoard, let position = queuePosition else { return nil }
        let matchSize = game.isDoubles ? 4 : 2
        let groupsAhead = (position - 1) / matchSize
        guard groupsAhead >= 1 else { return nil }
        return "About \(groupsAhead) more match\(groupsAhead == 1 ? "" : "es") before yours"
    }

    var gameStatus: String
    var isPaused: Bool { gameStatus == "paused" }
    var hasEnded: Bool { gameStatus == "ended" }

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeSubscriptions: [RealtimeSubscription] = []
    private var connectionObserverTask: Task<Void, Never>?

    init(game: Game) {
        self.game = game
        self.gameStatus = game.status
    }

    @MainActor
    func start() async {
        await loadAll()
        await subscribeToChanges()
    }

    func stop() {
        realtimeSubscriptions.forEach { $0.cancel() }
        realtimeSubscriptions.removeAll()
        Task { await realtimeChannel?.unsubscribe() }
        connectionObserverTask?.cancel()
        connectionObserverTask = nil
    }

    @MainActor
    func loadAll() async {
        // Only the very first load should hide the screen behind a
        // spinner — `isLoading` already starts `true` for that. Every
        // later call (a realtime update on a score, a pull-to-refresh,
        // etc.) reuses the screen that's already showing and just updates
        // the data in place; re-flipping isLoading here made every one of
        // those reloads blank the whole screen out and back in, not just
        // the score that actually changed.
        defer { isLoading = false }

        guard let userID = (try? await supabase.auth.session)?.user.id else { return }

        struct StatusRow: Decodable { let status: String }
        if let row: StatusRow = try? await supabase.from("games")
            .select("status")
            .eq("id", value: game.id)
            .single()
            .execute()
            .value {
            gameStatus = row.status
        }

        do {
            let player: GamePlayer? = try await supabase.from("game_players")
                .select()
                .eq("game_id", value: game.id)
                .eq("profile_id", value: userID)
                .single()
                .execute()
                .value
            myPlayer = player

            guard let player else { return }

            switch player.status {
            case .queued:
                let queue = try await loadQueue()
                queuedPlayers = queue
                queuePosition = queue.firstIndex(where: { $0.id == player.id }).map { $0 + 1 }
                myCourt = nil
                currentMatch = nil
            case .onCourt:
                queuePosition = nil
                queuedPlayers = []
                await loadCurrentMatch(for: player)
            case .resting, .removed, .pending:
                queuePosition = nil
                queuedPlayers = []
                myCourt = nil
                currentMatch = nil
            }

            await loadMyMatches(for: player)
            await loadAnnouncements(for: player)
            if game.format == .kingOfTheCourt {
                await loadPrepEndsAt()
            }
            if isPicker {
                await loadPickerRequiredTeammates()
            }
            await syncLiveActivity(for: player)
        } catch is CancellationError {
            // Superseded by a newer load (e.g. pull-to-refresh interrupted
            // by a realtime-triggered reload) — leave state as-is rather
            // than blanking it out or surfacing a bogus error.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// King of the Court only: whether the "get to your court" buffer is
    /// currently running, so every player (not just the admin) sees the
    /// same countdown before a round's timer actually starts.
    @MainActor
    private func loadPrepEndsAt() async {
        struct PrepRow: Decodable { let prep_ends_at: Date? }
        let row: PrepRow? = try? await supabase.from("games")
            .select("prep_ends_at")
            .eq("id", value: game.id)
            .single()
            .execute()
            .value
        prepEndsAt = row?.prep_ends_at
    }

    /// Starts/updates/ends the Lock Screen + Dynamic Island Live Activity
    /// to mirror whatever this screen is showing. Starting/updating while
    /// the app is foregrounded is free; staying live while backgrounded
    /// depends on the activity's push token reaching the server (uploaded
    /// once ActivityKit hands it back), which the "you're up!" push
    /// already piggybacks an update onto.
    @MainActor
    private func syncLiveActivity(for player: GamePlayer) async {
        switch player.status {
        case .queued:
            let state = PlayerActivityAttributes.ContentState(
                status: "queued",
                queuePosition: queuePosition,
                courtName: nil,
                teammateNames: nil,
                opponentNames: nil,
                scoreA: nil,
                scoreB: nil
            )
            LiveActivityManager.start(gameName: game.name, state: state, gamePlayerID: player.id)
        case .onCourt:
            guard let match = currentMatch else { return }
            let onTeamA = match.teamA.contains { $0.id == player.id }
            let teammates = (onTeamA ? match.teamA : match.teamB).filter { $0.id != player.id }
            let opponents = onTeamA ? match.teamB : match.teamA
            let state = PlayerActivityAttributes.ContentState(
                status: "onCourt",
                queuePosition: nil,
                courtName: myCourt?.name,
                teammateNames: teammates.isEmpty ? "You" : "You & " + teammates.map(\.displayName).joined(separator: " & "),
                opponentNames: opponents.map(\.displayName).joined(separator: " & "),
                scoreA: match.match.scoreA,
                scoreB: match.match.scoreB
            )
            LiveActivityManager.start(gameName: game.name, state: state, gamePlayerID: player.id)
        case .resting, .removed, .pending:
            await LiveActivityManager.end()
        }
    }

    @MainActor
    private func loadAnnouncements(for player: GamePlayer) async {
        announcements = (try? await supabase.from("announcements")
            .select()
            .eq("game_id", value: game.id)
            .or("target_player_id.is.null,target_player_id.eq.\(player.id)")
            .order("sent_at", ascending: false)
            .limit(10)
            .execute()
            .value) ?? []
    }

    /// Every confirmed match this player has played in this game, most
    /// recent first — queried from `matches` directly (not `match_players`)
    /// so `started_at` is a plain column on the table being ordered, same
    /// fix as elsewhere: ordering by an *embedded* table's column returned
    /// rows in an unreliable order.
    @MainActor
    private func loadMyMatches(for player: GamePlayer) async {
        struct TeamOnly: Decodable { let team: String }
        struct MyMatchQueryRow: Decodable {
            let id: UUID
            let score_a: Int?
            let score_b: Int?
            let match_players: [TeamOnly]
        }

        let matches: [MyMatchQueryRow] = (try? await supabase.from("matches")
            .select("id, score_a, score_b, match_players!inner(team)")
            .eq("match_players.game_player_id", value: player.id)
            .eq("status", value: MatchStatus.confirmed.rawValue)
            .order("started_at", ascending: false)
            .execute()
            .value) ?? []

        guard !matches.isEmpty else {
            myMatches = []
            return
        }

        struct NameOnly: Decodable {
            let id: UUID
            let display_name: String
        }
        struct AllPlayersRow: Decodable {
            let match_id: UUID
            let team: String
            let game_players: NameOnly
        }
        let allRows: [AllPlayersRow] = (try? await supabase.from("match_players")
            .select("match_id, team, game_players(id, display_name)")
            .in("match_id", values: matches.map(\.id))
            .execute()
            .value) ?? []

        myMatches = matches.compactMap { match in
            guard let scoreA = match.score_a, let scoreB = match.score_b,
                  let myTeam = match.match_players.first?.team else { return nil }
            let opponentTeam = myTeam == "a" ? "b" : "a"
            let opponentNames = allRows
                .filter { $0.match_id == match.id && $0.team == opponentTeam }
                .map(\.game_players.display_name)
                .joined(separator: " & ")
            return PlayerMatchScore(id: match.id, scoreA: scoreA, scoreB: scoreB, myTeam: myTeam, opponentNames: opponentNames)
        }
    }

    @MainActor
    func stepOut() async {
        guard let player = myPlayer else { return }
        do {
            try await supabase.from("game_players")
                .update(["status": PlayerStatus.resting.rawValue])
                .eq("id", value: player.id)
                .execute()
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func stepBackIn() async {
        guard let player = myPlayer else { return }
        let position = await nextQueuePosition()
        do {
            try await supabase.from("game_players")
                .update([
                    "status": AnyJSON.string(PlayerStatus.queued.rawValue),
                    "queue_position": AnyJSON.integer(position)
                ])
                .eq("id", value: player.id)
                .execute()
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func leaveGame() async {
        guard let player = myPlayer else { return }
        do {
            try await supabase.from("game_players")
                .update(["status": PlayerStatus.removed.rawValue])
                .eq("id", value: player.id)
                .execute()
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func nextQueuePosition() async -> Int {
        struct PositionRow: Decodable { let queue_position: Int? }
        let rows: [PositionRow] = (try? await supabase.from("game_players")
            .select("queue_position")
            .eq("game_id", value: game.id)
            .execute()
            .value) ?? []
        return (rows.compactMap(\.queue_position).max() ?? -1) + 1
    }

    private func loadQueue() async throws -> [GamePlayer] {
        try await supabase.from("game_players")
            .select()
            .eq("game_id", value: game.id)
            .eq("status", value: PlayerStatus.queued.rawValue)
            .order("queue_position", ascending: true, nullsFirst: false)
            .order("joined_at", ascending: true)
            .execute()
            .value
    }

    @MainActor
    func startPickerMatch(teammateIDs: [UUID]) async -> Bool {
        isStartingPickerMatch = true
        defer { isStartingPickerMatch = false }
        struct Params: Encodable {
            let p_game_id: UUID
            let p_teammate_ids: [UUID]
        }
        do {
            try await supabase.rpc("pick_board_start_match", params: Params(p_game_id: game.id, p_teammate_ids: teammateIDs)).execute()
            await loadAll()
            return true
        } catch let error as PostgrestError {
            errorMessage = error.message
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    private func loadCurrentMatch(for player: GamePlayer) async {
        struct MatchPlayerRow: Decodable {
            let match_id: UUID
            let team: String
            let game_players: GamePlayer
        }

        do {
            // A player accumulates one match_players row per match they've
            // ever played in this game — filtering to only the still-active
            // one server-side (rather than fetching every historical row
            // and grabbing `.first`) is what makes this find the *current*
            // match instead of whichever one happened to sort first, which
            // was almost always the first match they ever played here.
            struct MyActiveMatchRow: Decodable { let match_id: UUID }
            let myActiveRows: [MyActiveMatchRow] = try await supabase.from("match_players")
                .select("match_id, matches!inner(status)")
                .eq("game_player_id", value: player.id)
                .in("matches.status", values: [MatchStatus.inProgress.rawValue, MatchStatus.awaitingConfirmation.rawValue])
                .execute()
                .value

            guard let myMatchId = myActiveRows.first?.match_id else {
                currentMatch = nil
                myCourt = nil
                return
            }

            let match: Match = try await supabase.from("matches")
                .select()
                .eq("id", value: myMatchId)
                .single()
                .execute()
                .value

            let rows: [MatchPlayerRow] = try await supabase.from("match_players")
                .select("match_id, team, game_players(*)")
                .eq("match_id", value: match.id)
                .execute()
                .value

            let teamA = rows.filter { $0.team == "a" }.map(\.game_players)
            let teamB = rows.filter { $0.team == "b" }.map(\.game_players)
            currentMatch = MatchWithPlayers(match: match, teamA: teamA, teamB: teamB)

            if let courtId = match.courtId {
                myCourt = try? await supabase.from("courts")
                    .select()
                    .eq("id", value: courtId)
                    .single()
                    .execute()
                    .value
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func reportScore(scoreA: Int, scoreB: Int) async {
        guard let match = currentMatch?.match,
              let userID = (try? await supabase.auth.session)?.user.id else { return }

        do {
            try await supabase.from("matches")
                .update([
                    "score_a": AnyJSON.integer(scoreA),
                    "score_b": AnyJSON.integer(scoreB),
                    "status": AnyJSON.string(MatchStatus.awaitingConfirmation.rawValue),
                    "reported_by": AnyJSON.string(userID.uuidString)
                ])
                .eq("id", value: match.id)
                .execute()
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func subscribeToChanges() async {
        let channel = supabase.realtimeV2.channel("player-game-\(game.id)")
        realtimeChannel = channel

        let filter = "game_id=eq.\(game.id)"
        for table in ["game_players", "matches", "match_players", "announcements"] {
            let subscription = channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: table,
                filter: table == "match_players" ? nil : filter
            ) { [weak self] _ in
                Task { await self?.loadAll() }
            }
            realtimeSubscriptions.append(subscription)
        }

        // Separate filter since games' own primary key is "id", not
        // "game_id" — needed so the King of the Court prep countdown
        // updates live as the admin's device drives it.
        let gamesSubscription = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "games",
            filter: "id=eq.\(game.id)"
        ) { [weak self] _ in
            Task { await self?.loadAll() }
        }
        realtimeSubscriptions.append(gamesSubscription)

        connectionObserverTask?.cancel()
        connectionObserverTask = Task { [weak self] in
            for await status in channel.statusChange {
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.isConnected = (status == .subscribed) }
            }
        }

        try? await channel.subscribeWithError()
    }
}
