//
//  PhoneWatchSessionBridge.swift
//  Qourt
//
//  Ships the signed-in Supabase session from the phone to the Watch.
//
//  The Watch previously relied on the shared keychain access group to see
//  the phone's session. That can't work: a keychain access group is shared
//  between apps on ONE device, and the Watch is a separate device with its
//  own keychain. Nothing crossed that boundary, so the Watch was always
//  signed out. WatchConnectivity is the only supported transport.
//

import Foundation
import Supabase
import WatchConnectivity

@Observable
final class PhoneWatchSessionBridge: NSObject {
    static let shared = PhoneWatchSessionBridge()

    /// Bumped whenever we hand tokens over, purely so the Watch can tell a
    /// fresh payload from a replayed one it already applied.
    private var lastSentAccessToken: String?

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Push the current session to the Watch.
    ///
    /// Uses `updateApplicationContext` rather than `sendMessage` because it
    /// is queued by the system and delivered even when the Watch app isn't
    /// running — the Watch gets the tokens the next time it wakes, instead
    /// of only when both apps happen to be foregrounded together.
    func syncSessionToWatch() async {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        guard let authSession = try? await supabase.auth.session else {
            // Signed out on the phone — tell the Watch to drop its session
            // too, otherwise it keeps showing a stale queue position.
            try? session.updateApplicationContext([WatchSessionPayload.signedOutKey: true])
            lastSentAccessToken = nil
            return
        }

        // Re-sending an identical access token wakes the Watch app for no
        // reason; the refresh token is what it actually needs to persist.
        guard authSession.accessToken != lastSentAccessToken else { return }

        do {
            try session.updateApplicationContext([
                WatchSessionPayload.accessTokenKey: authSession.accessToken,
                WatchSessionPayload.refreshTokenKey: authSession.refreshToken
            ])
            lastSentAccessToken = authSession.accessToken
        } catch {
            // Non-fatal: the Watch re-requests on its next launch.
            lastSentAccessToken = nil
        }
    }
}

extension PhoneWatchSessionBridge: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard state == .activated else { return }
        Task { await syncSessionToWatch() }
    }

    /// The Watch asks for tokens on launch — covers the case where the
    /// application context was delivered before the user signed in, or the
    /// access token has since been rotated.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message[WatchSessionPayload.requestKey] as? Bool == true else { return }
        lastSentAccessToken = nil        // force a resend
        Task { await syncSessionToWatch() }
    }

    // Required on iOS so the session can be re-activated after the user
    // switches to a different paired Watch.
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
