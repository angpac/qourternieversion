//
//  Tournament.swift
//  Qourt
//

import Foundation

struct Tournament: Codable, Identifiable, Hashable {
    let id: UUID
    var gameId: UUID
    var bracketSize: Int
    var eliminationType: String // "single" | "double"
    var seedingMethod: String // "skill" | "random" | "manual"

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case bracketSize = "bracket_size"
        case eliminationType = "elimination_type"
        case seedingMethod = "seeding_method"
    }
}

struct TournamentMatch: Codable, Identifiable, Hashable {
    let id: UUID
    var tournamentId: UUID
    var matchId: UUID?
    var bracket: String // "winners" | "losers" | "final"
    var round: Int
    var slot: Int
    var nextMatchId: UUID?
    var teamAPlayerIds: [UUID]?
    var teamBPlayerIds: [UUID]?
    var advancesToSlot: String? // "a" | "b"
    var loserNextMatchId: UUID?
    var loserAdvancesToSlot: String?

    enum CodingKeys: String, CodingKey {
        case id, bracket, round, slot
        case tournamentId = "tournament_id"
        case matchId = "match_id"
        case nextMatchId = "next_match_id"
        case teamAPlayerIds = "team_a_player_ids"
        case teamBPlayerIds = "team_b_player_ids"
        case advancesToSlot = "advances_to_slot"
        case loserNextMatchId = "loser_next_match_id"
        case loserAdvancesToSlot = "loser_advances_to_slot"
    }

    var isReadyToStart: Bool {
        matchId == nil && teamAPlayerIds?.isEmpty == false && teamBPlayerIds?.isEmpty == false
    }
}
