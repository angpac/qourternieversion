//
//  QourtAppClipApp.swift
//  QourtAppClip
//
//  Entry point for the App Clip: invoked by tapping/scanning the exact
//  same per-game QR code and join link InvitePlayersView already
//  generates (qourt-web.vercel.app/join/<code>) — no separate App Clip
//  Code needed. iOS decides what to launch based on what's installed and
//  what's registered for that URL: the full app if it's installed, this
//  App Clip if not (once net.criers.Qourt.Clip is registered against the
//  "appclips" key in web/app/.well-known/apple-app-site-association), or
//  plain Safari — which serves web/app/join/[code] — for everyone else,
//  Android included.
//

import SwiftUI

@main
struct QourtAppClipApp: App {
    @State private var joinCode: String?

    var body: some Scene {
        WindowGroup {
            AppClipRootView(joinCode: joinCode)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    joinCode = Self.joinCode(from: url)
                }
        }
    }

    /// Same parsing rule as DeepLinkRouter.joinCode(from:) in the main app
    /// — duplicated rather than shared because it's the one piece of
    /// DeepLinkRouter logic this target needs, and pulling in the rest of
    /// DeepLinkRouter would mean pulling in its Observable/import surface
    /// for a single URL-parsing function.
    private static func joinCode(from url: URL) -> String? {
        let components = url.pathComponents
        guard let joinIndex = components.firstIndex(of: "join"),
              joinIndex + 1 < components.count else { return nil }
        return components[joinIndex + 1].uppercased()
    }
}
