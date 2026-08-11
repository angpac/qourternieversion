//
//  PlayerLiveStatusView.swift
//  Qourt
//

import SwiftUI

struct PlayerLiveStatusView: View {
    @State private var viewModel: PlayerLiveStatusViewModel
    @State private var isReportingScore = false
    @State private var isConfirmingLeave = false
    @State private var isShowingRoster = false
    @State private var isShowingHistory = false
    @State private var isShowingPicker = false

    init(game: Game) {
        _viewModel = State(initialValue: PlayerLiveStatusViewModel(game: game))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView().padding(.top, 60)
            } else if let player = viewModel.myPlayer {
                VStack(spacing: 20) {
                    // Shown so an admin can glance at a player's own phone
                    // to confirm who they are, courtside.
                    nameHeader(player)

                    if !viewModel.isConnected {
                        reconnectingBanner
                    }

                    if viewModel.isPaused {
                        pausedBanner
                    }

                    if let prepEndsAt = viewModel.prepEndsAt {
                        prepCountdownBanner(prepEndsAt)
                    }

                    if let latest = viewModel.announcements.first {
                        announcementBanner(latest)
                    }

                    if let result = viewModel.lastMatchResult {
                        lastResultBanner(result)
                    }

                    switch player.status {
                    case .pending:
                        statusCard(icon: "hourglass", title: "Waiting for approval", subtitle: "The host needs to approve you before you can join the line.")
                    case .queued:
                        queuedCard
                        if viewModel.isPicker && !viewModel.isPaused {
                            pickerCard
                        }
                    case .onCourt:
                        onCourtCard
                    case .resting:
                        statusCard(icon: "pause.circle.fill", title: "You're resting", subtitle: "Step back in whenever you're ready.")
                    case .removed:
                        statusCard(icon: "xmark.circle.fill", title: "You've left this game", subtitle: nil)
                    }

                    if player.status != .removed {
                        playerActions(for: player)
                    }

                    rosterLink
                }
                .padding()
            } else {
                Text("Couldn't find your spot in this game.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)
            }
        }
        .navigationTitle(viewModel.game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingRoster = true
                } label: {
                    Label("Roster", systemImage: "list.bullet")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    isShowingHistory = true
                } label: {
                    Label("History & stats", systemImage: "chart.bar")
                }
            }
        }
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
        .refreshable { await viewModel.loadAll() }
        .sheet(isPresented: $isShowingPicker) {
            PickerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isReportingScore) {
            if let match = viewModel.currentMatch {
                ReportScoreSheet(viewModel: viewModel, matchWithPlayers: match)
            }
        }
        .sheet(isPresented: $isShowingRoster) {
            NavigationStack {
                PlayerRosterView(game: viewModel.game)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isShowingRoster = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $isShowingHistory) {
            NavigationStack {
                PlayerHistoryView(game: viewModel.game)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isShowingHistory = false }
                        }
                    }
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
        }
    }

    @ViewBuilder
    private func playerActions(for player: GamePlayer) -> some View {
        VStack(spacing: 8) {
            switch player.status {
            case .queued:
                Button("Skip my turn") {
                    Task { await viewModel.stepOut() }
                }
                .buttonStyle(.bordered)
            case .resting:
                Button("I'm ready to play") {
                    Task { await viewModel.stepBackIn() }
                }
                .buttonStyle(.borderedProminent)
            default:
                EmptyView()
            }

            if player.status == .queued || player.status == .resting || player.status == .pending {
                Button(player.status == .pending ? "Cancel request" : "Leave game", role: .destructive) {
                    isConfirmingLeave = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.footnote)
            }
        }
    }

    private func lastResultBanner(_ result: LastMatchResult) -> some View {
        HStack {
            Image(systemName: result.won ? "trophy.fill" : "figure.badminton")
                .foregroundStyle(result.won ? .yellow : .secondary)
            Text(result.won ? "You won your last match" : "You lost your last match")
                .font(.subheadline.bold())
            Spacer()
            Text("\(result.scoreA) – \(result.scoreB)")
                .font(.subheadline.monospacedDigit())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(result.won ? Color.yellow.opacity(0.15) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func nameHeader(_ player: GamePlayer) -> some View {
        VStack(spacing: 2) {
            Text(player.displayName)
                .font(.title2.bold())
            Text(player.skillLevel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func prepCountdownBanner(_ prepEndsAt: Date) -> some View {
        VStack(spacing: 6) {
            Text("Get to your court!")
                .font(.headline)
            if prepEndsAt > Date() {
                Text(timerInterval: Date.now...prepEndsAt, countsDown: true)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text("0")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.orange, in: RoundedRectangle(cornerRadius: 16))
    }

    private var reconnectingBanner: some View {
        Label("Reconnecting, you may be seeing slightly stale data", systemImage: "wifi.slash")
            .font(.footnote.bold())
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var pausedBanner: some View {
        Label("Game paused — sit tight, the host will resume shortly", systemImage: "pause.circle.fill")
            .font(.footnote.bold())
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private func announcementBanner(_ announcement: Announcement) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "megaphone.fill")
                .foregroundStyle(.tint)
            Text(announcement.message)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var queuedCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.stand.line.dotted.figure.stand")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("You're #\(viewModel.queuePosition ?? 0) in line")
                .font(.title2.bold())
            if let groupsAheadText = viewModel.groupsAheadText {
                Text(groupsAheadText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(viewModel.game.format.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var pickerCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.yellow)
            Text("You're the Picker!")
                .font(.title3.bold())
            Text("Choose 3 players from the line to build your match.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Build your match") {
                isShowingPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
    }

    private var onCourtCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.currentMatch?.match.status == .awaitingConfirmation ? .orange : .green)
                    .frame(width: 10, height: 10)
                Text(viewModel.myCourt?.name ?? "On court")
                    .font(.title2.bold())
            }

            if let match = viewModel.currentMatch {
                VStack(spacing: 4) {
                    Text(match.teamA.map(\.displayName).joined(separator: " & "))
                        .font(.headline)
                    Text("vs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(match.teamB.map(\.displayName).joined(separator: " & "))
                        .font(.headline)
                }

                if let scoreA = match.match.scoreA, let scoreB = match.match.scoreB {
                    Text("\(scoreA) – \(scoreB)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                }

                if match.match.status == .awaitingConfirmation {
                    Label("Waiting for admin to confirm", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Button("Report score") {
                        isReportingScore = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statusCard(icon: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var rosterLink: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Join code")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(viewModel.game.joinCode)
                .font(.system(.body, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        PlayerLiveStatusView(game: Game(
            id: UUID(),
            name: "Sunday Open Play",
            location: nil,
            startsAt: nil,
            numCourts: 4,
            isDoubles: true,
            format: .kingOfTheCourt,
            formatSettings: [:],
            joinCode: "ABC123",
            status: "live"
        ))
    }
}
