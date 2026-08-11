//
//  ManageClubAdminsViewModel.swift
//  Qourt
//

import Foundation
import Supabase

struct ClubAdminRow: Decodable, Identifiable {
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
final class ManageClubAdminsViewModel {
    let club: Club

    var admins: [ClubAdminRow] = []
    var isLoading = true
    var errorMessage: String?

    init(club: Club) {
        self.club = club
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            admins = try await supabase.from("club_admins")
                .select("profile_id, profiles(display_name)")
                .eq("club_id", value: club.id)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func remove(_ admin: ClubAdminRow) async {
        do {
            try await supabase.from("club_admins")
                .delete()
                .eq("club_id", value: club.id)
                .eq("profile_id", value: admin.profileId)
                .execute()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
