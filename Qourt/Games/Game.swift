//
//  Game.swift
//  Qourt
//

import Foundation
import Supabase

struct Game: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var location: String?
    var startsAt: Date?
    var numCourts: Int
    var isDoubles: Bool
    var format: RotationFormat
    var formatSettings: JSONObject
    var joinCode: String
    var status: String
    var currentRoundStartedAt: Date?
    var requiresApproval: Bool = false
    var adminInviteCode: String?
    var archived: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, location, status, format, archived
        case startsAt = "starts_at"
        case numCourts = "num_courts"
        case isDoubles = "is_doubles"
        case formatSettings = "format_settings"
        case joinCode = "join_code"
        case currentRoundStartedAt = "current_round_started_at"
        case requiresApproval = "requires_approval"
        case adminInviteCode = "admin_invite_code"
    }

    var hasEnded: Bool { status == "ended" }

    var roundMinutes: Int {
        if case let .integer(value)? = formatSettings["round_minutes"] { return value }
        return 8
    }

    var autoRotate: Bool {
        if case let .bool(value)? = formatSettings["auto_rotate"] { return value }
        return true
    }

    var pickerPoolSize: Int {
        if case let .integer(value)? = formatSettings["picker_pool_size"] { return value }
        return 10
    }

    var manualMatching: Bool {
        if case let .bool(value)? = formatSettings["manual_matching"] { return value }
        return false
    }
}
