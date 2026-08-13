//
//  StatusEnums.swift
//  QourtShared/Models
//
//  Single source of truth for the two status enums that mirror Postgres
//  enums. These previously existed twice — once in the iOS target, once
//  in the Watch target — and drifted: `pending` was added to the DB and
//  to iOS when join approval landed, but never to the Watch copy, which
//  made any pending row fail to decode on the Watch.
//
//  Foundation-only on purpose: this folder is compiled into every target
//  (iOS, Watch, widget extension), so nothing here may import Supabase,
//  ActivityKit, UIKit, or WatchKit.
//

import Foundation

/// Mirrors the `player_status` enum in Postgres. Adding a value there
/// without adding it here makes the whole row fail to decode, which
/// usually surfaces as an empty screen rather than a visible error.
enum PlayerStatus: String, Codable {
    /// Joined a game whose `requires_approval` is on, but an admin hasn't
    /// let them in yet — so they hold no queue position.
    case pending
    case queued
    case onCourt = "on_court"
    case resting
    case removed
}

/// Mirrors the `match_status` enum in Postgres.
enum MatchStatus: String, Codable {
    case inProgress = "in_progress"
    /// A player self-reported the score; it counts only once an admin
    /// confirms it.
    case awaitingConfirmation = "awaiting_confirmation"
    case confirmed
    case cancelled
}
