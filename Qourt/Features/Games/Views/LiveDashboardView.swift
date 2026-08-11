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

    /// Set only when this view is pushed from the just-created-game flow
    /// (inside CreateGameView's own sheet/NavigationStack) rather than
    /// selected from the games list — gives that path a "Done" button to
    /// return to the list, since there's no other exit from a pushed view
    /// inside a modal.
    private var onExitToGamesList: (() -> Void)?

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
                        if !viewModel.isConnected {
                            reconnectingBanner
                        }

                        if viewModel.hasEnded {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("This game has ended. Its join code, link, and QR no longer work.", systemImage: "checkmark.seal")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                NavigationLink("View game summary") {
                                    GameSummaryView(game: viewModel.game)
                                }
                                .font(.footnote.bold())
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
        .navigationTitle(viewModel.game.name)
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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingWalkIn = true
                } label: {
                    Label("Add player", systemImage: "person.badge.plus")
                }
                .disabled(viewModel.hasEnded)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    isShowingRoster = true
                } label: {
                    Label("Roster", systemImage: "list.bullet")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    isShowingInvite = true
                } label: {
                    Label("Invite players", systemImage: "qrcode")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    isSendingAnnouncement = true
                } label: {
                    Label("Send announcement", systemImage: "megaphone")
                }
                .disabled(viewModel.hasEnded)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    isShowingCoAdmins = true
                } label: {
                    Label("Co-admins", systemImage: "person.badge.key")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    isShowingCourts = true
                } label: {
                    Label("Manage courts", systemImage: "sportscourt")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
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
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    isConfirmingEndGame = true
                } label: {
                    Label("End game", systemImage: "flag.checkered")
                }
                .disabled(viewModel.hasEnded)
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

    private var reconnectingBanner: some View {
        Label("Reconnecting, you may be seeing slightly stale data", systemImage: "wifi.slash")
            .font(.footnote.bold())
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var pausedBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Game paused", systemImage: "pause.circle.fill")
                .font(.footnote.bold())
            Text("Rotation and round timers are frozen. Matches already on court can still be scored and ended as usual.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                    .font(.headline)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let roundEndsAt = viewModel.roundEndsAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, roundEndsAt.timeIntervalSince(context.date))
                    Text(formatCountdown(remaining))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Text(viewModel.game.autoRotate ? "Rotates automatically when it hits zero" : "Tap End Round when it hits zero")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(role: .destructive) {
                    Task { await viewModel.rotateKingOfTheCourt() }
                } label: {
                    if viewModel.isRotating {
                        ProgressView()
                    } else {
                        Text("End round now")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRotating || viewModel.isPaused)
            } else {
                Text("No round running")
                    .foregroundStyle(.secondary)
                Button("Start round") {
                    Task { await viewModel.startPrepPhase() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isPaused)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var courtsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Courts")
                    .font(.headline)
                Spacer()
                if viewModel.canAutoAssign {
                    Button {
                        Task { await viewModel.autoAssignOpenCourts() }
                    } label: {
                        Label("Auto-assign by skill", systemImage: "wand.and.stars")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                }
            }

            if viewModel.courts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No courts yet.")
                        .foregroundStyle(.secondary)
                    Button("Create \(viewModel.game.numCourts) courts") {
                        Task { await viewModel.createMissingCourts() }
                    }
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
            Text("Queue (\(viewModel.queue.count))")
                .font(.headline)

            if viewModel.queue.isEmpty {
                Text("No players waiting.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.queue.enumerated()), id: \.element.id) { index, player in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(player.displayName)
                            Spacer()
                            Text(player.skillLevel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        if player.id != viewModel.queue.last?.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct CourtCard: View {
    let court: Court
    let match: MatchWithPlayers?
    let onTapEmpty: () -> Void
    let onTapMatch: (MatchWithPlayers) -> Void

    var body: some View {
        Button {
            if let match { onTapMatch(match) } else { onTapEmpty() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(court.name)
                        .font(.subheadline.bold())
                    if court.isChallengeCourt && court.winStreak > 0 {
                        Text("🔥\(court.winStreak)")
                            .font(.caption2.bold())
                    }
                    if let override = court.singlesOverride {
                        Text(override ? "Singles" : "Doubles")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let match {
                        Circle()
                            .fill(match.match.status == .awaitingConfirmation ? .orange : .green)
                            .frame(width: 8, height: 8)
                    }
                }

                if let match {
                    if match.teamA.isEmpty && match.teamB.isEmpty {
                        Text("No players, tap to fix")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        // One line, "Name & Name vs Name & Name" — easier to
                        // scan at a glance than three stacked lines.
                        Text("\(match.teamA.map(\.displayName).joined(separator: " & ")) vs \(match.teamB.map(\.displayName).joined(separator: " & "))")
                            .font(.caption)
                            .lineLimit(2)
                    }
                    if match.match.status == .awaitingConfirmation {
                        Text("Needs confirmation")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                } else {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Tap to assign players")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .frame(height: 100)
            .background(match != nil ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if match == nil {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                }
            }
        }
        .buttonStyle(.plain)
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
