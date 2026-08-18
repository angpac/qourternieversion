//
//  LiveActivityManager.swift
//  Qourt
//

import ActivityKit
import Foundation
import Supabase

/// Owns the one Live Activity a player can have running for their current
/// game. Starting/ending happens locally (the app is always running at
/// that moment — the player just joined or just left). Keeping it
/// *live* while backgrounded needs server push, so the activity's push
/// token is uploaded and the send-push Edge Function updates it directly
/// alongside the regular "you're up!" notification.
@MainActor
enum LiveActivityManager {
    private static var currentActivity: Activity<PlayerActivityAttributes>?

    static func start(gameName: String, state: PlayerActivityAttributes.ContentState, gamePlayerID: UUID) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            // The most common reason a Live Activity "never shows up": the
            // user (or a fresh simulator) has Live Activities turned off for
            // this app, or globally, in system Settings. Logged rather than
            // silently returning so this is diagnosable from the console
            // instead of looking like the feature is just broken.
            print("[LiveActivityManager] Not starting — Live Activities are disabled in system settings.")
            return
        }

        if currentActivity != nil {
            Task { await update(state) }
            return
        }

        do {
            let activity = try Activity.request(
                attributes: PlayerActivityAttributes(gameName: gameName),
                content: .init(state: state, staleDate: nil),
                pushType: .token
            )
            currentActivity = activity
            Task { await observePushToken(activity, gamePlayerID: gamePlayerID) }
        } catch {
            // Live Activities are a nice-to-have — never block the rest of
            // the app on this — but the failure reason still needs to be
            // visible somewhere, or "it just doesn't show up" is undebuggable.
            print("[LiveActivityManager] Activity.request failed: \(error)")
        }
    }

    static func update(_ state: PlayerActivityAttributes.ContentState) async {
        guard let currentActivity else { return }
        await currentActivity.update(.init(state: state, staleDate: nil))
    }

    static func end() async {
        guard let activity = currentActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }

    private static func observePushToken(_ activity: Activity<PlayerActivityAttributes>, gamePlayerID: UUID) async {
        for await tokenData in activity.pushTokenUpdates {
            let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
            await upload(token: token, gamePlayerID: gamePlayerID)
        }
    }

    private static func upload(token: String, gamePlayerID: UUID) async {
        struct TokenUpsert: Encodable {
            let game_player_id: UUID
            let push_token: String
        }
        _ = try? await supabase.from("live_activity_tokens")
            .upsert(TokenUpsert(game_player_id: gamePlayerID, push_token: token), onConflict: "game_player_id")
            .execute()
    }
}
