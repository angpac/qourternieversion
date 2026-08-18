//
//  ContentView.swift
//  Qourt Watch App
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = WatchStatusViewModel()
    @State private var hostViewModel = WatchHostViewModel()
    @State private var bridge = WatchSessionBridge.shared

    var body: some View {
        Group {
            if hostViewModel.isAdmin {
                // Admins are usually also playing, so both are reachable —
                // the queue on the left, the courts they're running on the right.
                TabView {
                    playerTab
                    HostCourtsView(viewModel: hostViewModel)
                }
                .tabViewStyle(.verticalPage)
            } else {
                playerTab
            }
        }
        .task {
            await viewModel.start()
            await hostViewModel.start()
        }
        .onChange(of: bridge.isSignedIn) { _, isSignedIn in
            guard isSignedIn else { return }
            // Tokens just arrived from the phone — everything that failed
            // on launch can now succeed.
            Task {
                await viewModel.start()
                await hostViewModel.start()
                await PushNotificationManager.requestAuthorizationAndRegister()
            }
        }
    }

    private var playerTab: some View {
        ScrollView {
            content.padding()
        }
        .refreshable { await viewModel.refresh() }
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
                Text(bridge.hasReceivedPayload ? "Sign in on your iPhone"
                                               : "Open Qourt on your iPhone")
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
                    .contentTransition(.numericText())
                Text("in line")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.playerStatus == .onCourt {
            onCourt
        }
    }

    @ViewBuilder
    private var onCourt: some View {
        VStack(spacing: 4) {
            Text(viewModel.courtName ?? "On court")
                .font(.headline)

            if let scoreA = viewModel.scoreA, let scoreB = viewModel.scoreB {
                Text("\(scoreA) – \(scoreB)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            } else {
                Image(systemName: "sportscourt.fill")
                    .font(.title)
                    .foregroundStyle(.tint)
            }

            if viewModel.isAwaitingConfirmation {
                Label("Waiting for admin", systemImage: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else if viewModel.currentMatchID != nil {
                NavigationLink {
                    ScoreEntryView(
                        title: viewModel.courtName ?? "Report score",
                        scoreA: viewModel.scoreA ?? 0,
                        scoreB: viewModel.scoreB ?? 0,
                        // Players don't drive the live score — only the
                        // final report counts, and it still needs admin
                        // confirmation.
                        onChange: { _, _ in },
                        onSubmit: { a, b in
                            await viewModel.reportScore(scoreA: a, scoreB: b)
                        },
                        submitLabel: "Report score"
                    )
                } label: {
                    Label("Report score", systemImage: "square.and.pencil")
                        .font(.system(size: 12))
                }
                .padding(.top, 4)
            }
        }
    }
}

#Preview {
    ContentView()
}
