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
            VStack(spacing: 24) {
                if hasNoPlayers {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.red)
                        Text("This court has no players")
                            .font(.headline)
                        Text("Clearing it reopens the court and takes you straight into building a match from the queue.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Clear court & assign players")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isSaving)
                } else {
                    if isConfirmingReportedScore {
                        Label("Player-reported score, review and confirm", systemImage: "checkmark.shield")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .padding(.top, 8)
                    }

                    scoreboardRow(
                        teamNames: matchWithPlayers.teamA.map(\.displayName).joined(separator: " & "),
                        score: $scoreA
                    )

                    Text("vs")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(isConfirmingReportedScore ? "Confirm" : "End match")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                }
            }
            .padding()
            .navigationTitle(hasNoPlayers ? "Court error" : (isConfirmingReportedScore ? "Confirm score" : "Live score"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $playerToSubstitute) { outgoing in
                NavigationStack {
                    List(viewModel.queue) { candidate in
                        Button(candidate.displayName) {
                            incomingPlayer = candidate
                        }
                    }
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
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(matchWithPlayers.teamA + matchWithPlayers.teamB) { player in
                HStack {
                    Text(player.displayName)
                    Spacer()
                    Button {
                        playerToSubstitute = player
                    } label: {
                        Label("Sub", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func scoreboardRow(teamNames: String, score: Binding<Int>) -> some View {
        VStack(spacing: 8) {
            Text(teamNames)
                .font(.headline)
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
            .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
