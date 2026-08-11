//
//  RosterViewModel.swift
//  Qourt
//

import Foundation
import Supabase

@Observable
final class RosterViewModel {
    let game: Game

    var players: [GamePlayer] = []
    var matchCounts: [UUID: Int] = [:]
    var isLoading = true
    var errorMessage: String?

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeSubscriptions: [RealtimeSubscription] = []

    let skillLevels = ["Beginner", "Intermediate", "Advanced"]

    init(game: Game) {
        self.game = game
    }

    @MainActor
    func start() async {
        await load()
        await subscribeToChanges()
    }

    func stop() {
        realtimeSubscriptions.forEach { $0.cancel() }
        realtimeSubscriptions.removeAll()
        Task { await realtimeChannel?.unsubscribe() }
    }

    @MainActor
    func load() async {
        isLoading = true
        do {
            players = try await supabase.from("game_players")
                .select()
                .eq("game_id", value: game.id)
                .order("joined_at", ascending: true)
                .execute()
                .value
            await loadMatchCounts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// How many confirmed matches each player has actually played in this
    /// game so far, so an admin can tell at a glance whether everyone's
    /// getting roughly even court time without waiting for Game Summary.
    @MainActor
    private func loadMatchCounts() async {
        struct MatchPlayerRow: Decodable {
            let game_player_id: UUID
            let matches: MatchStatusOnly
        }
        struct MatchStatusOnly: Decodable {
            let status: MatchStatus
        }

        let rows: [MatchPlayerRow] = (try? await supabase.from("match_players")
            .select("game_player_id, matches!inner(status)")
            .eq("matches.game_id", value: game.id)
            .eq("matches.status", value: MatchStatus.confirmed.rawValue)
            .execute()
            .value) ?? []

        matchCounts = Dictionary(grouping: rows, by: \.game_player_id).mapValues(\.count)
    }

    @MainActor
    private func subscribeToChanges() async {
        let channel = supabase.realtimeV2.channel("roster-\(game.id)")
        realtimeChannel = channel
        for table in ["game_players", "matches", "match_players"] {
            let subscription = channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: table,
                filter: table == "match_players" ? nil : "game_id=eq.\(game.id)"
            ) { [weak self] _ in
                Task { await self?.load() }
            }
            realtimeSubscriptions.append(subscription)
        }
        try? await channel.subscribeWithError()
    }

    @MainActor
    func setSkillLevel(_ player: GamePlayer, to skillLevel: String) async {
        do {
            try await supabase.from("game_players")
                .update(["skill_level": skillLevel])
                .eq("id", value: player.id)
                .execute()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func approve(_ player: GamePlayer) async {
        await setStatus(player, to: .queued, queuePosition: await nextQueuePosition())
    }

    @MainActor
    func reject(_ player: GamePlayer) async {
        await setStatus(player, to: .removed, queuePosition: nil)
    }

    @MainActor
    func pause(_ player: GamePlayer) async {
        await setStatus(player, to: .resting, queuePosition: nil)
    }

    @MainActor
    func returnToQueue(_ player: GamePlayer) async {
        await setStatus(player, to: .queued, queuePosition: await nextQueuePosition())
    }

    @MainActor
    func remove(_ player: GamePlayer) async {
        await setStatus(player, to: .removed, queuePosition: nil)
    }

    @MainActor
    private func setStatus(_ player: GamePlayer, to status: PlayerStatus, queuePosition: Int?) async {
        do {
            var payload: [String: AnyJSON] = ["status": .string(status.rawValue)]
            if let queuePosition {
                payload["queue_position"] = .integer(queuePosition)
            }
            try await supabase.from("game_players")
                .update(payload)
                .eq("id", value: player.id)
                .execute()
            await load()
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
}
