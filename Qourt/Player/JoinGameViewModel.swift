//
//  JoinGameViewModel.swift
//  Qourt
//

import Foundation
import Supabase

@Observable
final class JoinGameViewModel {
    var joinCode: String = ""
    var displayName: String = ""
    var skillLevel: String = "Beginner"
    var errorMessage: String?
    var joinedGame: Game?
    var previewGameName: String?
    var previewError: String?
    var isLoadingPreview = false

    let skillLevels = ["Beginner", "Intermediate", "Advanced"]

    @MainActor
    func loadPreview() async {
        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        previewGameName = nil
        previewError = nil
        isLoadingPreview = true
        defer { isLoadingPreview = false }

        struct Params: Encodable { let p_join_code: String }
        struct Preview: Decodable { let name: String; let status: String }

        do {
            let preview: Preview = try await supabase.rpc(
                "game_preview_by_code",
                params: Params(p_join_code: code)
            )
            .execute()
            .value
            if preview.status == "ended" {
                previewError = "This game has ended — the code no longer works."
            } else {
                previewGameName = preview.name
            }
        } catch let error as PostgrestError {
            previewError = error.message
        } catch {
            previewError = error.localizedDescription
        }
    }

    @MainActor
    func joinGame() async -> Bool {
        struct Params: Encodable {
            let p_join_code: String
            let p_display_name: String
            let p_skill_level: String
        }

        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, !name.isEmpty else {
            errorMessage = "Enter a join code and your name."
            return false
        }

        do {
            let game: Game = try await supabase.rpc(
                "join_game_by_code",
                params: Params(p_join_code: code, p_display_name: name, p_skill_level: skillLevel)
            )
            .execute()
            .value
            joinedGame = game
            return true
        } catch let error as PostgrestError {
            errorMessage = error.message
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
