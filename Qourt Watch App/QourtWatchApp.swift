//
//  QourtWatchApp.swift
//  Qourt Watch App
//

import SwiftUI

@main
struct QourtWatchApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) private var extensionDelegate

    init() {
        // Must run before any view queries Supabase, so the session handed
        // over by the phone is installed as early as possible.
        WatchSessionBridge.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchGamesListView()
            }
        }
    }
}
