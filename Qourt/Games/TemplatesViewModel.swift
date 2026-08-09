//
//  TemplatesViewModel.swift
//  Qourt
//

import Foundation
import Supabase

@Observable
final class TemplatesViewModel {
    var templates: [GameTemplate] = []
    var isLoading = true
    var errorMessage: String?

    @MainActor
    func load() async {
        guard let userID = (try? await supabase.auth.session)?.user.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            templates = try await supabase.from("game_templates")
                .select()
                .eq("owner_id", value: userID)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func delete(_ template: GameTemplate) async {
        do {
            try await supabase.from("game_templates")
                .delete()
                .eq("id", value: template.id)
                .execute()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    static func save(name: String, from game: Game, ownerID: UUID) async -> String? {
        struct NewTemplate: Encodable {
            let owner_id: UUID
            let name: String
            let num_courts: Int
            let is_doubles: Bool
            let requires_approval: Bool
            let format: String
            let format_settings: JSONObject
        }
        do {
            try await supabase.from("game_templates")
                .insert(NewTemplate(
                    owner_id: ownerID,
                    name: name,
                    num_courts: game.numCourts,
                    is_doubles: game.isDoubles,
                    requires_approval: game.requiresApproval,
                    format: game.format.rawValue,
                    format_settings: game.formatSettings
                ))
                .execute()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

extension CreateGameViewModel {
    /// Prefills setup fields from a saved Template — name/date/location are
    /// intentionally left alone since those are always specific to this
    /// new instance of the game.
    func apply(_ template: GameTemplate) {
        numCourts = template.numCourts
        isDoubles = template.isDoubles
        requiresApproval = template.requiresApproval
        format = template.format
        formatSettings = FormatSettings(from: template.formatSettings)
    }
}
