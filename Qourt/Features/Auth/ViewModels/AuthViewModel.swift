//
//  AuthViewModel.swift
//  Qourt
//

import AuthenticationServices
import Foundation
import Supabase

enum AppRole: String {
    case admin
    case player
}

@Observable
final class AuthViewModel {
    var userID: UUID?
    var displayName: String?
    var defaultSkillLevel: String = "Beginner"
    var role: AppRole?
    var errorMessage: String?

    var isSignedIn: Bool { userID != nil }
    var needsNameSetup: Bool { isSignedIn && (displayName?.isEmpty ?? true) }

    @MainActor
    func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            userID = session.user.id

            // Hand the fresh session to the Watch immediately. Without this
            // the Watch stays signed out until the next cold launch of the
            // phone app.
            await PhoneWatchSessionBridge.shared.syncSessionToWatch()
            await loadProfile()
        } catch {
            userID = nil
        }
    }

    @MainActor
    func signIn(with authorization: ASAuthorization) async {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let identityTokenData = credential.identityToken,
            let identityToken = String(data: identityTokenData, encoding: .utf8)
        else {
            errorMessage = "Apple didn't return a usable credential."
            return
        }

        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: identityToken)
            )
            userID = session.user.id

            // Apple only shares the account holder's name on the very first
            // authorization for this app; every later sign-in gets nothing
            // back here. Only used as the seed for a brand new profile row —
            // ignoreDuplicates below means it never overwrites a returning
            // user's already-stored (and possibly since-edited) name.
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            await ensureProfile(seedDisplayName: fullName)
            await loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func ensureProfile(seedDisplayName: String) async {
        guard let userID else { return }
        struct ProfileUpsert: Encodable {
            let id: UUID
            let display_name: String
        }
        do {
            try await supabase.from("profiles")
                .upsert(
                    ProfileUpsert(id: userID, display_name: seedDisplayName),
                    onConflict: "id",
                    ignoreDuplicates: true
                )
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadProfile() async {
        guard let userID else { return }
        struct Profile: Decodable {
            let display_name: String
            let default_skill_level: String?
        }
        do {
            let profile: Profile = try await supabase.from("profiles")
                .select("display_name, default_skill_level")
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            displayName = profile.display_name
            defaultSkillLevel = profile.default_skill_level ?? "Beginner"
        } catch {
            // No profile yet is fine right after first sign-in.
        }
    }

    @MainActor
    func setDisplayName(_ name: String) async {
        guard let userID else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try await supabase.from("profiles")
                .update(["display_name": trimmed])
                .eq("id", value: userID)
                .execute()
            displayName = trimmed
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func setDefaultSkillLevel(_ level: String) async {
        guard let userID else { return }
        do {
            try await supabase.from("profiles")
                .update(["default_skill_level": level])
                .eq("id", value: userID)
                .execute()
            defaultSkillLevel = level
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func chooseRole(_ role: AppRole) {
        self.role = role
    }

    @MainActor
    func signOut() async {
        // Before signOut: the RPC is scoped to auth.uid(), so once the
        // session is gone the row can no longer be found — and it would keep
        // this device receiving the previous account's notifications.
        await PushNotificationManager.unregisterCurrentDevice()
        try? await supabase.auth.signOut()
        userID = nil
        displayName = nil
        role = nil
        // Tells the Watch to clear its session too, so it can't keep
        // showing a queue position for a signed-out account.
        await PhoneWatchSessionBridge.shared.syncSessionToWatch()
    }
}
