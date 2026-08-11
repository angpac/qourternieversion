//
//  Models.swift
//  Qourt Watch App
//
//  Mirrors the enums in the iOS target's GamePlayer.swift/Match.swift —
//  duplicated here since Watch and iOS are separate compile targets.
//

import Foundation

enum PlayerStatus: String, Codable {
    /// Set by `join_game_by_code` when the game has `requires_approval`
    /// on — the player has joined but an admin hasn't let them in yet, so
    /// they hold no queue position. Must stay in sync with the
    /// `player_status` enum in Postgres: a value missing here makes the
    /// whole row fail to decode, which surfaces as a blank Watch screen
    /// rather than a visible error.
    case pending
    case queued
    case onCourt = "on_court"
    case resting
    case removed
}

enum MatchStatus: String, Codable {
    case inProgress = "in_progress"
    case awaitingConfirmation = "awaiting_confirmation"
    case confirmed
    case cancelled
}
