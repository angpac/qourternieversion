//
//  CreateGameViewModel.swift
//  Qourt
//

import Foundation
import Supabase

@Observable
final class CreateGameViewModel {
    // Step 1: Create a game
    var name: String = ""
    var location: String = ""
    var startsAt: Date = Date()
    var numCourts: Int = 4
    var isDoubles: Bool = true
    var requiresApproval: Bool = false
    var format: RotationFormat = .kingOfTheCourt

    // Step 2: Rotation format settings
    var formatSettings = FormatSettings()

    var errorMessage: String?
    var createdGame: Game?

    private static let joinCodeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    private func generateJoinCode() -> String {
        String((0..<6).map { _ in Self.joinCodeAlphabet.randomElement()! })
    }

    @MainActor
    func createGame(ownerID: UUID) async -> Bool {
        // The SDK stores the session in the Keychain; a code-signing/entitlements
        // change since the last sign-in can strand it there, silently falling
        // back to the anon key and failing RLS. Fail fast with a clear message
        // instead of surfacing Postgres's generic RLS violation error.
        guard let session = try? await supabase.auth.session, session.user.id == ownerID else {
            errorMessage = "Your session isn't valid anymore — sign out and sign in again."
            return false
        }

        struct NewGame: Encodable {
            let owner_id: UUID
            let name: String
            let location: String?
            let starts_at: Date
            let num_courts: Int
            let is_doubles: Bool
            let requires_approval: Bool
            let format: String
            let format_settings: JSONObject
            let join_code: String
            let admin_invite_code: String
        }

        let newGame = NewGame(
            owner_id: ownerID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.isEmpty ? nil : location,
            starts_at: startsAt,
            num_courts: numCourts,
            is_doubles: isDoubles,
            requires_approval: requiresApproval,
            format: format.rawValue,
            format_settings: formatSettings.asJSONObject(for: format),
            join_code: generateJoinCode(),
            admin_invite_code: generateJoinCode()
        )

        do {
            let game: Game = try await supabase.from("games")
                .insert(newGame)
                .select()
                .single()
                .execute()
                .value
            createdGame = game
            await createCourts(for: game)
            return true
        } catch let error as PostgrestError {
            errorMessage = error.message
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func createCourts(for game: Game) async {
        try? await supabase.from("courts").insert(Self.newCourtRows(for: game)).execute()
    }

    /// Half-Court Kingminton splits each physical court into two independent
    /// singles lanes, each capable of hosting its own match — modeled as two
    /// separate court rows sharing a physical court number, reusing all the
    /// existing court/match infrastructure instead of adding a "lane" concept
    /// to matches.
    static func newCourtRows(for game: Game) -> [NewCourtRow] {
        let isKingminton = game.format == .halfCourtKingminton
        let isChallengeCourt = game.format == .challengeCourt

        if isKingminton {
            return (0..<game.numCourts).flatMap { index in
                ["A", "B"].map { lane in
                    NewCourtRow(
                        game_id: game.id,
                        name: "Court \(index + 1) · Lane \(lane)",
                        position: index,
                        is_lane_split: true,
                        is_challenge_court: false
                    )
                }
            }
        }

        return (0..<game.numCourts).map { index in
            NewCourtRow(
                game_id: game.id,
                name: "Court \(index + 1)",
                position: index,
                is_lane_split: false,
                is_challenge_court: isChallengeCourt && index == 0
            )
        }
    }
}

struct NewCourtRow: Encodable {
    let game_id: UUID
    let name: String
    let position: Int
    let is_lane_split: Bool
    let is_challenge_court: Bool
}
