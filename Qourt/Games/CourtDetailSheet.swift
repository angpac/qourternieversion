//
//  CourtDetailSheet.swift
//  Qourt
//

import SwiftUI

struct CourtDetailSheet: View {
    var viewModel: LiveDashboardViewModel
    let matchWithPlayers: MatchWithPlayers

    @Environment(\.dismiss) private var dismiss
    @State private var scoreA: Int
    @State private var scoreB: Int
    @State private var isSaving = false

    private var isConfirmingReportedScore: Bool {
        matchWithPlayers.match.status == .awaitingConfirmation
    }

    init(viewModel: LiveDashboardViewModel, matchWithPlayers: MatchWithPlayers) {
        self.viewModel = viewModel
        self.matchWithPlayers = matchWithPlayers
        _scoreA = State(initialValue: matchWithPlayers.match.scoreA ?? 0)
        _scoreB = State(initialValue: matchWithPlayers.match.scoreB ?? 0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isConfirmingReportedScore {
                    Label("Player-reported score — review and confirm", systemImage: "checkmark.shield")
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
            .padding()
            .navigationTitle(isConfirmingReportedScore ? "Confirm score" : "Live score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
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
