//
//  Court.swift
//  Qourt
//

import Foundation

struct Court: Codable, Identifiable, Hashable {
    let id: UUID
    var gameId: UUID
    var name: String
    var position: Int
    var isLaneSplit: Bool
    var isChallengeCourt: Bool
    var winStreak: Int

    enum CodingKeys: String, CodingKey {
        case id, name, position
        case gameId = "game_id"
        case isLaneSplit = "is_lane_split"
        case isChallengeCourt = "is_challenge_court"
        case winStreak = "win_streak"
    }
}
