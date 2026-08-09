//
//  PlayerLiveStatusViewModel.swift
//  Qourt
//

import Foundation
import Supabase

struct LastMatchResult {
    let scoreA: Int
    let scoreB: Int
    let myTeam: String
    var won: Bool { myTeam == "a" ? scoreA > scoreB : scoreB > scoreA }
}

@Observable
final class PlayerLiveStatusViewModel {
    let game: Game

    var myPlayer: GamePlayer?
    var queuePosition: Int?
    var queuedPlayers: [GamePlayer] = []
    var myCourt: Court?
    var currentMatch: MatchWithPlayers?
    var lastMatchResult: LastMatchResult?
    var announcements: [Announcement] = []
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

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeSubscriptions: [RealtimeSubscription] = []
    private var connectionObserverTask: Task<Void, Never>?

    init(game: Game) {
        self.game = game
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
        isLoading = true
        defer { isLoading = false }

        guard let userID = (try? await supabase.auth.session)?.user.id else { return }

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

            await loadLastMatchResult(for: player)
            await loadAnnouncements(for: player)
        } catch {
            errorMessage = error.localizedDescription
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

    @MainActor
    private func loadLastMatchResult(for player: GamePlayer) async {
        struct LastMatchRow: Decodable {
            let team: String
            let matches: MatchScoreOnly
        }
        struct MatchScoreOnly: Decodable {
            let score_a: Int?
            let score_b: Int?
            let status: MatchStatus
        }

        let rows: [LastMatchRow] = (try? await supabase.from("match_players")
            .select("team, matches!inner(score_a, score_b, status)")
            .eq("game_player_id", value: player.id)
            .eq("matches.status", value: MatchStatus.confirmed.rawValue)
            .order("started_at", ascending: false, referencedTable: "matches")
            .limit(1)
            .execute()
            .value) ?? []

        guard let row = rows.first, let scoreA = row.matches.score_a, let scoreB = row.matches.score_b else {
            lastMatchResult = nil
            return
        }
        lastMatchResult = LastMatchResult(scoreA: scoreA, scoreB: scoreB, myTeam: row.team)
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
            let myRows: [MatchPlayerRow] = try await supabase.from("match_players")
                .select("match_id, team, game_players(*)")
                .eq("game_player_id", value: player.id)
                .execute()
                .value

            guard let myMatchId = myRows.first?.match_id else {
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

            guard match.status == .inProgress || match.status == .awaitingConfirmation else {
                currentMatch = nil
                myCourt = nil
                return
            }

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

        connectionObserverTask?.cancel()
        connectionObserverTask = Task { [weak self] in
            for await status in channel.statusChange {
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.isConnected = (status == .subscribed) }
            }
        }

        await channel.subscribe()
    }
}
