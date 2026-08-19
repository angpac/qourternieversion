//
//  WatchHostViewModel.swift
//  Qourt Watch App
//
//  Host-side scoring from the wrist: see every live court in the game and
//  adjust scores as rallies finish, without pulling the phone out.
//

import Foundation
import Supabase

/// One live court plus whatever match is on it right now.
struct WatchCourtMatch: Identifiable, Hashable {
    var courtID: UUID
    var courtName: String
    var matchID: UUID?
    var scoreA: Int
    var scoreB: Int
    var status: MatchStatus?

    var id: UUID { courtID }
    var hasLiveMatch: Bool { matchID != nil }
}

@Observable
final class WatchHostViewModel {
    var isAdmin = false
    var isLoading = true
    var gameName: String?
    var courts: [WatchCourtMatch] = []
    var errorMessage: String?

    private var gameID: UUID?
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeSubscriptions: [RealtimeSubscription] = []

    /// Lightweight admin probe. The host experience isn't on the Watch yet,
    /// but the app still needs to know whether this user runs a game so it
    /// can say so plainly instead of showing them an empty player screen.
    /// Deliberately does no court loading and opens no realtime channel.
    @MainActor
    func checkIsAdmin() async {
        guard let userID = (try? await supabase.auth.session)?.user.id else {
            isAdmin = false
            return
        }
        await resolveAdminGame(userID: userID)
        isAdmin = gameID != nil
    }

    /// Full host load — courts, scores and realtime. Not reachable from the
    /// UI yet; see `HostCourtsView` for the pending host experience.
    @MainActor
    func start() async {
        isLoading = true
        defer { isLoading = false }

        guard let userID = (try? await supabase.auth.session)?.user.id else {
            isAdmin = false
            return
        }
        await resolveAdminGame(userID: userID)
        guard gameID != nil else { isAdmin = false; return }
        isAdmin = true
        await load()
        await subscribeToChanges()
    }

    /// Find the game this user administers. Mirrors `MyGamesView.loadGames`:
    /// a user administers a game they own, or one they were added to via
    /// game_admins (which is also how club-level admins inherit access).
    @MainActor
    private func resolveAdminGame(userID: UUID) async {
        struct GameRow: Decodable { let id: UUID; let name: String; let status: String? }

        let owned: [GameRow]? = try? await supabase.from("games")
            .select("id, name, status")
            .eq("owner_id", value: userID)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        if let game = owned?.first {
            gameID = game.id
            gameName = game.name
            return
        }

        struct CoAdminRow: Decodable { let games: GameRow }
        let coAdmin: [CoAdminRow]? = try? await supabase.from("game_admins")
            .select("games(id, name, status)")
            .eq("profile_id", value: userID)
            .limit(1)
            .execute()
            .value

        if let game = coAdmin?.first?.games {
            gameID = game.id
            gameName = game.name
        }
    }

    @MainActor
    func load() async {
        guard let gameID else { return }

        struct CourtRow: Decodable { let id: UUID; let name: String; let position: Int }
        struct MatchRow: Decodable {
            let id: UUID
            let court_id: UUID?
            let score_a: Int?
            let score_b: Int?
            let status: MatchStatus
        }

        do {
            let courtRows: [CourtRow] = try await supabase.from("courts")
                .select("id, name, position")
                .eq("game_id", value: gameID)
                .order("position", ascending: true)
                .execute()
                .value

            let matchRows: [MatchRow] = try await supabase.from("matches")
                .select("id, court_id, score_a, score_b, status")
                .eq("game_id", value: gameID)
                .in("status", values: [MatchStatus.inProgress.rawValue, MatchStatus.awaitingConfirmation.rawValue])
                .execute()
                .value

            let byCourt = Dictionary(matchRows.compactMap { row in
                row.court_id.map { ($0, row) }
            }, uniquingKeysWith: { first, _ in first })

            courts = courtRows.map { court in
                let match = byCourt[court.id]
                return WatchCourtMatch(
                    courtID: court.id,
                    courtName: court.name,
                    matchID: match?.id,
                    scoreA: match?.score_a ?? 0,
                    scoreB: match?.score_b ?? 0,
                    status: match?.status
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Live score keeping. Matches the phone's
    /// `LiveDashboardViewModel.updateScore` — score only, no status change,
    /// so both devices can drive the same match without fighting.
    @MainActor
    func updateScore(matchID: UUID, scoreA: Int, scoreB: Int) async {
        // Optimistic local update so the wrist feels instant; Realtime
        // reconciles it a moment later.
        if let index = courts.firstIndex(where: { $0.matchID == matchID }) {
            courts[index].scoreA = scoreA
            courts[index].scoreB = scoreB
        }
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
            await load()
        }
    }

    /// Send the final score up for confirmation.
    ///
    /// Deliberately NOT a full "end match": confirming a match on the phone
    /// also runs rotation — winner-stays streaks, Challenge Court caps,
    /// putting the losing side back in the queue — which lives in
    /// `LiveDashboardViewModel.endMatch` and has no server-side equivalent.
    /// Duplicating it here would let the two implementations drift, so the
    /// Watch stops at `awaiting_confirmation` and the phone finishes the job.
    @MainActor
    func reportFinalScore(matchID: UUID, scoreA: Int, scoreB: Int) async {
        guard let userID = (try? await supabase.auth.session)?.user.id else { return }
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
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func subscribeToChanges() async {
        guard let gameID else { return }
        await unsubscribe()

        let channel = supabase.realtimeV2.channel("watch-host-\(gameID)")
        realtimeChannel = channel

        let filter = "game_id=eq.\(gameID)"
        for table in ["matches", "courts"] {
            let subscription = channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: table,
                filter: filter
            ) { [weak self] _ in
                Task { await self?.load() }
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
