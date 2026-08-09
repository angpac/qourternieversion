//
//  PushNotificationManager.swift
//  Qourt
//

import Foundation
import Supabase
import UIKit
import UserNotifications

enum PushNotificationManager {
    @MainActor
    static func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    static func upload(deviceToken: Data, platform: String) async {
        guard let userID = (try? await supabase.auth.session)?.user.id else { return }
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        struct DeviceTokenUpsert: Encodable {
            let profile_id: UUID
            let device_token: String
            let platform: String
        }

        try? await supabase.from("apns_device_tokens")
            .upsert(
                DeviceTokenUpsert(profile_id: userID, device_token: token, platform: platform),
                onConflict: "device_token"
            )
            .execute()
    }
}
