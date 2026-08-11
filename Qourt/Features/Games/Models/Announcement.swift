//
//  Announcement.swift
//  Qourt
//

import Foundation

struct Announcement: Codable, Identifiable, Hashable {
    let id: UUID
    var gameId: UUID
    var senderId: UUID
    var targetPlayerId: UUID?
    var message: String
    var sentAt: Date

    enum CodingKeys: String, CodingKey {
        case id, message
        case gameId = "game_id"
        case senderId = "sender_id"
        case targetPlayerId = "target_player_id"
        case sentAt = "sent_at"
    }
}
