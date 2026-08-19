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
    private let skipsInitialLoad: Bool

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)
    private let destructiveColor = Color(red: 0xFF / 255, green: 0x42 / 255, blue: 0x45 / 255)

    init(game: Game, previewViewModel: PlayerLiveStatusViewModel? = nil) {
        _viewModel = State(initialValue: previewViewModel ?? PlayerLiveStatusViewModel(game: game))
        skipsInitialLoad = previewViewModel != nil
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
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
                .frame(maxWidth: .infinity)
            } else {
                Text("Couldn't find your spot in this game.")
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(viewModel.game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingRoster = true
                } label: {
                    Label("Roster", systemImage: "person.2.fill")
                        .foregroundStyle(Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255))
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
        .task {
            guard !skipsInitialLoad else { return }
            await viewModel.start()
        }
        .onDisappear {
            guard !skipsInitialLoad else { return }
            viewModel.stop()
        }
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
                Button {
                    Task { await viewModel.stepOut() }
                } label: {
                    Text("Skip my turn")
                        .font(.custom("DIN-Medium", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            case .resting:
                Button {
                    Task { await viewModel.stepBackIn() }
                } label: {
                    Text("I'm ready to play")
                        .font(.custom("DIN-Medium", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            default:
                EmptyView()
            }

            if player.status == .queued || player.status == .resting || player.status == .pending {
                Button(role: .destructive) {
                    isConfirmingLeave = true
                } label: {
                    Text(player.status == .pending ? "Cancel request" : "Leave game")
                        .font(.custom("DIN-Medium", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(destructiveColor, in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func lastResultBanner(_ result: LastMatchResult) -> some View {
        HStack {
            Image(systemName: result.won ? "trophy.fill" : "figure.badminton")
                .foregroundStyle(result.won ? .yellow : labelColor)
            Text(result.won ? "You won your last match" : "You lost your last match")
                .font(.custom("DIN-Medium", size: 15))
                .foregroundStyle(Color.primary)
            Spacer()
            Text("\(result.scoreA) – \(result.scoreB)")
                .font(.custom("DIN-Medium", size: 15))
                .foregroundStyle(Color.primary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(result.won ? Color.yellow.opacity(0.15) : Color.appSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func nameHeader(_ player: GamePlayer) -> some View {
        VStack(spacing: 2) {
            Text(player.displayName)
                .font(.custom("DIN-Medium", size: 22))
                .foregroundStyle(Color.primary)
            Text(player.skillLevel)
                .font(.custom("DIN-Regular", size: 15))
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
    }

    private func prepCountdownBanner(_ prepEndsAt: Date) -> some View {
        VStack(spacing: 6) {
            Text("Get to your court!")
                .font(.custom("DIN-Medium", size: 17))
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
            .font(.custom("DIN-Medium", size: 13))
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var pausedBanner: some View {
        Label("Game paused — sit tight, the host will resume shortly", systemImage: "pause.circle.fill")
            .font(.custom("DIN-Medium", size: 13))
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private func announcementBanner(_ announcement: Announcement) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "megaphone.fill")
                .foregroundStyle(accentColor)
            Text(announcement.message)
                .font(.custom("DIN-Regular", size: 15))
                .foregroundStyle(Color.primary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(accentColor.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }

    private var queuedCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.stand.line.dotted.figure.stand")
                .font(.system(size: 40))
                .foregroundStyle(accentColor)
            Text("You're #\(viewModel.queuePosition ?? 0) in line")
                .font(.custom("DIN-Medium", size: 22))
                .foregroundStyle(Color.primary)
            if let groupsAheadText = viewModel.groupsAheadText {
                Text(groupsAheadText)
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
            }
            Text(viewModel.game.format.title)
                .font(.custom("DIN-Regular", size: 13))
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var pickerCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.yellow)
            Text("You're the Picker!")
                .font(.custom("DIN-Medium", size: 20))
                .foregroundStyle(Color.primary)
            Text("Choose 3 players from the line to build your match.")
                .font(.custom("DIN-Regular", size: 15))
                .foregroundStyle(labelColor)
                .multilineTextAlignment(.center)
            Button {
                isShowingPicker = true
            } label: {
                Text("Build your match")
                    .font(.custom("DIN-Medium", size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(accentColor, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
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
                    .font(.custom("DIN-Medium", size: 22))
                    .foregroundStyle(Color.primary)
            }

            if let match = viewModel.currentMatch {
                VStack(spacing: 4) {
                    Text(match.teamA.map(\.displayName).joined(separator: " & "))
                        .font(.custom("DIN-Medium", size: 17))
                        .foregroundStyle(Color.primary)
                    Text("vs")
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(labelColor)
                    Text(match.teamB.map(\.displayName).joined(separator: " & "))
                        .font(.custom("DIN-Medium", size: 17))
                        .foregroundStyle(Color.primary)
                }

                if let scoreA = match.match.scoreA, let scoreB = match.match.scoreB {
                    Text("\(scoreA) – \(scoreB)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.primary)
                }

                if match.match.status == .awaitingConfirmation {
                    Label("Waiting for admin to confirm", systemImage: "clock")
                        .font(.custom("DIN-Medium", size: 13))
                        .foregroundStyle(.orange)
                } else {
                    Button {
                        isReportingScore = true
                    } label: {
                        Text("Report score")
                            .font(.custom("DIN-Medium", size: 15))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .overlay(Capsule().stroke(accentColor, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statusCard(icon: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(labelColor)
            Text(title)
                .font(.custom("DIN-Medium", size: 20))
                .foregroundStyle(Color.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var rosterLink: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Join code")
                .font(.custom("DIN-Regular", size: 13))
                .foregroundStyle(labelColor)
            Text(viewModel.game.joinCode)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private let previewGame = Game(
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
)

#Preview("With announcement") {
    let vm = PlayerLiveStatusViewModel(game: previewGame)
    vm.isLoading = false
    vm.myPlayer = GamePlayer(
        id: UUID(),
        gameId: previewGame.id,
        profileId: nil,
        displayName: "Awan Minton",
        skillLevel: "Advanced",
        status: .queued,
        queuePosition: 3,
        joinedAt: Date()
    )
    vm.queuePosition = 3
    vm.announcements = [
        Announcement(
            id: UUID(),
            gameId: previewGame.id,
            senderId: UUID(),
            targetPlayerId: nil,
            message: "Court 2 is closed for the next round, sorry for the inconvenience!",
            sentAt: Date()
        )
    ]
    return NavigationStack {
        PlayerLiveStatusView(game: previewGame, previewViewModel: vm)
    }
}

#Preview {
    NavigationStack {
        PlayerLiveStatusView(game: previewGame)
    }
}
