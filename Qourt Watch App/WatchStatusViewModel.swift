//
//  WatchStatusViewModel.swift
//  Qourt Watch App
//

import Foundation
import Supabase

struct WatchGame: Codable {
    var id: UUID
    var name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }
}

@Observable
final class WatchStatusViewModel {
    var isSignedIn = false
    var isLoading = true
    var gameName: String?
    var playerStatus: PlayerStatus?
    var queuePosition: Int?
    var courtName: String?
    var scoreA: Int?
    var scoreB: Int?
    var errorMessage: String?

    /// Set while the player is on court, so the score can be reported from
    /// the Watch without another round trip to find the match.
    private(set) var currentMatchID: UUID?
    private(set) var currentMatchStatus: MatchStatus?
    /// True once this player has reported and the admin hasn't confirmed —
    /// the UI shows a waiting state instead of the report control.
    var isAwaitingConfirmation: Bool { currentMatchStatus == .awaitingConfirmation }

    private var gameID: UUID?
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeSubscriptions: [RealtimeSubscription] = []

    @MainActor
    func start() async {
        isLoading = true
        defer { isLoading = false }

        guard let userID = (try? await supabase.auth.session)?.user.id else {
            isSignedIn = false
            // The phone may not have handed tokens over yet.
            WatchSessionBridge.shared.requestSessionFromPhone()
            return
        }
        isSignedIn = true
        await load(userID: userID)
        await subscribeToChanges()
    }

    @MainActor
    private func load(userID: UUID) async {
        struct ActivePlayerRow: Decodable {
            let id: UUID
            let status: PlayerStatus
            let queue_position: Int?
            let joined_at: Date
            let games: WatchGame
        }

        do {
            let rows: [ActivePlayerRow] = try await supabase.from("game_players")
                .select("id, status, queue_position, joined_at, games(id, name)")
                .eq("profile_id", value: userID)
                .in("status", values: [PlayerStatus.queued.rawValue, PlayerStatus.onCourt.rawValue])
                .order("joined_at", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let active = rows.first else {
                gameName = nil
                playerStatus = nil
                gameID = nil
                currentMatchID = nil
                return
            }

            gameName = active.games.name
            playerStatus = active.status
            gameID = active.games.id

            if active.status == .queued {
                queuePosition = try await computeQueuePosition(gameID: active.games.id, playerID: active.id)
                courtName = nil
                scoreA = nil
                scoreB = nil
                currentMatchID = nil
                currentMatchStatus = nil
            } else {
                queuePosition = nil
                await loadCourtAndScore(playerID: active.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func refresh() async {
        guard let userID = (try? await supabase.auth.session)?.user.id else { return }
        await load(userID: userID)
    }

    private func computeQueuePosition(gameID: UUID, playerID: UUID) async throws -> Int? {
        struct Row: Decodable { let id: UUID }
        let queue: [Row] = try await supabase.from("game_players")
            .select("id")
            .eq("game_id", value: gameID)
            .eq("status", value: PlayerStatus.queued.rawValue)
            .order("queue_position", ascending: true, nullsFirst: false)
            .order("joined_at", ascending: true)
            .execute()
            .value
        guard let index = queue.firstIndex(where: { $0.id == playerID }) else { return nil }
        return index + 1
    }

    @MainActor
    private func loadCourtAndScore(playerID: UUID) async {
        struct MatchPlayerRow: Decodable {
            let matches: MatchInfo
        }
        struct MatchInfo: Decodable {
            let id: UUID
            let score_a: Int?
            let score_b: Int?
            let status: MatchStatus
            let courts: CourtInfo?
        }
        struct CourtInfo: Decodable {
            let name: String
        }

        let rows: [MatchPlayerRow]? = try? await supabase.from("match_players")
            .select("matches!inner(id, score_a, score_b, status, courts(name))")
            .eq("game_player_id", value: playerID)
            .in("matches.status", values: [MatchStatus.inProgress.rawValue, MatchStatus.awaitingConfirmation.rawValue])
            .execute()
            .value

        guard let match = rows?.first?.matches else {
            courtName = nil
            scoreA = nil
            scoreB = nil
            currentMatchID = nil
            currentMatchStatus = nil
            return
        }
        courtName = match.courts?.name
        scoreA = match.score_a
        scoreB = match.score_b
        currentMatchID = match.id
        currentMatchStatus = match.status
    }

    /// Self-report the final score from the Watch. Mirrors the phone's
    /// `PlayerLiveStatusViewModel.reportScore` exactly: the match moves to
    /// `awaiting_confirmation` and only counts once an admin confirms, so
    /// reporting from the wrist can't quietly settle a match.
    @MainActor
    func reportScore(scoreA: Int, scoreB: Int) async {
        guard let matchID = currentMatchID,
              let userID = (try? await supabase.auth.session)?.user.id else { return }
        do {
            try await supabase.from("matches")
                .update([
                    "score_a": AnyJSON.integer(scoreA),
                    "score_b": AnyJSON.integer(scoreB),
                    "status": AnyJSON.string(MatchStatus.awaitingConfirmation.rawValue),
                    "reported_by": AnyJSON.string(userID.uuidString)
                ])
                .eq("id", value: matchID)
                .execute()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func subscribeToChanges() async {
        guard let gameID else { return }
        await unsubscribe()

        let channel = supabase.realtimeV2.channel("watch-player-\(gameID)")
        realtimeChannel = channel

        let filter = "game_id=eq.\(gameID)"
        for table in ["game_players", "matches", "match_players"] {
            let subscription = channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: table,
                // match_players has no game_id column, so it can't be
                // server-filtered; the reload below re-reads only this
                // player's row either way.
                filter: table == "match_players" ? nil : filter
            ) { [weak self] _ in
                Task { await self?.refresh() }
            }
            realtimeSubscriptions.append(subscription)
        }

        try? await channel.subscribeWithError()
    }

    @MainActor
    func unsubscribe() async {
        for subscription in realtimeSubscriptions { subscription.cancel() }
        realtimeSubscriptions.removeAll()
        if let realtimeChannel {
            await supabase.realtimeV2.removeChannel(realtimeChannel)
        }
        realtimeChannel = nil
    }
}
