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
    /// How many players are in line in total, so "#3" can be shown as
    /// "3 of 8" — a bare position doesn't say how long the wait is.
    var queueTotal: Int?
    var announcements: [Announcement] = []
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
    /// This player's `game_players.id` — needed by every action below, and
    /// it is not the same as the profile/auth id.
    private var playerID: UUID?
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
            // !inner + games.status so an ended game drops off the wrist
            // the moment the admin ends it, not just when this player's own
            // status happens to change too — ending a game only ever
            // touches games.status, never resets the participant rows, so
            // without this a player who was still queued/on court when the
            // game ended would see it forever.
            let rows: [ActivePlayerRow] = try await supabase.from("game_players")
                .select("id, status, queue_position, joined_at, games!inner(id, name)")
                .eq("profile_id", value: userID)
                .in("status", values: [
                    PlayerStatus.pending.rawValue,
                    PlayerStatus.queued.rawValue,
                    PlayerStatus.onCourt.rawValue,
                    PlayerStatus.resting.rawValue
                ])
                .neq("games.status", value: "ended")
                .order("joined_at", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let active = rows.first else {
                gameName = nil
                playerStatus = nil
                gameID = nil
                playerID = nil
                queuePosition = nil
                queueTotal = nil
                announcements = []
                currentMatchID = nil
                return
            }

            gameName = active.games.name
            playerStatus = active.status
            gameID = active.games.id
            playerID = active.id

            switch active.status {
            case .queued:
                let queue = try await loadQueue(gameID: active.games.id)
                queueTotal = queue.count
                queuePosition = queue.firstIndex(of: active.id).map { $0 + 1 }
                clearCourtState()
            case .onCourt:
                queuePosition = nil
                queueTotal = nil
                await loadCourtAndScore(playerID: active.id)
            case .pending, .resting, .removed:
                // Not in line and not on court — nothing to count, and no
                // match to report. Before this branch existed these two
                // states fell through to the on-court path and rendered a
                // blank screen, so stepping out looked like a crash.
                queuePosition = nil
                queueTotal = nil
                clearCourtState()
            }

            await loadAnnouncements(playerID: active.id, gameID: active.games.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func refresh() async {
        guard let userID = (try? await supabase.auth.session)?.user.id else { return }
        await load(userID: userID)
    }

    /// The whole queue in display order, so position and total come from
    /// one round trip. Ordering matches the phone's roster exactly —
    /// explicit `queue_position` first, `joined_at` as the tiebreak.
    private func loadQueue(gameID: UUID) async throws -> [UUID] {
        struct Row: Decodable { let id: UUID }
        let queue: [Row] = try await supabase.from("game_players")
            .select("id")
            .eq("game_id", value: gameID)
            .eq("status", value: PlayerStatus.queued.rawValue)
            .order("queue_position", ascending: true, nullsFirst: false)
            .order("joined_at", ascending: true)
            .execute()
            .value
        return queue.map(\.id)
    }

    @MainActor
    private func clearCourtState() {
        courtName = nil
        scoreA = nil
        scoreB = nil
        currentMatchID = nil
        currentMatchStatus = nil
    }

    /// Mirrors the phone's `loadAnnouncements`: game-wide messages plus any
    /// aimed at this player specifically. Only the newest is shown on the
    /// wrist, but the rest are kept so a list can scroll them.
    @MainActor
    private func loadAnnouncements(playerID: UUID, gameID: UUID) async {
        announcements = (try? await supabase.from("announcements")
            .select()
            .eq("game_id", value: gameID)
            .or("target_player_id.is.null,target_player_id.eq.\(playerID)")
            .order("sent_at", ascending: false)
            .limit(10)
            .execute()
            .value) ?? []
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

    // MARK: - Queue actions
    //
    // All three mirror `PlayerLiveStatusViewModel` exactly — plain status
    // writes that RLS already allows the player to make. Nothing here
    // touches rotation, so the Watch can't disturb a running game.

    /// Give up this turn and drop out of the line. The phone calls this
    /// "Skip my turn"; the player moves to `resting` and keeps their spot
    /// in the game, just not in the queue.
    @MainActor
    func skipTurn() async {
        await setStatus(.resting)
    }

    /// Re-join the back of the line after resting.
    @MainActor
    func stepBackIn() async {
        guard let playerID else { return }
        let position = await nextQueuePosition()
        do {
            try await supabase.from("game_players")
                .update([
                    "status": AnyJSON.string(PlayerStatus.queued.rawValue),
                    "queue_position": AnyJSON.integer(position)
                ])
                .eq("id", value: playerID)
                .execute()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Leave the game entirely. Destructive — the caller confirms first.
    @MainActor
    func leaveGame() async {
        await setStatus(.removed)
    }

    @MainActor
    private func setStatus(_ status: PlayerStatus) async {
        guard let playerID else { return }
        do {
            try await supabase.from("game_players")
                .update(["status": status.rawValue])
                .eq("id", value: playerID)
                .execute()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Back of the queue. Matches the phone: one past the highest position
    /// currently held by anyone in the game, so a returning player can't
    /// jump the line.
    @MainActor
    private func nextQueuePosition() async -> Int {
        guard let gameID else { return 1 }
        struct PositionRow: Decodable { let queue_position: Int? }
        let rows: [PositionRow] = (try? await supabase.from("game_players")
            .select("queue_position")
            .eq("game_id", value: gameID)
            .execute()
            .value) ?? []
        return (rows.compactMap(\.queue_position).max() ?? 0) + 1
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
        for table in ["game_players", "matches", "match_players", "announcements"] {
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
