//
//  AppClipRootView.swift
//  QourtAppClip
//

import SwiftUI

struct AppClipRootView: View {
    let joinCode: String?

    @State private var session: GuestJoinResponse?

    var body: some View {
        Group {
            if let session {
                GuestStatusView(session: session) { self.session = nil }
            } else {
                JoinQueueView(initialJoinCode: joinCode ?? "") { session = $0 }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

#Preview {
    AppClipRootView(joinCode: "7K2P9Q")
}
