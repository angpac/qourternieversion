//
//  WatchSettingsView.swift
//  Qourt Watch App
//
//  Mirrors the phone's Settings role switch (SettingsView.swift): a local,
//  in-memory-style toggle — persisted here via @AppStorage since the Watch
//  has no equivalent of re-picking a role at launch — with no write to the
//  backend. Only shown once WatchGamesListView's admin-eligibility probe
//  (WatchHostViewModel.checkIsAdmin) confirms this profile actually owns
//  or co-admins a game.
//

import SwiftUI

struct WatchSettingsView: View {
    @AppStorage("watchRole") private var storedRole = WatchRole.player.rawValue
    let isEligibleForAdmin: Bool

    private var role: WatchRole { WatchRole(rawValue: storedRole) ?? .player }

    var body: some View {
        List {
            if isEligibleForAdmin {
                Button {
                    storedRole = (role == .admin ? WatchRole.player : WatchRole.admin).rawValue
                } label: {
                    Label(
                        role == .admin ? "Switch to Player" : "Switch to Admin",
                        systemImage: "arrow.left.arrow.right"
                    )
                }
                .tint(.green)
            } else {
                Text("Signed in as Player")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        WatchSettingsView(isEligibleForAdmin: true)
    }
}
