//
//  QourtWatchApp.swift
//  Qourt Watch App
//

import SwiftUI

@main
struct QourtWatchApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) private var extensionDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
