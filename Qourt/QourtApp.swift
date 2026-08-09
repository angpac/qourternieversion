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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(deepLinkRouter)
                .onOpenURL { url in
                    deepLinkRouter.handle(url)
                }
        }
    }
}
