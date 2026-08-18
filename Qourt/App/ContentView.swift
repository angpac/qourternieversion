//
//  ContentView.swift
//  Qourt
//
//  Created by Ernesto Pacheco on 8/8/26.
//

import SwiftUI

struct ContentView: View {
    @State private var auth = AuthViewModel()
    @State private var isRestoringSession = true

    var body: some View {
        Group {
            if isRestoringSession {
                ProgressView()
            } else if !auth.isSignedIn {
                SignInView(auth: auth)
            } else if auth.role == nil {
                ChooseRoleView(auth: auth)
            } else {
                MyGamesView(auth: auth)
            }
        }
        // Fill the window before painting: a root view that is still sizing
        // itself would otherwise leave bare white around the background.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        .environment(\.font, .custom("DIN-Regular", size: 17))
        .task {
            await auth.restoreSession()
            isRestoringSession = false
        }
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                Task { await PushNotificationManager.requestAuthorizationAndRegister() }
            }
        }
    }
}

#Preview {
    ContentView()
}
