//
//  WatchGamesViewModel.swift
//  Qourt Watch App
//
//  Backs the wrist's My Games list — mirrors the phone's MyGamesView.
//  loadGames query shapes exactly (admin: owned + co-admin games, player:
//  games joined via game_players) so the list matches what the phone
//  would show, scoped to whichever role is currently active.
//

import Foundation
import Supabase

enum WatchRole: String {
    case admin
    case player
}

@Observable
final class WatchGamesViewModel {
    var isLoading = true
    var games: [WatchGame] = []
    var errorMessage: String?

    @MainActor
    func load(role: WatchRole) async {
        isLoading = true
        defer { isLoading = false }

        guard let userID = (try? await supabase.auth.session)?.user.id else { return }

        do {
            switch role {
            case .admin:
                games = try await loadAdminGames(userID: userID)
            case .player:
                games = try await loadPlayerGames(userID: userID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Same two shapes as `MyGamesView.loadGames`'s admin branch: just the
    /// games this profile owns, or — if it co-admins any via `game_admins`
    /// — owned OR co-administered.
    private func loadAdminGames(userID: UUID) async throws -> [WatchGame] {
        struct CoAdminRow: Decodable { let game_id: UUID }
        let coAdminRows: [CoAdminRow] = (try? await supabase.from("game_admins")
            .select("game_id")
            .eq("profile_id", value: userID)
            .execute()
            .value) ?? []

        if coAdminRows.isEmpty {
            return try await supabase.from("games")
                .select("id, name, status")
                .eq("owner_id", value: userID)
                .order("created_at", ascending: false)
                .execute()
                .value
        } else {
            let coAdminIDs = coAdminRows.map(\.game_id.uuidString).joined(separator: ",")
            return try await supabase.from("games")
                .select("id, name, status")
                .or("owner_id.eq.\(userID),id.in.(\(coAdminIDs))")
                .order("created_at", ascending: false)
                .execute()
                .value
        }
    }

    /// Every game this profile has ever joined, newest first. Ended games
    /// stay in the list with an Ended pill rather than disappearing, same
    /// as the phone's My Games — tapping one still shows a graceful
    /// "session has ended" card instead of stale queue/court state.
    private func loadPlayerGames(userID: UUID) async throws -> [WatchGame] {
        struct JoinedGameRow: Decodable {
            let joined_at: Date
            let games: WatchGame
        }
        let rows: [JoinedGameRow] = try await supabase.from("game_players")
            .select("joined_at, games!inner(id, name, status)")
            .eq("profile_id", value: userID)
            .order("joined_at", ascending: false)
            .execute()
            .value
        return rows.map(\.games)
    }
}
