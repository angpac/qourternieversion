//
//  WatchSessionBridge.swift
//  Qourt Watch App
//
//  Receives the Supabase session from the phone and installs it into the
//  Watch's own Supabase client, so the Watch can query and subscribe on
//  its own rather than proxying every call through the phone.
//

import Foundation
import Supabase
import WatchConnectivity

@Observable
final class WatchSessionBridge: NSObject {
    static let shared = WatchSessionBridge()

    /// Flips to true once a session is installed, so the UI can drop the
    /// "Sign in on your iPhone" placeholder the moment tokens land.
    var isSignedIn = false
    /// Set when the phone has never sent tokens — distinct from "signed
    /// out", so the Watch can tell the user to open the app on the phone.
    var hasReceivedPayload = false

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        // The phone may already have stored a context before this launch.
        apply(context: session.receivedApplicationContext)
    }

    /// Ask the phone for a fresh session — used on launch, and whenever a
    /// query fails because the stored refresh token has expired.
    func requestSessionFromPhone() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([WatchSessionPayload.requestKey: true], replyHandler: nil, errorHandler: nil)
    }

    private func apply(context: [String: Any]) {
        guard !context.isEmpty else { return }
        hasReceivedPayload = true

        if context[WatchSessionPayload.signedOutKey] as? Bool == true {
            Task { @MainActor in
                // Same ordering as the phone: retire this Watch's token while
                // the session is still valid, or it keeps receiving pushes for
                // the account that just signed out.
                await PushNotificationManager.unregisterCurrentDevice()
                try? await supabase.auth.signOut()
                isSignedIn = false
            }
            return
        }

        guard let accessToken = context[WatchSessionPayload.accessTokenKey] as? String,
              let refreshToken = context[WatchSessionPayload.refreshTokenKey] as? String else { return }

        Task { @MainActor in
            do {
                _ = try await supabase.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
                isSignedIn = true
            } catch {
                isSignedIn = false
            }
        }
    }
}

extension WatchSessionBridge: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard state == .activated else { return }
        apply(context: session.receivedApplicationContext)
        requestSessionFromPhone()
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context: context)
    }

    /// If the phone was out of range when this app launched, the request
    /// above went nowhere. Ask again the moment it comes back.
    func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable, !isSignedIn else { return }
        requestSessionFromPhone()
    }
}
