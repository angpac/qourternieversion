//
//  Match.swift
//  Qourt
//

import Foundation

struct Match: Codable, Identifiable, Hashable {
    let id: UUID
    var gameId: UUID
    var courtId: UUID?
    var status: MatchStatus
    var scoreA: Int?
    var scoreB: Int?
    var startedAt: Date
    var endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status
        case gameId = "game_id"
        case courtId = "court_id"
        case scoreA = "score_a"
        case scoreB = "score_b"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}

struct MatchPlayer: Codable, Hashable {
    var matchId: UUID
    var gamePlayerId: UUID
    var team: String

    enum CodingKeys: String, CodingKey {
        case team
        case matchId = "match_id"
        case gamePlayerId = "game_player_id"
    }
}

/// A match joined with its roster, for display on the dashboard.
struct MatchWithPlayers: Identifiable, Hashable {
    var match: Match
    var teamA: [GamePlayer]
    var teamB: [GamePlayer]

    var id: UUID { match.id }
}
