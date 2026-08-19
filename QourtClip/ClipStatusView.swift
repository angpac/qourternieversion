//
//  ClipStatusView.swift
//  QourtClip
//
//  Native twin of web/app/status/page.tsx.
//
//  One deliberate difference: the web page offers Web Push, and this
//  doesn't. An App Clip can only ask for an ephemeral notification
//  permission that lasts hours, and the honest fix for someone who wants
//  to be told they're up is the full app — which is what the install
//  prompt at the bottom is for.
//

import SwiftUI

struct ClipStatusView: View {
    @Bindable var viewModel: ClipViewModel
    @State private var isConfirmingLeave = false
    @State private var isReportingScore = false
    @State private var scoreA = 0
    @State private var scoreB = 0
    @State private var isPicking = false
    @State private var pickedIDs: [UUID] = []
    @State private var pickerError: String?

    var body: some View {
        ZStack {
            ClipTheme.background.ignoresSafeArea()

            if let error = viewModel.statusError, viewModel.status == nil {
                errorState(error)
            } else if let status = viewModel.status {
                content(status)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task {
            await viewModel.refresh()
            viewModel.startPolling()
        }
        .onDisappear { viewModel.stopPolling() }
        .confirmationDialog(
            "Leave this game?",
            isPresented: $isConfirmingLeave,
            titleVisibility: .visible
        ) {
            Button("Leave game", role: .destructive) {
                Task { await viewModel.leave() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll be removed from the roster.")
        }
        .sheet(isPresented: $isReportingScore) {
            if let status = viewModel.status {
                ClipReportScoreSheet(
                    status: status,
                    scoreA: $scoreA,
                    scoreB: $scoreB,
                    onSubmit: {
                        await viewModel.reportScore(scoreA: scoreA, scoreB: scoreB)
                    }
                )
            }
        }
        .sheet(isPresented: $isPicking) {
            if let status = viewModel.status {
                ClipPickerSheet(
                    pool: status.picker_pool ?? [],
                    pickedIDs: $pickedIDs,
                    errorMessage: $pickerError,
                    onStart: {
                        pickerError = await viewModel.startPickerMatch(teammateIDs: pickedIDs)
                        return pickerError == nil
                    }
                )
            }
        }
    }

    // MARK: - Main content

    private func content(_ status: ClipStatus) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                header(status)

                if let latest = viewModel.announcements.first {
                    announcementBanner(latest)
                }

                if let won = status.wonLastMatch {
                    lastResultBanner(status, won: won)
                }

                ClipCard(padding: 32) {
                    VStack(spacing: 0) {
                        statusBlock(status)

                        if status.player_status == .queued && status.is_picker {
                            pickerPrompt
                        }

                        if [.queued, .resting, .pending].contains(status.player_status) {
                            footerActions(status)
                        }
                    }
                }

                installPrompt

                Text("Join code: \(status.join_code)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(ClipTheme.emerald100)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 48)
        }
        .refreshable { await viewModel.refresh() }
    }

    private func header(_ status: ClipStatus) -> some View {
        VStack(spacing: 2) {
            Text(status.game_name)
                .font(.subheadline)
                .foregroundStyle(ClipTheme.emerald100)
            Text(status.my_display_name)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            Text(status.my_skill_level)
                .font(.subheadline)
                .foregroundStyle(ClipTheme.emerald100)
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private func statusBlock(_ status: ClipStatus) -> some View {
        switch status.player_status {
        case .pending:
            centeredCard(
                emoji: "⌛",
                title: "Waiting for approval",
                subtitle: "The host needs to approve you before you can join the line."
            )
        case .queued:
            VStack(spacing: 8) {
                Text("⏳").font(.system(size: 44))
                Text("You're #\(status.queue_position ?? 0) in line")
                    .font(.title2.bold())
                    .foregroundStyle(ClipTheme.zinc900)
                    .contentTransition(.numericText())
                if let groups = status.groupsAheadText {
                    Text(groups)
                        .font(.subheadline)
                        .foregroundStyle(ClipTheme.zinc600)
                }
                Text(status.game_format)
                    .font(.subheadline)
                    .foregroundStyle(ClipTheme.zinc500)
            }
            .multilineTextAlignment(.center)
        case .onCourt:
            onCourtBlock(status)
        case .resting:
            VStack(spacing: 12) {
                Text("You're resting. Step back in whenever you're ready.")
                    .font(.body)
                    .foregroundStyle(ClipTheme.zinc600)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await viewModel.stepIn() }
                } label: {
                    Text("I'm ready to play")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(ClipTheme.emerald700, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        case .removed:
            VStack(spacing: 12) {
                Text("You've left this game.")
                    .foregroundStyle(ClipTheme.zinc600)
                Button("Join another game") { viewModel.startOver() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ClipTheme.emerald700)
            }
        }
    }

    private func onCourtBlock(_ status: ClipStatus) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                // Status never rides on colour alone — the dot is paired
                // with the wording below it.
                Circle()
                    .fill(status.match_status == .awaitingConfirmation
                          ? ClipTheme.amber500 : Color.green)
                    .frame(width: 10, height: 10)
                Text(status.court_name ?? "On court")
                    .font(.title2.bold())
                    .foregroundStyle(ClipTheme.zinc900)
            }

            if let teamA = status.team_a, let teamB = status.team_b {
                VStack(spacing: 4) {
                    Text(teamA.map(\.display_name).joined(separator: " & "))
                        .font(.headline)
                        .foregroundStyle(ClipTheme.zinc800)
                    Text("vs")
                        .font(.caption)
                        .foregroundStyle(ClipTheme.zinc400)
                    Text(teamB.map(\.display_name).joined(separator: " & "))
                        .font(.headline)
                        .foregroundStyle(ClipTheme.zinc800)
                }
                .multilineTextAlignment(.center)
            }

            if let a = status.score_a, let b = status.score_b {
                Text("\(a) – \(b)")
                    .font(.system(size: 36, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(ClipTheme.zinc900)
                    .contentTransition(.numericText())
            }

            if status.match_status == .awaitingConfirmation {
                Text("Waiting for admin to confirm")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ClipTheme.amber600)
            } else {
                Button {
                    scoreA = 0
                    scoreB = 0
                    isReportingScore = true
                } label: {
                    Text("Report score")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ClipTheme.emerald700)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ClipTheme.emerald700, lineWidth: 1)
                        )
                }
            }
        }
    }

    private var pickerPrompt: some View {
        VStack(spacing: 8) {
            Text("⭐").font(.system(size: 28))
            Text("You're the Picker!")
                .font(.headline)
                .foregroundStyle(ClipTheme.zinc900)
            Text("Choose 3 players from the line to build your match.")
                .font(.subheadline)
                .foregroundStyle(ClipTheme.zinc600)
                .multilineTextAlignment(.center)
            Button {
                pickedIDs = []
                pickerError = nil
                isPicking = true
            } label: {
                Text("Build your match")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ClipTheme.emerald700, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(ClipTheme.amber50, in: RoundedRectangle(cornerRadius: 12))
        .padding(.top, 24)
    }

    private func footerActions(_ status: ClipStatus) -> some View {
        VStack(spacing: 12) {
            Divider().background(ClipTheme.zinc100)
            if status.player_status == .queued {
                Button("Skip my turn") {
                    Task { await viewModel.stepOut() }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ClipTheme.zinc600)
                .underline()
            }
            Button(status.player_status == .pending ? "Cancel request" : "Leave game") {
                isConfirmingLeave = true
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(ClipTheme.red600)
        }
        .padding(.top, 24)
    }

    // MARK: - Banners

    private func announcementBanner(_ announcement: ClipAnnouncement) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("📣")
            Text(announcement.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ClipTheme.zinc800)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
    }

    private func lastResultBanner(_ status: ClipStatus, won: Bool) -> some View {
        HStack {
            Text(won ? "🏆 You won your last match" : "You lost your last match")
                .font(.headline)
                .foregroundStyle(ClipTheme.zinc800)
            Spacer(minLength: 8)
            Text("\(status.last_match_score_a ?? 0) – \(status.last_match_score_b ?? 0)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(ClipTheme.zinc600)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(won ? ClipTheme.amber100 : Color.white, in: RoundedRectangle(cornerRadius: 12))
    }

    /// The one thing the clip has that the web page doesn't need: a way
    /// out of the clip and into the real app, which is where notifications
    /// and a persistent identity live.
    private var installPrompt: some View {
        VStack(spacing: 4) {
            Text("Get the full app")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("Keep your profile between games and get notified when you're up.")
                .font(.caption)
                .foregroundStyle(ClipTheme.emerald100)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button("Join a different game") { viewModel.startOver() }
                .font(.headline)
                .foregroundStyle(ClipTheme.emerald800)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(24)
    }

    private func centeredCard(emoji: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(emoji).font(.system(size: 44))
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(ClipTheme.zinc900)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(ClipTheme.zinc500)
        }
        .multilineTextAlignment(.center)
    }
}
