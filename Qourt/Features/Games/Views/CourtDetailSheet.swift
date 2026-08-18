//
//  CourtDetailSheet.swift
//  Qourt
//

import SwiftUI

struct CourtDetailSheet: View {
    var viewModel: LiveDashboardViewModel
    let matchWithPlayers: MatchWithPlayers
    /// Called after "Clear this court" succeeds, with the now-open court —
    /// lets the caller jump straight into building a match on it instead
    /// of dismissing back to the grid and making the admin find and tap
    /// the court a second time.
    var onClearedForReassignment: (Court) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var scoreA: Int
    @State private var scoreB: Int
    @State private var isSaving = false
    @State private var playerToSubstitute: GamePlayer?
    @State private var incomingPlayer: GamePlayer?

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)
    private let destructiveColor = Color(red: 0xFF / 255, green: 0x42 / 255, blue: 0x45 / 255)

    private var isConfirmingReportedScore: Bool {
        matchWithPlayers.match.status == .awaitingConfirmation
    }

    /// Should never happen — startMatch() now hard-guards against writing
    /// a match with empty teams — but this makes an already-broken match
    /// (from before that guard existed) obvious and one tap to fix,
    /// instead of a silent blank scoreboard nobody can act on.
    private var hasNoPlayers: Bool {
        matchWithPlayers.teamA.isEmpty && matchWithPlayers.teamB.isEmpty
    }

    init(
        viewModel: LiveDashboardViewModel,
        matchWithPlayers: MatchWithPlayers,
        onClearedForReassignment: @escaping (Court) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.matchWithPlayers = matchWithPlayers
        self.onClearedForReassignment = onClearedForReassignment
        _scoreA = State(initialValue: matchWithPlayers.match.scoreA ?? 0)
        _scoreB = State(initialValue: matchWithPlayers.match.scoreB ?? 0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Text(hasNoPlayers ? "Court error" : (isConfirmingReportedScore ? "Confirm score" : "Live score"))
                        .font(.custom("DIN-Medium", size: 17))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Text("Close")
                                .font(.custom("DIN-Medium", size: 15))
                                .foregroundStyle(Color.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .background(Color(.systemGray5), in: Capsule())
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
                .padding()

                VStack(spacing: 24) {
                    if hasNoPlayers {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(destructiveColor)
                            Text("This court has no players")
                                .font(.custom("DIN-Medium", size: 17))
                                .foregroundStyle(Color.primary)
                            Text("Clearing it reopens the court and takes you straight into building a match from the queue.")
                                .font(.custom("DIN-Regular", size: 13))
                                .foregroundStyle(labelColor)
                                .multilineTextAlignment(.center)
                        }
                        .padding()

                        Spacer()

                        Button {
                            Task {
                                isSaving = true
                                let court = viewModel.courts.first { $0.id == matchWithPlayers.match.courtId }
                                await viewModel.endMatch(matchWithPlayers, scoreA: 0, scoreB: 0)
                                isSaving = false
                                dismiss()
                                if let court {
                                    onClearedForReassignment(court)
                                }
                            }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Clear court & assign players")
                                    .font(.custom("DIN-Medium", size: 16))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(destructiveColor, in: Capsule())
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    } else {
                        if isConfirmingReportedScore {
                            Label("Player-reported score, review and confirm", systemImage: "checkmark.shield")
                                .font(.custom("DIN-Regular", size: 13))
                                .foregroundStyle(.orange)
                                .padding(.top, 8)
                        }

                        scoreboardRow(
                            teamNames: matchWithPlayers.teamA.map(\.displayName).joined(separator: " & "),
                            score: $scoreA
                        )

                        Text("vs")
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(labelColor)

                        scoreboardRow(
                            teamNames: matchWithPlayers.teamB.map(\.displayName).joined(separator: " & "),
                            score: $scoreB
                        )

                        playersOnCourtSection

                        Spacer()

                        Button {
                            Task {
                                isSaving = true
                                await viewModel.endMatch(matchWithPlayers, scoreA: scoreA, scoreB: scoreB)
                                isSaving = false
                                dismiss()
                            }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text(isConfirmingReportedScore ? "Confirm" : "End match")
                                    .font(.custom("DIN-Medium", size: 16))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(accentColor, in: Capsule())
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                }
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $playerToSubstitute) { outgoing in
                NavigationStack {
                    List(viewModel.queue) { candidate in
                        Button(candidate.displayName) {
                            incomingPlayer = candidate
                        }
                        .font(.custom("DIN-Regular", size: 17))
                        .foregroundStyle(Color.primary)
                        .listRowBackground(Color.appSurface)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground.ignoresSafeArea())
                    .navigationTitle("Sub in for \(outgoing.displayName)")
                    .navigationBarTitleDisplayMode(.inline)
                    .overlay {
                        if viewModel.queue.isEmpty {
                            ContentUnavailableView("No one in the queue", systemImage: "person.3")
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { playerToSubstitute = nil }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Substitute player?",
                isPresented: Binding(
                    get: { incomingPlayer != nil },
                    set: { if !$0 { incomingPlayer = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Confirm substitution") {
                    if let outgoing = playerToSubstitute, let incoming = incomingPlayer {
                        Task {
                            await viewModel.substitutePlayer(in: matchWithPlayers, outgoing: outgoing, incoming: incoming)
                            playerToSubstitute = nil
                            incomingPlayer = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    incomingPlayer = nil
                }
            } message: {
                if let outgoing = playerToSubstitute, let incoming = incomingPlayer {
                    Text("This is for exceptions like an injury, not routine pairing changes. \(outgoing.displayName) goes back to the end of the queue, \(incoming.displayName) takes their place on court right now, mid-match.")
                }
            }
        }
    }

    private var playersOnCourtSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Players on court")
                .font(.custom("DIN-Regular", size: 13))
                .foregroundStyle(labelColor)
            VStack(spacing: 0) {
                ForEach(matchWithPlayers.teamA + matchWithPlayers.teamB) { player in
                    HStack {
                        Text(player.displayName)
                            .font(.custom("DIN-Regular", size: 17))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Button {
                            playerToSubstitute = player
                        } label: {
                            Label("Sub", systemImage: "arrow.triangle.2.circlepath")
                                .font(.custom("DIN-Medium", size: 13))
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .overlay(
                                    Capsule().stroke(accentColor, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()

                    if player.id != (matchWithPlayers.teamA + matchWithPlayers.teamB).last?.id {
                        Rectangle()
                            .fill(labelColor.opacity(0.15))
                            .frame(height: 1)
                            .padding(.horizontal)
                    }
                }
            }
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func scoreboardRow(teamNames: String, score: Binding<Int>) -> some View {
        VStack(spacing: 8) {
            Text(teamNames)
                .font(.custom("DIN-Medium", size: 17))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                Button {
                    guard score.wrappedValue > 0 else { return }
                    score.wrappedValue -= 1
                    pushScore()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                }

                Text("\(score.wrappedValue)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .frame(minWidth: 90)
                    .contentTransition(.numericText())
                    .animation(.default, value: score.wrappedValue)

                Button {
                    score.wrappedValue += 1
                    pushScore()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                }
            }
            .foregroundStyle(accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func pushScore() {
        Task { await viewModel.updateScore(matchID: matchWithPlayers.match.id, scoreA: scoreA, scoreB: scoreB) }
    }
}

#Preview {
    let game = Game(
        id: UUID(),
        name: "Sunday Open Play",
        location: "Community Center",
        startsAt: Date(),
        numCourts: 4,
        isDoubles: true,
        format: .kingOfTheCourt,
        formatSettings: [:],
        joinCode: "7K2P9Q",
        status: "draft"
    )
    let playerA = GamePlayer(id: UUID(), gameId: game.id, profileId: nil, displayName: "Alex Chen", skillLevel: "Intermediate", status: .onCourt, queuePosition: nil, joinedAt: Date())
    let playerB = GamePlayer(id: UUID(), gameId: game.id, profileId: nil, displayName: "Jamie Lee", skillLevel: "Advanced", status: .onCourt, queuePosition: nil, joinedAt: Date())
    let match = Match(id: UUID(), gameId: game.id, courtId: UUID(), status: .inProgress, scoreA: 11, scoreB: 7, startedAt: Date(), endedAt: nil)
    return CourtDetailSheet(
        viewModel: LiveDashboardViewModel(game: game),
        matchWithPlayers: MatchWithPlayers(match: match, teamA: [playerA], teamB: [playerB])
    )
}
