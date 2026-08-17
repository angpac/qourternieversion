//
//  ClubsViewModel.swift
//  Qourt
//

import Foundation
import Supabase

@Observable
final class ClubsViewModel {
    var clubs: [Club] = []
    var isLoading = true
    var errorMessage: String?

    private static let inviteAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    private func generateInviteCode() -> String {
        String((0..<6).map { _ in Self.inviteAlphabet.randomElement()! })
    }

    @MainActor
    func load() async {
        guard let userID = (try? await supabase.auth.session)?.user.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            struct ClubAdminRow: Decodable { let club_id: UUID }
            let adminRows: [ClubAdminRow] = (try? await supabase.from("club_admins")
                .select("club_id")
                .eq("profile_id", value: userID)
                .execute()
                .value) ?? []

            if adminRows.isEmpty {
                clubs = try await supabase.from("clubs")
                    .select()
                    .eq("owner_id", value: userID)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            } else {
                let adminIDs = adminRows.map(\.club_id.uuidString).joined(separator: ",")
                clubs = try await supabase.from("clubs")
                    .select()
                    .or("owner_id.eq.\(userID),id.in.(\(adminIDs))")
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func createClub(name: String, sports: [String], courts: Int, ownerID: UUID) async -> Club? {
        struct NewClub: Encodable {
            let owner_id: UUID
            let name: String
            let sports: [String]
            let courts: Int
            let club_admin_invite_code: String
        }
        do {
            let club: Club = try await supabase.from("clubs")
                .insert(NewClub(
                    owner_id: ownerID,
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    sports: sports,
                    courts: courts,
                    club_admin_invite_code: generateInviteCode()
                ))
                .select()
                .single()
                .execute()
                .value
            await load()
            return club
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
