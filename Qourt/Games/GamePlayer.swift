//
//  GamePlayer.swift
//  Qourt
//

import Foundation

enum PlayerStatus: String, Codable {
    case pending
    case queued
    case onCourt = "on_court"
    case resting
    case removed
}

struct GamePlayer: Codable, Identifiable, Hashable {
    let id: UUID
    var gameId: UUID
    var profileId: UUID?
    var displayName: String
    var skillLevel: String
    var status: PlayerStatus
    var queuePosition: Int?
    var joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status
        case gameId = "game_id"
        case profileId = "profile_id"
        case displayName = "display_name"
        case skillLevel = "skill_level"
        case queuePosition = "queue_position"
        case joinedAt = "joined_at"
    }
}
