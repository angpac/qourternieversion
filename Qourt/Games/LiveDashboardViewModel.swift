//
//  LiveDashboardViewModel.swift
//  Qourt
//

import Foundation
import Supabase

@Observable
final class LiveDashboardViewModel {
    let game: Game

    var courts: [Court] = []
    var queue: [GamePlayer] = []
    var fullRoster: [GamePlayer] = []
    var activeMatches: [UUID: MatchWithPlayers] = [:] // keyed by court id
    var errorMessage: String?
    var isLoading = true
    var gameStatus: String
    var roundStartedAt: Date?
    var isRotating = false
    var isConnected = true

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeSubscriptions: [RealtimeSubscription] = []
    private var roundTimerTask: Task<Void, Never>?
    private var connectionObserverTask: Task<Void, Never>?

    init(game: Game) {
        self.game = game
        self.gameStatus = game.status
        self.roundStartedAt = game.currentRoundStartedAt
    }

    var hasEnded: Bool { gameStatus == "ended" }
    var isKingOfTheCourt: Bool { game.format == .kingOfTheCourt }

    var roundEndsAt: Date? {
        guard let roundStartedAt else { return nil }
        return roundStartedAt.addingTimeInterval(TimeInterval(game.roundMinutes * 60))
    }

    @MainActor
    func endGame() async {
        do {
            try await supabase.from("games")
                .update(["status": "ended"])
                .eq("id", value: game.id)
                .execute()
            gameStatus = "ended"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func start() async {
        await loadAll()
        await subscribeToChanges()
        if isKingOfTheCourt {
            startRoundTimerLoop()
        }
    }

    func stop() {
        realtimeSubscriptions.forEach { $0.cancel() }
        realtimeSubscriptions.removeAll()
        Task { await realtimeChannel?.unsubscribe() }
        roundTimerTask?.cancel()
        roundTimerTask = nil
        connectionObserverTask?.cancel()
        connectionObserverTask = nil
    }

    /// Checks once a second whether the King of the Court round has expired.
    /// There's no server-side scheduler in this project, so automatic
    /// rotation only fires while an admin's dashboard is open — the client
    /// that notices expiry performs it. Manual "End round now" covers the
    /// gap when no dashboard is open.
    private func startRoundTimerLoop() {
        roundTimerTask?.cancel()
        roundTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                await self.checkRoundExpiry()
            }
        }
    }

    @MainActor
    private func checkRoundExpiry() async {
        guard game.autoRotate, !isRotating, let roundEndsAt, Date() >= roundEndsAt else { return }
        await rotateKingOfTheCourt()
    }

    @MainActor
    func loadAll() async {
        isLoading = true
        async let courtsFetch: [Court] = (try? await supabase.from("courts")
            .select()
            .eq("game_id", value: game.id)
            .order("position")
            .execute()
            .value) ?? []

        async let queueFetch: [GamePlayer] = (try? await supabase.from("game_players")
            .select()
            .eq("game_id", value: game.id)
            .eq("status", value: PlayerStatus.queued.rawValue)
            .order("queue_position", ascending: true, nullsFirst: false)
            .order("joined_at", ascending: true)
            .execute()
            .value) ?? []

        async let rosterFetch: [GamePlayer] = (try? await supabase.from("game_players")
            .select()
            .eq("game_id", value: game.id)
            .neq("status", value: PlayerStatus.removed.rawValue)
            .order("joined_at", ascending: true)
            .execute()
            .value) ?? []

        courts = await courtsFetch
        queue = await queueFetch
        fullRoster = await rosterFetch
        await loadActiveMatches()
        if isKingOfTheCourt {
            await refreshRoundStartedAt()
        }
        isLoading = false
        await tryAutoFillOpenCourts()
    }

    private var isAutoFilling = false

    /// The "manually match players" toggle from game setup: when it's off
    /// (the default), an open court with enough players queued should fill
    /// itself instead of sitting empty until an admin taps it — that's the
    /// promise made on the setup screen ("the app pairing players
    /// automatically"). Peg Board is exempt: its Picker is the one who
    /// builds each match, never an automatic process.
    @MainActor
    private func tryAutoFillOpenCourts() async {
        guard !isAutoFilling, !game.manualMatching, game.format != .pegBoard, !hasEnded else { return }

        let openCourts = courts
            .filter { activeMatches[$0.id] == nil }
            .sorted { $0.position < $1.position }
        guard !openCourts.isEmpty else { return }

        isAutoFilling = true
        defer { isAutoFilling = false }

        var availableQueue = queue
        for court in openCourts {
            let required = playersPerTeam(for: court)
            guard availableQueue.count >= required * 2 else { break }
            let teamA = Array(availableQueue.prefix(required))
            let teamB = Array(availableQueue.dropFirst(required).prefix(required))
            availableQueue.removeFirst(required * 2)
            await startMatch(court: court, teamA: teamA, teamB: teamB)
        }
    }

    @MainActor
    private func refreshRoundStartedAt() async {
        struct RoundRow: Decodable { let current_round_started_at: Date? }
        let row: RoundRow? = try? await supabase.from("games")
            .select("current_round_started_at")
            .eq("id", value: game.id)
            .single()
            .execute()
            .value
        roundStartedAt = row?.current_round_started_at
    }

    @MainActor
    private func loadActiveMatches() async {
        struct MatchPlayerRow: Decodable {
            let match_id: UUID
            let team: String
            let game_players: GamePlayer
        }

        do {
            let matches: [Match] = try await supabase.from("matches")
                .select()
                .eq("game_id", value: game.id)
                .in("status", values: [MatchStatus.inProgress.rawValue, MatchStatus.awaitingConfirmation.rawValue])
                .execute()
                .value

            guard !matches.isEmpty else {
                activeMatches = [:]
                return
            }

            let matchIDs = matches.map(\.id)
            let rows: [MatchPlayerRow] = try await supabase.from("match_players")
                .select("match_id, team, game_players(*)")
                .in("match_id", values: matchIDs)
                .execute()
                .value

            var result: [UUID: MatchWithPlayers] = [:]
            for match in matches {
                guard let courtId = match.courtId else { continue }
                let players = rows.filter { $0.match_id == match.id }
                let teamA = players.filter { $0.team == "a" }.map(\.game_players)
                let teamB = players.filter { $0.team == "b" }.map(\.game_players)
                result[courtId] = MatchWithPlayers(match: match, teamA: teamA, teamB: teamB)
            }
            activeMatches = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func subscribeToChanges() async {
        let channel = supabase.realtimeV2.channel("game-\(game.id)")
        realtimeChannel = channel

        let filter = "game_id=eq.\(game.id)"
        for table in ["game_players", "matches", "match_players", "courts"] {
            let subscription = channel.onPostgresChange(AnyAction.self, schema: "public", table: table, filter: table == "match_players" ? nil : filter) { [weak self] _ in
                Task { await self?.loadAll() }
            }
            realtimeSubscriptions.append(subscription)
        }

        // Separate filter since games' own primary key is "id", not "game_id" —
        // needed to see another admin's device start/rotate the round timer.
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

        await channel.subscribe()
    }

    @MainActor
    func createMissingCourts() async {
        do {
            try await supabase.from("courts").insert(CreateGameViewModel.newCourtRows(for: game)).execute()
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func addWalkIn(name: String, skillLevel: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        struct NewWalkIn: Encodable {
            let game_id: UUID
            let display_name: String
            let skill_level: String
            let queue_position: Int
        }

        let newWalkIn = NewWalkIn(
            game_id: game.id,
            display_name: trimmed,
            skill_level: skillLevel,
            queue_position: await nextQueuePosition()
        )

        do {
            try await supabase.from("game_players").insert(newWalkIn).execute()
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

    var playersNeededPerMatch: Int {
        game.isDoubles ? 4 : 2
    }

    var playersPerTeam: Int { playersNeededPerMatch / 2 }

    /// A lane-split court (Half-Court Kingminton) is always 1v1 singles,
    /// regardless of whether the game overall was set up as doubles.
    func playersPerTeam(for court: Court) -> Int {
        court.isLaneSplit ? 1 : playersPerTeam
    }

    @MainActor
    func startMatch(court: Court, teamA: [GamePlayer], teamB: [GamePlayer]) async {
        let required = playersPerTeam(for: court)
        guard teamA.count == required, teamB.count == required else { return }

        struct NewMatch: Encodable {
            let game_id: UUID
            let court_id: UUID
            let status: String
        }

        do {
            let match: Match = try await supabase.from("matches")
                .insert(NewMatch(game_id: game.id, court_id: court.id, status: MatchStatus.inProgress.rawValue))
                .select()
                .single()
                .execute()
                .value

            let matchPlayers = teamA.map { MatchPlayer(matchId: match.id, gamePlayerId: $0.id, team: "a") }
                + teamB.map { MatchPlayer(matchId: match.id, gamePlayerId: $0.id, team: "b") }
            try await supabase.from("match_players").insert(matchPlayers).execute()

            let playerIDs = (teamA + teamB).map(\.id)
            try await supabase.from("game_players")
                .update(["status": PlayerStatus.onCourt.rawValue])
                .in("id", values: playerIDs)
                .execute()

            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func updateScore(matchID: UUID, scoreA: Int, scoreB: Int) async {
        do {
            try await supabase.from("matches")
                .update([
                    "score_a": AnyJSON.integer(scoreA),
                    "score_b": AnyJSON.integer(scoreB)
                ])
                .eq("id", value: matchID)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func endMatch(_ matchWithPlayers: MatchWithPlayers, scoreA: Int, scoreB: Int) async {
        do {
            try await supabase.from("matches")
                .update([
                    "status": AnyJSON.string(MatchStatus.confirmed.rawValue),
                    "score_a": AnyJSON.integer(scoreA),
                    "score_b": AnyJSON.integer(scoreB),
                    "ended_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
                ])
                .eq("id", value: matchWithPlayers.match.id)
                .execute()

            let court = courts.first(where: { $0.id == matchWithPlayers.match.courtId })
            if let court, court.isChallengeCourt || court.isLaneSplit {
                // Challenge Court has an explicit win cap; Half-Court
                // Kingminton has none — the winner just keeps defending
                // the lane until someone finally beats them.
                let winCap: Int? = court.isChallengeCourt ? challengeCourtWinCap : nil
                await handleWinnerStaysResult(court: court, match: matchWithPlayers, scoreA: scoreA, scoreB: scoreB, winCap: winCap)
            } else {
                let allPlayers = matchWithPlayers.teamA + matchWithPlayers.teamB
                // An admin may have paused/removed one of these players while
                // the match was still live — trust the live status, not this
                // stale snapshot, so we don't silently resurrect them into
                // the queue.
                let stillOnCourt = await liveOnCourtIDs(among: allPlayers.map(\.id))
                if !stillOnCourt.isEmpty {
                    let backOfQueue = await nextQueuePosition()
                    try await supabase.from("game_players")
                        .update([
                            "status": AnyJSON.string(PlayerStatus.queued.rawValue),
                            "queue_position": AnyJSON.integer(backOfQueue)
                        ])
                        .in("id", values: Array(stillOnCourt))
                        .execute()
                }
            }

            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Re-reads current status for these players so end-of-match/rotation
    /// logic only requeues players who are still actually on court — an
    /// admin may have paused or removed one of them mid-match via the
    /// Roster, and that decision must win over this match's stale snapshot.
    private func liveOnCourtIDs(among ids: [UUID]) async -> Set<UUID> {
        guard !ids.isEmpty else { return [] }
        struct StatusRow: Decodable { let id: UUID; let status: PlayerStatus }
        let rows: [StatusRow] = (try? await supabase.from("game_players")
            .select("id, status")
            .in("id", values: ids)
            .execute()
            .value) ?? []
        return Set(rows.filter { $0.status == .onCourt }.map(\.id))
    }

    private var challengeCourtWinCap: Int {
        if case let .integer(value)? = game.formatSettings["win_cap"] { return value }
        return 3
    }

    /// Shared by Challenge Court (winCap set — defenders step off once they
    /// hit it) and Half-Court Kingminton lanes (winCap nil — the winner just
    /// keeps defending indefinitely): the winning side stays on the
    /// court/lane, the loser returns to the queue, and a new challenger is
    /// pulled from the front of the queue to fill their spot immediately.
    @MainActor
    private func handleWinnerStaysResult(court: Court, match: MatchWithPlayers, scoreA: Int, scoreB: Int, winCap: Int?) async {
        let aWon = scoreA > scoreB
        let winners = aWon ? match.teamA : match.teamB
        let losers = aWon ? match.teamB : match.teamA
        let newStreak = court.winStreak + 1
        let required = playersPerTeam(for: court)

        // An admin may have paused/removed one of these players while the
        // match was still live — only requeue whoever the live status still
        // says is on court, and never trust this stale team snapshot.
        let stillOnCourt = await liveOnCourtIDs(among: (winners + losers).map(\.id))
        let effectiveWinners = winners.filter { stillOnCourt.contains($0.id) }
        let effectiveLosers = losers.filter { stillOnCourt.contains($0.id) }

        do {
            let backOfQueue = await nextQueuePosition()
            let capHit = winCap.map { newStreak >= $0 } ?? false
            // A defender pulled mid-match by the admin leaves the winning
            // side short a player — they can't keep defending either, so
            // treat that exactly like hitting the win cap.
            let winnersBroken = effectiveWinners.count < required
            if capHit || winnersBroken {
                let requeueIDs = (effectiveWinners + effectiveLosers).map(\.id)
                if !requeueIDs.isEmpty {
                    try await supabase.from("game_players")
                        .update([
                            "status": AnyJSON.string(PlayerStatus.queued.rawValue),
                            "queue_position": AnyJSON.integer(backOfQueue)
                        ])
                        .in("id", values: requeueIDs)
                        .execute()
                }
                try await supabase.from("courts")
                    .update(["win_streak": 0])
                    .eq("id", value: court.id)
                    .execute()
                return
            }

            // Loser returns to queue; winner stays and defends against the
            // next challenger pulled from the front of the queue.
            if !effectiveLosers.isEmpty {
                try await supabase.from("game_players")
                    .update([
                        "status": AnyJSON.string(PlayerStatus.queued.rawValue),
                        "queue_position": AnyJSON.integer(backOfQueue)
                    ])
                    .in("id", values: effectiveLosers.map(\.id))
                    .execute()
            }

            let winners = effectiveWinners
            let challengers = Array(queue.filter { player in !winners.contains { $0.id == player.id } }.prefix(required))
            guard challengers.count == required else {
                // Not enough players waiting — defender just waits with an
                // open spot until someone joins the queue.
                try await supabase.from("courts")
                    .update(["win_streak": newStreak])
                    .eq("id", value: court.id)
                    .execute()
                return
            }

            struct NewMatch: Encodable {
                let game_id: UUID
                let court_id: UUID
                let status: String
            }
            let newMatch: Match = try await supabase.from("matches")
                .insert(NewMatch(game_id: game.id, court_id: court.id, status: MatchStatus.inProgress.rawValue))
                .select()
                .single()
                .execute()
                .value

            let matchPlayers = winners.map { MatchPlayer(matchId: newMatch.id, gamePlayerId: $0.id, team: "a") }
                + challengers.map { MatchPlayer(matchId: newMatch.id, gamePlayerId: $0.id, team: "b") }
            try await supabase.from("match_players").insert(matchPlayers).execute()

            try await supabase.from("game_players")
                .update(["status": PlayerStatus.onCourt.rawValue])
                .in("id", values: challengers.map(\.id))
                .execute()

            try await supabase.from("courts")
                .update(["win_streak": newStreak])
                .eq("id", value: court.id)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - King of the Court round timer

    @MainActor
    func startRound() async {
        do {
            let now = Date()
            try await supabase.from("games")
                .update(["current_round_started_at": ISO8601DateFormatter().string(from: now)])
                .eq("id", value: game.id)
                .execute()
            roundStartedAt = now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Winner of each court moves up one court, loser moves down one court.
    /// Courts are ranked by `position` (0 = bottom); clamping the new
    /// position at the top/bottom naturally implements "the King's Court
    /// winner stays" and "the Bottom Court loser stays" as the same rule.
    /// A tie is scored as a win for team A — arbitrary but deterministic,
    /// since King of the Court has no point target to break a tie by.
    @MainActor
    func rotateKingOfTheCourt() async {
        guard !isRotating else { return }
        isRotating = true
        defer { isRotating = false }

        let matchesByCourt = activeMatches
        guard !matchesByCourt.isEmpty else {
            await startRound()
            return
        }
        let sortedCourts = courts.sorted { $0.position < $1.position }

        struct TeamMove {
            let players: [GamePlayer]
            let newCourtID: UUID
        }
        var moves: [TeamMove] = []

        for (courtID, match) in matchesByCourt {
            guard let courtIndex = sortedCourts.firstIndex(where: { $0.id == courtID }) else { continue }
            let scoreA = match.match.scoreA ?? 0
            let scoreB = match.match.scoreB ?? 0
            let aWins = scoreA >= scoreB

            let winnerTeam = aWins ? match.teamA : match.teamB
            let loserTeam = aWins ? match.teamB : match.teamA

            let winnerCourt = sortedCourts[min(courtIndex + 1, sortedCourts.count - 1)]
            let loserCourt = sortedCourts[max(courtIndex - 1, 0)]

            moves.append(TeamMove(players: winnerTeam, newCourtID: winnerCourt.id))
            moves.append(TeamMove(players: loserTeam, newCourtID: loserCourt.id))
        }

        do {
            // End every match this round covered before starting the next one.
            for match in matchesByCourt.values {
                try await supabase.from("matches")
                    .update([
                        "status": AnyJSON.string(MatchStatus.confirmed.rawValue),
                        "ended_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
                    ])
                    .eq("id", value: match.match.id)
                    .execute()
            }

            // An admin may have paused/removed one of these players mid-round
            // — a team missing a player can't rotate onto a new court, so
            // drop that whole team's move and send whoever's left in it back
            // to the queue instead of silently pairing them up short-handed.
            let allMovedIDs = moves.flatMap { $0.players.map(\.id) }
            let stillOnCourt = await liveOnCourtIDs(among: allMovedIDs)
            var strandedIDs: [UUID] = []
            let filteredMoves = moves.map { move -> TeamMove in
                let effective = move.players.filter { stillOnCourt.contains($0.id) }
                if effective.count != move.players.count {
                    strandedIDs.append(contentsOf: effective.map(\.id))
                    return TeamMove(players: [], newCourtID: move.newCourtID)
                }
                return TeamMove(players: effective, newCourtID: move.newCourtID)
            }
            if !strandedIDs.isEmpty {
                let backOfQueue = await nextQueuePosition()
                try await supabase.from("game_players")
                    .update([
                        "status": AnyJSON.string(PlayerStatus.queued.rawValue),
                        "queue_position": AnyJSON.integer(backOfQueue)
                    ])
                    .in("id", values: strandedIDs)
                    .execute()
            }

            // Group the moved teams by their new court — a middle court
            // always ends up with exactly two incoming teams (one moving up
            // from below, one moving down from above); the top/bottom
            // courts get their defender/stayer plus one incoming team.
            let movesByCourt = Dictionary(grouping: filteredMoves, by: \.newCourtID)
            for (courtID, courtMoves) in movesByCourt {
                let teamA = courtMoves.first?.players ?? []
                let teamB = courtMoves.count > 1 ? courtMoves[1].players : []
                guard !teamA.isEmpty, !teamB.isEmpty else { continue }

                let newMatch: Match = try await supabase.from("matches")
                    .insert([
                        "game_id": AnyJSON.string(game.id.uuidString),
                        "court_id": AnyJSON.string(courtID.uuidString),
                        "status": AnyJSON.string(MatchStatus.inProgress.rawValue)
                    ])
                    .select()
                    .single()
                    .execute()
                    .value

                let matchPlayers = teamA.map { MatchPlayer(matchId: newMatch.id, gamePlayerId: $0.id, team: "a") }
                    + teamB.map { MatchPlayer(matchId: newMatch.id, gamePlayerId: $0.id, team: "b") }
                try await supabase.from("match_players").insert(matchPlayers).execute()
            }

            await startRound()
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
