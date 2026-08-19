//
//  ContentView.swift
//  Qourt Watch App
//
//  The Watch is a player companion for now: your place in line, your
//  court, your score, and the host's announcements. Running a game from
//  the wrist is deliberately not here yet — `HostCourtsView` and
//  `WatchHostViewModel` hold that work until rotation can be settled off
//  the phone. Anyone who administers a game is told so directly rather
//  than being left to wonder where the controls went.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = WatchStatusViewModel()
    @State private var hostViewModel = WatchHostViewModel()
    @State private var bridge = WatchSessionBridge.shared
    @State private var isConfirmingLeave = false

    var body: some View {
        ScrollView {
            content.padding(.horizontal, 4)
        }
        .refreshable { await viewModel.refresh() }
        .task {
            await viewModel.start()
            await hostViewModel.checkIsAdmin()
        }
        .onChange(of: bridge.isSignedIn) { _, isSignedIn in
            guard isSignedIn else { return }
            // Tokens just arrived from the phone — everything that failed
            // on launch can now succeed.
            Task {
                await viewModel.start()
                await hostViewModel.checkIsAdmin()
                await PushNotificationManager.requestAuthorizationAndRegister()
            }
        }
        .confirmationDialog(
            "Leave this game?",
            isPresented: $isConfirmingLeave,
            titleVisibility: .visible
        ) {
            Button("Leave game", role: .destructive) {
                Task { await viewModel.leaveGame() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if !viewModel.isSignedIn {
            signedOutState
        } else {
            VStack(spacing: 10) {
                if let gameName = viewModel.gameName {
                    Text(gameName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let latest = viewModel.announcements.first {
                    announcementBanner(latest)
                }

                statusSection
                actionSection

                // Shown last so it never pushes the player's own status
                // below the fold, but always shown to an admin — including
                // when they have no active game, which would otherwise
                // read as "the Watch app is broken".
                if hostViewModel.isAdmin {
                    hostPendingCard
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - States

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

    @ViewBuilder
    private var statusSection: some View {
        switch viewModel.playerStatus {
        case .none:
            statusCard(
                icon: "figure.badminton",
                title: "No active game",
                subtitle: "Join a game on your iPhone."
            )
        case .pending:
            statusCard(
                icon: "hourglass",
                title: "Waiting for approval",
                subtitle: "The host needs to let you in."
            )
        case .queued:
            queuedCard
        case .onCourt:
            onCourtCard
        case .resting:
            statusCard(
                icon: "pause.circle.fill",
                title: "You're resting",
                subtitle: "Step back in when you're ready."
            )
        case .removed:
            statusCard(
                icon: "xmark.circle.fill",
                title: "You've left this game",
                subtitle: nil
            )
        }
    }

    private var queuedCard: some View {
        VStack(spacing: 2) {
            Text("#\(viewModel.queuePosition ?? 0)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            if let total = viewModel.queueTotal {
                Text(viewModel.queuePosition == 1
                     ? "You're up next · \(total) in line"
                     : "of \(total) in line")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("in line")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var onCourtCard: some View {
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
                Label("Waiting for host", systemImage: "clock")
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
                        // final report counts, and it still needs host
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

    // MARK: - Actions

    @ViewBuilder
    private var actionSection: some View {
        switch viewModel.playerStatus {
        case .queued:
            VStack(spacing: 6) {
                Button {
                    Task { await viewModel.skipTurn() }
                } label: {
                    Label("Skip my turn", systemImage: "forward.end")
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                leaveButton
            }
        case .resting:
            VStack(spacing: 6) {
                Button {
                    Task { await viewModel.stepBackIn() }
                } label: {
                    Label("I'm ready", systemImage: "figure.badminton")
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                leaveButton
            }
        case .pending:
            leaveButton
        default:
            EmptyView()
        }
    }

    private var leaveButton: some View {
        Button(role: .destructive) {
            isConfirmingLeave = true
        } label: {
            Label(viewModel.playerStatus == .pending ? "Cancel request" : "Leave game",
                  systemImage: "xmark")
                .font(.footnote)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    // MARK: - Pieces

    private func announcementBanner(_ announcement: Announcement) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 12))
                .foregroundStyle(.tint)
            Text(announcement.message)
                .font(.system(size: 13))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Tells a host, in as many words, that the Watch is player-only right
    /// now — so an admin who wears it doesn't hunt for court controls that
    /// were never here.
    private var hostPendingCard: some View {
        VStack(spacing: 4) {
            Label("Hosting", systemImage: "iphone.gen3")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Courts and scoring stay on your iPhone for now. The Watch shows your own play.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
        .padding(.top, 2)
    }

    private func statusCard(icon: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(title)
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ContentView()
}
