//
//  PushNotificationManager.swift
//  Qourt Watch App
//

import Foundation
import Supabase
import UserNotifications
import WatchKit

enum PushNotificationManager {
    private static let storedTokenKey = "qourt.apnsDeviceToken"

    @MainActor
    static func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        WKApplication.shared().registerForRemoteNotifications()
    }

    static func upload(deviceToken: Data) async {
        guard (try? await supabase.auth.session) != nil else { return }
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        struct Params: Encodable {
            let p_device_token: String
            let p_platform: String
        }

        // Security definer RPC, same reason as on the phone: a token row left
        // behind by a previous account can't be reassigned through RLS.
        do {
            try await supabase.rpc(
                "register_device_token",
                params: Params(p_device_token: token, p_platform: "watchos")
            ).execute()
            UserDefaults.standard.set(token, forKey: storedTokenKey)
        } catch {
            // Push stays off this launch; the next registration retries.
        }
    }

    /// Retires this Watch's token when the phone reports a sign-out.
    static func unregisterCurrentDevice() async {
        guard let token = UserDefaults.standard.string(forKey: storedTokenKey) else { return }
        struct Params: Encodable { let p_device_token: String }
        _ = try? await supabase.rpc(
            "unregister_device_token",
            params: Params(p_device_token: token)
        ).execute()
        UserDefaults.standard.removeObject(forKey: storedTokenKey)
    }
}
