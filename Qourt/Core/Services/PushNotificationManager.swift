//
//  PushNotificationManager.swift
//  Qourt
//

import Foundation
import Supabase
import UIKit
import UserNotifications

enum PushNotificationManager {
    /// The last token handed to the server, kept so sign-out can retire that
    /// exact token. Deleting every token for the profile instead would kill
    /// push on the person's other devices.
    private static let storedTokenKey = "qourt.apnsDeviceToken"

    @MainActor
    static func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    static func upload(deviceToken: Data, platform: String) async {
        guard (try? await supabase.auth.session) != nil else { return }
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        struct Params: Encodable {
            let p_device_token: String
            let p_platform: String
        }

        // Goes through a security definer function rather than a direct
        // upsert. The table is unique on device_token and its RLS policy only
        // exposes rows belonging to auth.uid(), so a device previously used by
        // another account holds a row this client cannot update — the upsert
        // failed silently and left that account still receiving push here.
        do {
            try await supabase.rpc(
                "register_device_token",
                params: Params(p_device_token: token, p_platform: platform)
            ).execute()
            UserDefaults.standard.set(token, forKey: storedTokenKey)
        } catch {
            // Push simply stays off this launch; the next registration retries.
        }
    }

    /// Retires this device's token. Call BEFORE `supabase.auth.signOut()` —
    /// the function is scoped to auth.uid(), so it does nothing once the
    /// session is gone.
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
