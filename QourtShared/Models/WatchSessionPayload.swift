//
//  WatchSessionPayload.swift
//  QourtShared/Models
//
//  Key names for the WatchConnectivity payload that carries the Supabase
//  session from phone to Watch. Lives here so both sides of the bridge
//  compile against one spelling — a typo on either side would fail
//  silently at runtime rather than at build time.
//
//  Foundation-only, per the rule for this folder: it is compiled into the
//  iOS app, the Watch app, and the widget extension.
//

import Foundation

enum WatchSessionPayload {
    static let accessTokenKey = "supabase_access_token"
    static let refreshTokenKey = "supabase_refresh_token"
    /// Sent instead of the tokens when the phone signs out.
    static let signedOutKey = "supabase_signed_out"
    /// Watch -> phone: "send me the current session".
    static let requestKey = "request_session"
}
