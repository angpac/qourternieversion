//
//  ContentView.swift
//  Qourt Watch App
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = WatchStatusViewModel()

    var body: some View {
        ScrollView {
            content
                .padding()
        }
        .task { await viewModel.start() }
        .refreshable { await viewModel.start() }
        .onChange(of: viewModel.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                Task { await PushNotificationManager.requestAuthorizationAndRegister() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if !viewModel.isSignedIn {
            VStack(spacing: 6) {
                Image(systemName: "iphone.gen3")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Sign in on your iPhone")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
        } else if viewModel.gameName == nil {
            VStack(spacing: 6) {
                Image(systemName: "figure.badminton")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("No active game")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.playerStatus == .queued {
            VStack(spacing: 4) {
                Text(viewModel.gameName ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("#\(viewModel.queuePosition ?? 0)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("in line")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.playerStatus == .onCourt {
            VStack(spacing: 4) {
                Text(viewModel.courtName ?? "On court")
                    .font(.headline)
                if let scoreA = viewModel.scoreA, let scoreB = viewModel.scoreB {
                    Text("\(scoreA) – \(scoreB)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                } else {
                    Image(systemName: "sportscourt.fill")
                        .font(.title)
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
