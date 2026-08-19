//
//  LiveDashboardView.swift
//  Qourt
//

import SwiftUI

struct LiveDashboardView: View {
    @State private var viewModel: LiveDashboardViewModel
    @State private var courtForMatchPicker: Court?
    @State private var matchToScore: MatchWithPlayers?
    @State private var isAddingWalkIn = false
    @State private var isShowingInvite = false
    @State private var isConfirmingEndGame = false
    @State private var isShowingRoster = false
    @State private var isSendingAnnouncement = false
    @State private var isShowingCoAdmins = false
    @State private var isShowingCourts = false
    @State private var isShowingScoreboard = false

    /// Set only when this view is pushed from the just-created-game flow
    /// (inside CreateGameView's own sheet/NavigationStack) rather than
    /// selected from the games list — gives that path a "Done" button to
    /// return to the list, since there's no other exit from a pushed view
    /// inside a modal.
    private var onExitToGamesList: (() -> Void)?

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)
    private let destructiveColor = Color(red: 0xFF / 255, green: 0x42 / 255, blue: 0x45 / 255)

    init(game: Game, onExitToGamesList: (() -> Void)? = nil) {
        _viewModel = State(initialValue: LiveDashboardViewModel(game: game))
        self.onExitToGamesList = onExitToGamesList
    }

    var body: some View {
        Group {
            if viewModel.game.format.isTournament {
                BracketView(game: viewModel.game)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(viewModel.game.name)
                            .font(.custom("DIN-BlackAlternate", size: 34))

                        if !viewModel.isConnected {
                            reconnectingBanner
                        }

                        if viewModel.hasEnded {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("This game has ended. Its join code, link, and QR no longer work.", systemImage: "checkmark.seal")
                                    .font(.custom("DIN-Regular", size: 13))
                                    .foregroundStyle(Color.appSecondaryText)
                                NavigationLink("View game summary") {
                                    GameSummaryView(game: viewModel.game)
                                }
                                .font(.custom("DIN-Medium", size: 13))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12))
                        } else if viewModel.isPaused {
                            pausedBanner
                        }

                        if viewModel.isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                        } else {
                            if viewModel.isKingOfTheCourt && !viewModel.hasEnded {
                                roundTimerCard
                            }
                            courtsSection
                            queueSection
                        }
                    }
                    .padding()
                }
                .refreshable { await viewModel.loadAll() }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // In the create-a-game flow, this is pushed straight after Invite
        // Players — but that QR/join code screen is also always reachable
        // from "Invite players" in the ••• menu below, so there's no need
        // to keep it as a back-navigation stop. The back chevron here
        // exits the whole flow to My Games directly instead of popping
        // back to a screen that's already one tap away.
        .navigationBarBackButtonHidden(onExitToGamesList != nil)
        .toolbar {
            if let onExitToGamesList {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onExitToGamesList()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            // A ToolbarItemGroup, not an HStack in a single ToolbarItem with
            // its own capsule behind it. The back chevron draws no background
            // itself — that white circle is the system's toolbar chrome — so a
            // hand-rolled systemGray5 capsule sat next to it in a visibly
            // different shade and shape. Letting the system lay these out
            // keeps them grouped while matching the back button exactly.
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isAddingWalkIn = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .disabled(viewModel.hasEnded)

                menuButton
            }
        }
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
        .sheet(item: $courtForMatchPicker) { court in
            StartMatchSheet(viewModel: viewModel, court: court)
        }
        .sheet(item: $matchToScore) { match in
            CourtDetailSheet(
                viewModel: viewModel,
                matchWithPlayers: match,
                onClearedForReassignment: { court in
                    courtForMatchPicker = court
                }
            )
        }
        .sheet(isPresented: $isAddingWalkIn) {
            AddWalkInSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isSendingAnnouncement) {
            SendAnnouncementSheet(game: viewModel.game, roster: viewModel.fullRoster)
        }
        .sheet(isPresented: $isShowingInvite) {
            NavigationStack {
                InvitePlayersView(game: viewModel.game, onFinished: { isShowingInvite = false })
            }
        }
        .sheet(isPresented: $isShowingRoster) {
            NavigationStack {
                RosterView(game: viewModel.game)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isShowingRoster = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $isShowingCoAdmins) {
            NavigationStack {
                ManageCoAdminsView(game: viewModel.game)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isShowingCoAdmins = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $isShowingCourts) {
            NavigationStack {
                ManageCourtsView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isShowingCourts = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $isShowingScoreboard) {
            ScoreboardView(viewModel: viewModel)
        }
        .confirmationDialog(
            "End this game?",
            isPresented: $isConfirmingEndGame,
            titleVisibility: .visible
        ) {
            Button("End game", role: .destructive) {
                Task { await viewModel.endGame() }
            }
        } message: {
            Text("Its join code, link, and QR code will stop working. This can't be undone.")
        }
        .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var menuButton: some View {
        Menu {
            Button {
                isShowingRoster = true
            } label: {
                Label("Roster", systemImage: "list.bullet")
            }
            Button {
                isShowingInvite = true
            } label: {
                Label("Invite Players", systemImage: "qrcode")
            }
            Button {
                isSendingAnnouncement = true
            } label: {
                Label("Send announcement", systemImage: "megaphone")
            }
            .disabled(viewModel.hasEnded)
            Button {
                isShowingCoAdmins = true
            } label: {
                Label("Co-admins", systemImage: "person.badge.key")
            }
            Button {
                isShowingCourts = true
            } label: {
                Label("Manage courts", systemImage: "sportscourt")
            }
            Button {
                isShowingScoreboard = true
            } label: {
                Label("Scoreboard", systemImage: "rectangle.on.rectangle")
            }
            Button {
                Task {
                    if viewModel.isPaused {
                        await viewModel.resumeGame()
                    } else {
                        await viewModel.pauseGame()
                    }
                }
            } label: {
                if viewModel.isPaused {
                    Label("Resume game", systemImage: "play.circle")
                } else {
                    Label("Pause game", systemImage: "pause.circle")
                }
            }
            .disabled(viewModel.hasEnded)
            Button(role: .destructive) {
                isConfirmingEndGame = true
            } label: {
                Label("End game", systemImage: "flag.checkered")
            }
            .disabled(viewModel.hasEnded)
        } label: {
            Image(systemName: "ellipsis")
        }
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
        VStack(alignment: .leading, spacing: 4) {
            Label("Game paused", systemImage: "pause.circle.fill")
                .font(.custom("DIN-Medium", size: 13))
            Text("Rotation and round timers are frozen. Matches already on court can still be scored and ended as usual.")
                .font(.custom("DIN-Regular", size: 12))
                .foregroundStyle(.orange.opacity(0.8))
        }
        .foregroundStyle(.orange)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var roundTimerCard: some View {
        VStack(spacing: 8) {
            if let prepEndsAt = viewModel.prepEndsAt {
                Text("Get to your court!")
                    .font(.custom("DIN-Medium", size: 17))
                    .foregroundStyle(Color.primary)
                if prepEndsAt > Date() {
                    Text(timerInterval: Date.now...prepEndsAt, countsDown: true)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                } else {
                    Text("0")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                Text("Round starts the moment this hits zero")
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)
            } else if let roundEndsAt = viewModel.roundEndsAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, roundEndsAt.timeIntervalSince(context.date))
                    Text(formatCountdown(remaining))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.primary)
                }
                Text(viewModel.game.autoRotate ? "Rotates automatically when it hits zero" : "Tap End Round when it hits zero")
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)
                Button {
                    Task { await viewModel.rotateKingOfTheCourt() }
                } label: {
                    Group {
                        if viewModel.isRotating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("End round now")
                                .font(.custom("DIN-Medium", size: 15))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(destructiveColor, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isRotating || viewModel.isPaused)
            } else {
                Text("No round running")
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
                Button {
                    Task { await viewModel.startPrepPhase() }
                } label: {
                    Text("Start round")
                        .font(.custom("DIN-Medium", size: 15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(accentColor, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isPaused)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var courtsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Courts")
                    .font(.custom("DIN-Medium", size: 17))
                    .foregroundStyle(labelColor)
                Spacer()
                if viewModel.canAutoAssign {
                    Button {
                        Task { await viewModel.autoAssignOpenCourts() }
                    } label: {
                        Label("Auto-assign by skill", systemImage: "wand.and.stars")
                            .font(.custom("DIN-Medium", size: 12))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .overlay(Capsule().stroke(accentColor, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.courts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No courts yet.")
                        .font(.custom("DIN-Regular", size: 15))
                        .foregroundStyle(labelColor)
                    Button {
                        Task { await viewModel.createMissingCourts() }
                    } label: {
                        Text("Create \(viewModel.game.numCourts) courts")
                            .font(.custom("DIN-Medium", size: 15))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(accentColor, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.courts) { court in
                        CourtCard(
                            court: court,
                            match: viewModel.activeMatches[court.id],
                            onTapEmpty: { if !viewModel.isPaused { courtForMatchPicker = court } },
                            onTapMatch: { match in matchToScore = match }
                        )
                    }
                }
            }
        }
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.queue.isEmpty ? "Queue (0)" : "Queue ( \(viewModel.queue.count) waiting )")
                .font(.custom("DIN-Medium", size: 17))
                .foregroundStyle(labelColor)

            if viewModel.queue.isEmpty {
                Text("No players waiting.")
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(Array(viewModel.queue.enumerated()), id: \.element.id) { index, player in
                            VStack(spacing: 6) {
                                Text("\(index + 1)")
                                    .font(.custom("DIN-Medium", size: 17))
                                    .foregroundStyle(Color.appOnInverseSurface)
                                    .frame(width: 44, height: 44)
                                    .background(Color.appInverseSurface, in: Circle())
                                Text(player.displayName)
                                    .font(.custom("DIN-Regular", size: 11))
                                    .lineLimit(1)
                                    .frame(width: 60)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    Task { await viewModel.announceNextUp() }
                } label: {
                    Label("Announce next up", systemImage: "speaker.wave.2.fill")
                        .font(.custom("DIN-Medium", size: 16))
                        .foregroundStyle(Color.appOnInverseSurface)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appInverseSurface, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CourtCard: View {
    let court: Court
    let match: MatchWithPlayers?
    let onTapEmpty: () -> Void
    let onTapMatch: (MatchWithPlayers) -> Void

    private let labelColor = Color.appSecondaryText
    private let goldColor = Color(red: 0xB8 / 255, green: 0x8A / 255, blue: 0x2B / 255)
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    var body: some View {
        Button {
            if let match { onTapMatch(match) } else { onTapEmpty() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(court.name)
                        .font(.custom("DIN-Medium", size: 15))
                        .foregroundStyle(Color.primary)
                    if let override = court.singlesOverride {
                        Text(override ? "Singles" : "Doubles")
                            .font(.custom("DIN-Medium", size: 11))
                            .foregroundStyle(labelColor)
                    }
                    Spacer()
                    if court.isChallengeCourt {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(goldColor)
                    } else if let match {
                        Circle()
                            .fill(match.match.status == .awaitingConfirmation ? .orange : .green)
                            .frame(width: 8, height: 8)
                    }
                }

                if court.isChallengeCourt {
                    Text("KING'S COURT")
                        .font(.custom("DIN-Medium", size: 11))
                        .foregroundStyle(goldColor)
                }

                if let match {
                    if match.teamA.isEmpty && match.teamB.isEmpty {
                        Text("No players, tap to fix")
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(.red)
                    } else if court.isChallengeCourt && court.winStreak > 0 {
                        Text("DEFENDING")
                            .font(.custom("DIN-Medium", size: 11))
                            .foregroundStyle(labelColor)
                        Text(match.teamA.map(\.displayName).joined(separator: " • "))
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                        Text("\(court.winStreak) straight win\(court.winStreak == 1 ? "" : "s")")
                            .font(.custom("DIN-Regular", size: 11))
                            .foregroundStyle(labelColor)
                    } else {
                        // One line, "Name & Name vs Name & Name" — easier to
                        // scan at a glance than three stacked lines.
                        Text("\(match.teamA.map(\.displayName).joined(separator: " & ")) vs \(match.teamB.map(\.displayName).joined(separator: " & "))")
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                    }

                    if match.match.status == .awaitingConfirmation {
                        Text("Needs confirmation")
                            .font(.custom("DIN-Medium", size: 11))
                            .foregroundStyle(.orange)
                    } else {
                        elapsedTimer(since: match.match.startedAt)
                    }
                } else {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Tap to assign players")
                    }
                    .font(.custom("DIN-Medium", size: 13))
                    .foregroundStyle(accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .frame(minHeight: 100)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if court.isChallengeCourt {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(goldColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func elapsedTimer(since startedAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = Int(context.date.timeIntervalSince(startedAt))
            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text(String(format: "%d:%02d", elapsed / 60, elapsed % 60))
                    .font(.custom("DIN-Medium", size: 11))
                Text("elapsed")
                    .font(.custom("DIN-Regular", size: 11))
            }
            .foregroundStyle(labelColor)
        }
    }
}

#Preview {
    NavigationStack {
        LiveDashboardView(game: Game(
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
