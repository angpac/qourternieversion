//
//  WatchGamesListView.swift
//  Qourt Watch App
//
//  Root screen. Replaces the old single-game auto-detect flow with a real
//  list — admin and player see different queries for the same reason
//  MyGamesView does on the phone (WatchGamesViewModel.load(role:)), and
//  which one loads is driven by the role toggle in Settings.
//

import SwiftUI

struct WatchGamesListView: View {
    @AppStorage("watchRole") private var storedRole = WatchRole.player.rawValue
    @State private var gamesViewModel = WatchGamesViewModel()
    @State private var bridge = WatchSessionBridge.shared
    @State private var eligibilityProbe = WatchHostViewModel()
    @State private var isSignedIn = false
    @State private var isEligibleForAdmin = false

    private var role: WatchRole { WatchRole(rawValue: storedRole) ?? .player }

    var body: some View {
        Group {
            if !isSignedIn {
                signedOutState
            } else if gamesViewModel.isLoading {
                ProgressView()
            } else if gamesViewModel.games.isEmpty {
                emptyState
            } else {
                GamesList(games: gamesViewModel.games, role: role)
            }
        }
        .navigationTitle("My Games")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    WatchSettingsView(isEligibleForAdmin: isEligibleForAdmin)
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .refreshable { await gamesViewModel.load(role: role) }
        .task { await loadEverything() }
        .onChange(of: storedRole) {
            Task { await gamesViewModel.load(role: role) }
        }
        .onChange(of: bridge.isSignedIn) { _, signedIn in
            guard signedIn else {
                // The phone can push a signed-out context while this
                // screen is already open (WatchSessionBridge.swift's
                // signedOutKey handling) — without this, the list just
                // keeps showing whatever it last loaded instead of
                // falling back to signedOutState.
                isSignedIn = false
                return
            }
            // Tokens just arrived from the phone — everything that failed
            // on launch can now succeed.
            Task {
                await loadEverything()
                await PushNotificationManager.requestAuthorizationAndRegister()
            }
        }
    }

    private func loadEverything() async {
        guard (try? await supabase.auth.session)?.user.id != nil else {
            isSignedIn = false
            WatchSessionBridge.shared.requestSessionFromPhone()
            return
        }
        isSignedIn = true
        await eligibilityProbe.checkIsAdmin()
        isEligibleForAdmin = eligibilityProbe.isAdmin
        // Eligibility can be revoked (e.g. a co-admin invite pulled) while
        // storedRole is still "admin" from before. Without this, Settings'
        // switch disappears entirely once ineligible — nothing left to tap
        // it back with — and this list keeps querying admin games that no
        // longer resolve to anything, stranding whatever player games this
        // profile actually has.
        if !isEligibleForAdmin && role == .admin {
            storedRole = WatchRole.player.rawValue
        }
        await gamesViewModel.load(role: role)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "figure.badminton")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(role == .admin ? "No games yet" : "No games joined")
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private var signedOutState: some View {
        VStack(spacing: 6) {
            Image(systemName: "iphone.gen3")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(bridge.hasReceivedPayload ? "Sign in on your iPhone"
                                           : "Open Qourt on your iPhone")
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }
}

/// Split out from WatchGamesListView so the ForEach/List's type-checking
/// happens in a small, isolated context of its own, rather than nested
/// inside a struct that also carries @AppStorage/@State and several other
/// computed properties.
private struct GamesList: View {
    let games: [WatchGame]
    let role: WatchRole

    var body: some View {
        List {
            ForEach(games) { game in
                NavigationLink {
                    if role == .admin {
                        HostCourtsView(viewModel: WatchHostViewModel(), game: game)
                    } else {
                        ContentView(game: game)
                    }
                } label: {
                    GameRow(game: game)
                }
            }
        }
    }
}

private struct GameRow: View {
    let game: WatchGame

    var body: some View {
        HStack {
            Text(game.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            Spacer()
            // "ONGOING" not "LIVE" — games.status also has draft/paused
            // (see game_status enum), which aren't actually live play,
            // and the phone's own My Games groups all three the same
            // neutral way rather than claiming a more specific status
            // than it means. Status never rides on colour alone, matching
            // the rest of the app's convention — there's always a word.
            Text(game.hasEnded ? "ENDED" : "ONGOING")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(game.hasEnded ? Color.secondary : Color.green)
        }
    }
}

#Preview {
    NavigationStack {
        WatchGamesListView()
    }
}
