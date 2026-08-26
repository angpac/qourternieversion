//
//  ContentView.swift
//  Qourt Watch App
//
//  A player's own place in one game — line position, court, score, and the
//  host's announcements — reached by tapping a game in WatchGamesListView.
//  Scoped to that one game via WatchStatusViewModel.start(gameID:), rather
//  than the old auto-detect-the-active-game flow this replaced.
//

import SwiftUI

struct ContentView: View {
    let game: WatchGame
    @State private var viewModel = WatchStatusViewModel()
    @State private var isConfirmingLeave = false

    var body: some View {
        ScrollView {
            content.padding(.horizontal, 4)
        }
        .navigationTitle(game.name)
        .refreshable { await viewModel.refresh() }
        .task {
            // Matches the "ended games skip the round trip" comment on
            // `content` below — without this guard, start(gameID:) still
            // ran a game_players fetch and opened a 4-table realtime
            // channel for a game that's already over, on every visit.
            guard !game.hasEnded else { return }
            await viewModel.start(gameID: game.id)
        }
        .onDisappear {
            // HostCourtsView does the same for WatchHostViewModel; this
            // view's own realtime channel needs the same cleanup, or it's
            // left open server-side every time a game is visited.
            Task { await viewModel.unsubscribe() }
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
        // `game.hasEnded` covers arriving at an already-ended game (the list
        // skips the round trip entirely for those, see `.task` below).
        // `viewModel.hasEnded` covers the game ending while this screen is
        // already open — kept live by WatchStatusViewModel's own realtime
        // subscription to the games row, since none of the tables the rest
        // of this screen reacts to change when a game just ends.
        if game.hasEnded || viewModel.hasEnded {
            statusCard(
                icon: "flag.checkered",
                title: "This session has ended",
                subtitle: "Thanks for playing — ask the host if there's another one coming up."
            )
            .padding(.vertical, 4)
        } else if viewModel.isLoading {
            ProgressView()
        } else {
            VStack(spacing: 10) {
                if let latest = viewModel.announcements.first {
                    announcementBanner(latest)
                }

                statusSection
                actionSection
            }
            .padding(.vertical, 4)
        }
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
    NavigationStack {
        ContentView(game: WatchGame(id: UUID(), name: "Sunday Open Play", status: "live"))
    }
}
