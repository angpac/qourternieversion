//
//  SupabaseClient.swift
//  Qourt
//

import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://izanyjrbgguidttflpvp.supabase.co")!
    static let anonKey = "sb_publishable_Jlrs6NAUoAb5uUBl_XO6Gg_QQ0LGtwq"

    // Shared with the Watch target via the keychain-access-groups entitlement
    // on both targets, so the Watch app sees the same signed-in session as
    // the phone instead of needing its own sign-in flow.
    static let sharedKeychainAccessGroup = "67YBGP3A84.net.criers.Qourt.shared"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            storage: KeychainLocalStorage(accessGroup: SupabaseConfig.sharedKeychainAccessGroup),
            // Opting in early to what becomes the default in supabase-swift 3.
            // Leaving it off logs a runtime warning on every launch. Safe here
            // because nothing in the app observes `authStateChanges` — every
            // caller reads `supabase.auth.session`, which refreshes on demand
            // and throws when the stored session can't be renewed, so an
            // expired session still can't slip through as signed-in.
            emitLocalSessionAsInitialSession: true
        )
    )
)
