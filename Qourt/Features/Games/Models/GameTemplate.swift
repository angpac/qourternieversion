//
//  GameTemplate.swift
//  Qourt
//

import Foundation
import Supabase

struct GameTemplate: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var numCourts: Int
    var isDoubles: Bool
    var requiresApproval: Bool
    var format: RotationFormat
    var formatSettings: JSONObject

    enum CodingKeys: String, CodingKey {
        case id, name, format
        case numCourts = "num_courts"
        case isDoubles = "is_doubles"
        case requiresApproval = "requires_approval"
        case formatSettings = "format_settings"
    }
}
