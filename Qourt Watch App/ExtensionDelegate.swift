//
//  ExtensionDelegate.swift
//  Qourt Watch App
//

import WatchKit

final class ExtensionDelegate: NSObject, WKApplicationDelegate {
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        Task { await PushNotificationManager.upload(deviceToken: deviceToken) }
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        // No device token this launch — the Watch app still works, just without push.
    }
}
