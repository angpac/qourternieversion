//
//  PlayerActivityAttributes.swift
//  Qourt (shared between the app and the widget extension)
//

import ActivityKit
import Foundation

/// Drives the Live Activity shown on the Lock Screen / Dynamic Island for
/// a player's current game — queue position while waiting, live score
/// once they're on court. `gameName` never changes for the life of the
/// activity so it's a static attribute; everything that changes over time
/// lives in ContentState.
struct PlayerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String // "queued" | "onCourt"
        var queuePosition: Int?
        var courtName: String?
        var teammateNames: String?
        var opponentNames: String?
        var scoreA: Int?
        var scoreB: Int?
    }

    var gameName: String
}
