//
//  ClipModels.swift
//  QourtClip
//
//  Mirrors the jsonb these RPCs return. Field names match the SQL
//  `jsonb_build_object` keys exactly — see `guest_status` and
//  `guest_join_game` in db/qourt_schema.sql. Everything the SQL can leave
//  null is optional here; a mismatch decodes to nothing and shows an empty
//  screen rather than an error, so it's worth keeping these in step.
//

import Foundation

struct ClipGamePreview: Decodable {
    let name: String
    let status: String
}

struct ClipJoinResult: Decodable {
    let session_token: UUID
    let game_name: String
}

struct ClipPlayer: Decodable, Identifiable {
    let id: UUID
    let display_name: String
}

struct ClipPoolPlayer: Decodable, Identifiable {
    let id: UUID
    let display_name: String
    let skill_level: String
}

struct ClipAnnouncement: Decodable, Identifiable {
    let id: UUID
    let message: String
    let sent_at: Date
}

struct ClipStatus: Decodable {
    let game_name: String
    let game_format: String
    let is_doubles: Bool
    let join_code: String
    let player_status: ClipPlayerStatus
    let queue_position: Int?
    let court_name: String?
    let match_status: ClipMatchStatus?
    let score_a: Int?
    let score_b: Int?
    let team_a: [ClipPlayer]?
    let team_b: [ClipPlayer]?
    let last_match_score_a: Int?
    let last_match_score_b: Int?
    let last_match_my_team: String?
    let is_picker: Bool
    let picker_pool: [ClipPoolPlayer]?
    let my_display_name: String
    let my_skill_level: String

    /// True if the last confirmed match was a win, nil if there isn't one
    /// yet. Same derivation as the web client's `wonLastMatch`.
    var wonLastMatch: Bool? {
        guard let team = last_match_my_team,
              let a = last_match_score_a,
              let b = last_match_score_b else { return nil }
        return team == "a" ? a > b : b > a
    }

    /// "About 2 more matches before yours" — a rough read on the wait that
    /// a raw queue number doesn't give, especially in doubles. Skipped for
    /// Peg Board, where the Picker builds a match out of a pool rather than
    /// the next N in order, so counting groups ahead wouldn't hold.
    var groupsAheadText: String? {
        guard game_format != "peg_board", let position = queue_position else { return nil }
        let matchSize = is_doubles ? 4 : 2
        let groupsAhead = (position - 1) / matchSize
        guard groupsAhead >= 1 else { return nil }
        return "About \(groupsAhead) more match\(groupsAhead == 1 ? "" : "es") before yours"
    }
}

/// Mirrors `player_status` in Postgres. Kept local to the clip rather than
/// shared from QourtShared/Models, so the App Clip target pulls in nothing
/// it doesn't use.
enum ClipPlayerStatus: String, Decodable {
    case pending, queued, resting, removed
    case onCourt = "on_court"
}

enum ClipMatchStatus: String, Decodable {
    case inProgress = "in_progress"
    case awaitingConfirmation = "awaiting_confirmation"
    case confirmed, cancelled
}
