//
//  QourtClipApp.swift
//  QourtClip
//
//  The App Clip a guest gets when they scan a game's QR code (or tap its
//  link) on an iPhone without Qourt installed. iOS routes it here rather
//  than to the web guest client; someone who already has the full app gets
//  the app instead, via the same Universal Link, and Android keeps going
//  to the web.
//

import SwiftUI

@main
struct QourtClipApp: App {
    @State private var viewModel = ClipViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                switch viewModel.phase {
                case .joining:
                    ClipJoinView(viewModel: viewModel)
                case .joined:
                    ClipStatusView(viewModel: viewModel)
                }
            }
            // The invoking URL arrives as a user activity. It can land
            // either before or after the first view appears, so both the
            // launch payload and later invocations funnel to one handler.
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                viewModel.handle(url: url)
            }
        }
    }
}
