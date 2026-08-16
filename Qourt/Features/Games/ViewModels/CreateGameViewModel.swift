//
//  CreateGameViewModel.swift
//  Qourt
//

import Foundation
import Supabase

enum GameFormatMode: String, CaseIterable, Identifiable {
    case doubles, singles, mixed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .doubles: return "Doubles"
        case .singles: return "Singles"
        case .mixed: return "Mixed"
        }
    }
}

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
    var selectedClubId: UUID?
    var availableClubs: [Club] = []

    /// Doubles/Singles just set isDoubles directly, same as always. Mixed
    /// leaves isDoubles as the fallback for any court that isn't
    /// individually overridden below, and reveals a per-court picker so
    /// setting up a mixed session doesn't require hunting for Manage
    /// Courts after the game already exists.
    var formatMode: GameFormatMode = .doubles {
        didSet {
            switch formatMode {
            case .doubles: isDoubles = true
            case .singles: isDoubles = false
            case .mixed: break
            }
        }
    }
    /// Keyed by court index (0-based); a missing entry means "use the
    /// overall default above" for that court.
    var courtSinglesOverrides: [Int: Bool] = [:]

    // Step 2: Rotation format settings
    var formatSettings = FormatSettings()

    var errorMessage: String?
    var createdGame: Game?

    @MainActor
    func loadAvailableClubs(ownerID: UUID) async {
        struct ClubAdminRow: Decodable { let club_id: UUID }
        let adminRows: [ClubAdminRow] = (try? await supabase.from("club_admins")
            .select("club_id")
            .eq("profile_id", value: ownerID)
            .execute()
            .value) ?? []

        if adminRows.isEmpty {
            availableClubs = (try? await supabase.from("clubs")
                .select()
                .eq("owner_id", value: ownerID)
                .order("created_at", ascending: false)
                .execute()
                .value) ?? []
        } else {
            let adminIDs = adminRows.map(\.club_id.uuidString).joined(separator: ",")
            availableClubs = (try? await supabase.from("clubs")
                .select()
                .or("owner_id.eq.\(ownerID),id.in.(\(adminIDs))")
                .order("created_at", ascending: false)
                .execute()
                .value) ?? []
        }
    }

    private static let joinCodeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    private func generateJoinCode() -> String {
        String((0..<6).map { _ in Self.joinCodeAlphabet.randomElement()! })
    }

    @MainActor
    func createGame(ownerID: UUID) async -> Bool {
        // Guards against creating a second, duplicate game if this is called
        // again after already succeeding once in this wizard session (e.g. a
        // navigation race that sends the admin back to this screen before
        // `createdGame` has propagated) — a game once created here should
        // never be re-inserted.
        if createdGame != nil {
            return true
        }

        // The SDK stores the session in the Keychain; a code-signing/entitlements
        // change since the last sign-in can strand it there, silently falling
        // back to the anon key and failing RLS. Fail fast with a clear message
        // instead of surfacing Postgres's generic RLS violation error.
        guard let session = try? await supabase.auth.session, session.user.id == ownerID else {
            errorMessage = "Your session isn't valid anymore. Sign out and sign in again."
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
            let club_id: UUID?
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
            admin_invite_code: generateJoinCode(),
            club_id: selectedClubId
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
        let overrides = formatMode == .mixed ? courtSinglesOverrides : [:]
        _ = try? await supabase.from("courts").insert(Self.newCourtRows(for: game, singlesOverrides: overrides)).execute()
    }

    /// Half-Court Kingminton splits each physical court into two independent
    /// singles lanes, each capable of hosting its own match — modeled as two
    /// separate court rows sharing a physical court number, reusing all the
    /// existing court/match infrastructure instead of adding a "lane" concept
    /// to matches.
    static func newCourtRows(for game: Game, singlesOverrides: [Int: Bool] = [:]) -> [NewCourtRow] {
        let isKingminton = game.format == .halfCourtKingminton
        let isChallengeCourt = game.format == .challengeCourt

        if isKingminton {
            // Every lane is already forced to singles via is_lane_split —
            // a singles_override on top of that wouldn't mean anything.
            return (0..<game.numCourts).flatMap { index in
                ["A", "B"].map { lane in
                    NewCourtRow(
                        game_id: game.id,
                        name: "Court \(index + 1) · Lane \(lane)",
                        position: index,
                        is_lane_split: true,
                        is_challenge_court: false,
                        singles_override: nil
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
                is_challenge_court: isChallengeCourt && index == 0,
                singles_override: singlesOverrides[index]
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
    let singles_override: Bool?
}
