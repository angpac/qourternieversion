//
//  Club.swift
//  Qourt
//

import Foundation

struct Club: Codable, Identifiable, Hashable {
    let id: UUID
    var ownerId: UUID
    var name: String
    var sports: [String]
    var clubAdminInviteCode: String?

    enum CodingKeys: String, CodingKey {
        case id, name, sports
        case ownerId = "owner_id"
        case clubAdminInviteCode = "club_admin_invite_code"
    }
}

/// Common sports offered as quick-pick options when creating a club — a
/// club isn't restricted to these, "sports" is just a free-form text
/// array; this list only seeds the UI so most admins never need to type.
enum CommonSport: String, CaseIterable, Identifiable {
    case badminton = "Badminton"
    case pickleball = "Pickleball"
    case tennis = "Tennis"
    case tableTennis = "Table Tennis"
    case squash = "Squash"
    case basketball = "Basketball"
    case volleyball = "Volleyball"

    var id: String { rawValue }
}
