//
//  TournamentSetupViewModel.swift
//  Qourt
//

import Foundation
import Supabase

@Observable
final class TournamentSetupViewModel {
    let game: Game

    var roster: [GamePlayer] = []
    var seedingMethod: String = "skill" // "skill" | "random" | "manual"
    var manualOrder: [GamePlayer] = []
    var isLoading = true
    var isGenerating = false
    var errorMessage: String?

    private static let skillRank: [String: Int] = ["Beginner": 0, "Intermediate": 1, "Advanced": 2]

    init(game: Game) {
        self.game = game
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            roster = try await supabase.from("game_players")
                .select()
                .eq("game_id", value: game.id)
                .eq("status", value: PlayerStatus.queued.rawValue)
                .order("joined_at", ascending: true)
                .execute()
                .value
            manualOrder = roster
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func seededPlayers() -> [UUID] {
        switch seedingMethod {
        case "random":
            return roster.shuffled().map(\.id)
        case "manual":
            return manualOrder.map(\.id)
        default: // "skill" — strongest first
            return roster.sorted { (Self.skillRank[$0.skillLevel] ?? 0) > (Self.skillRank[$1.skillLevel] ?? 0) }.map(\.id)
        }
    }

    @MainActor
    func generateBracket() async -> Tournament? {
        guard roster.count >= 2 else {
            errorMessage = "Need at least 2 players in the queue to start a tournament."
            return nil
        }
        isGenerating = true
        defer { isGenerating = false }

        let players = seededPlayers()
        let isDouble = game.format == .tournamentDoubleElim
        let generated = isDouble
            ? BracketGenerator.generateDoubleElimination(players: players)
            : BracketGenerator.generateSingleElimination(players: players)

        struct NewTournament: Encodable {
            let game_id: UUID
            let bracket_size: Int
            let elimination_type: String
            let seeding_method: String
        }

        do {
            let tournament: Tournament = try await supabase.from("tournaments")
                .insert(NewTournament(
                    game_id: game.id,
                    bracket_size: BracketGenerator.nextPowerOfTwo(atLeast: players.count),
                    elimination_type: isDouble ? "double" : "single",
                    seeding_method: seedingMethod
                ))
                .select()
                .single()
                .execute()
                .value

            struct NewTournamentMatch: Encodable {
                let id: UUID
                let tournament_id: UUID
                let bracket: String
                let round: Int
                let slot: Int
                let next_match_id: UUID?
                let team_a_player_ids: [UUID]?
                let team_b_player_ids: [UUID]?
                let advances_to_slot: String?
                let loser_next_match_id: UUID?
                let loser_advances_to_slot: String?
            }

            let rows = generated.map { match in
                NewTournamentMatch(
                    id: match.id, tournament_id: tournament.id, bracket: match.bracket,
                    round: match.round, slot: match.slot, next_match_id: match.nextMatchId,
                    team_a_player_ids: match.teamA, team_b_player_ids: match.teamB,
                    advances_to_slot: match.advancesToSlot,
                    loser_next_match_id: match.loserNextMatchId, loser_advances_to_slot: match.loserAdvancesToSlot
                )
            }
            try await supabase.from("tournament_matches").insert(rows).execute()

            return tournament
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
