//
//  Models.swift
//  Qourt Watch App
//
//  Mirrors the enums in the iOS target's GamePlayer.swift/Match.swift —
//  duplicated here since Watch and iOS are separate compile targets.
//

import Foundation

enum PlayerStatus: String, Codable {
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
