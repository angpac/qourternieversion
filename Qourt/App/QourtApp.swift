//
//  QourtApp.swift
//  Qourt
//
//  Created by Ernesto Pacheco on 8/8/26.
//

import SwiftUI

@main
struct QourtApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var deepLinkRouter = DeepLinkRouter()

    init() {
        // Starts the WatchConnectivity session that ships the Supabase
        // session to the Watch. Safe on devices with no Watch paired:
        // WCSession.isSupported() gates it.
        PhoneWatchSessionBridge.shared.activate()

        UITableView.appearance().backgroundColor = .appBackground
        UICollectionView.appearance().backgroundColor = .appBackground
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(deepLinkRouter)
                .onOpenURL { url in
                    deepLinkRouter.handle(url)
                }
                // Re-push on every foreground: the access token rotates, and
                // this is the cheapest place to catch a sign-in or sign-out
                // that happened since the Watch last heard from us.
                .task {
                    await PhoneWatchSessionBridge.shared.syncSessionToWatch()
                }
        }
    }
}
