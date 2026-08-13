//
//  ManageCoAdminsViewModel.swift
//  Qourt
//

import Foundation
import Supabase

struct GameAdminRow: Decodable, Identifiable {
    var id: UUID { profileId }
    let profileId: UUID
    let profiles: ProfileName

    struct ProfileName: Decodable {
        let displayName: String
        enum CodingKeys: String, CodingKey { case displayName = "display_name" }
    }

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case profiles
    }
}

@Observable
final class ManageCoAdminsViewModel {
    let game: Game

    var coAdmins: [GameAdminRow] = []
    var isLoading = true
    var errorMessage: String?

    init(game: Game) {
        self.game = game
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            coAdmins = try await supabase.from("game_admins")
                .select("profile_id, profiles(display_name)")
                .eq("game_id", value: game.id)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func remove(_ admin: GameAdminRow) async {
        do {
            try await supabase.from("game_admins")
                .delete()
                .eq("game_id", value: game.id)
                .eq("profile_id", value: admin.profileId)
                .execute()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
