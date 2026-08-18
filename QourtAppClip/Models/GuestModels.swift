//
//  GuestModels.swift
//  QourtAppClip
//
//  Mirrors the JSON shape of the guest_* Postgres functions (see
//  supabase/migrations/20260808180000_web_guest_rpcs.sql and
//  20260809180000_game_preview_by_code.sql) — the same RPCs the web guest
//  client (web/components/JoinForm.tsx, web/app/status) already calls, so
//  the App Clip is just a native client of the exact same guest API.
//

import Foundation

struct GamePreview: Decodable {
    let name: String
    let status: String
    let joinCode: String

    enum CodingKeys: String, CodingKey {
        case name, status
        case joinCode = "join_code"
    }
}

struct GuestJoinResponse: Decodable {
    let sessionToken: UUID
    let gameName: String
    let gameFormat: String
    let joinCode: String

    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
        case gameName = "game_name"
        case gameFormat = "game_format"
        case joinCode = "join_code"
    }
}

struct GuestPlayer: Decodable, Identifiable {
    let id: UUID
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct GuestStatus: Decodable {
    let gameName: String
    let gameFormat: RotationFormat
    let isDoubles: Bool
    let joinCode: String
    let playerStatus: PlayerStatus
    let queuePosition: Int?
    let courtName: String?
    let matchStatus: MatchStatus?
    let scoreA: Int?
    let scoreB: Int?
    let teamA: [GuestPlayer]?
    let teamB: [GuestPlayer]?
    let myDisplayName: String
    let mySkillLevel: String

    enum CodingKeys: String, CodingKey {
        case gameName = "game_name"
        case gameFormat = "game_format"
        case isDoubles = "is_doubles"
        case joinCode = "join_code"
        case playerStatus = "player_status"
        case queuePosition = "queue_position"
        case courtName = "court_name"
        case matchStatus = "match_status"
        case scoreA = "score_a"
        case scoreB = "score_b"
        case teamA = "team_a"
        case teamB = "team_b"
        case myDisplayName = "my_display_name"
        case mySkillLevel = "my_skill_level"
    }
}
