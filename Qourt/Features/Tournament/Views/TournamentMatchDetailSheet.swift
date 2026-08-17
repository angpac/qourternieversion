//
//  TournamentMatchDetailSheet.swift
//  Qourt
//

import SwiftUI

struct TournamentMatchDetailSheet: View {
    var viewModel: BracketViewModel
    let tournamentMatch: TournamentMatch

    @Environment(\.dismiss) private var dismiss
    @State private var scoreA = 0
    @State private var scoreB = 0

    private var match: MatchWithPlayers? { viewModel.activeMatches[tournamentMatch.id] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(viewModel.name(for: tournamentMatch.teamAPlayerIds))
                        .font(.headline)
                    Text("vs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.name(for: tournamentMatch.teamBPlayerIds))
                        .font(.headline)
                }

                HStack(spacing: 40) {
                    Stepper(value: $scoreA, in: 0...99) {
                        Text("\(scoreA)").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    }
                    Stepper(value: $scoreB, in: 0...99) {
                        Text("\(scoreB)").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    }
                }

                Button("End match") {
                    Task {
                        await viewModel.endMatch(tournamentMatch, scoreA: scoreA, scoreB: scoreB)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(scoreA == scoreB)

                Spacer()
            }
            .padding()
            .navigationTitle("Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                scoreA = match?.match.scoreA ?? 0
                scoreB = match?.match.scoreB ?? 0
            }
            .onChange(of: scoreA) { _, newValue in
                if let matchID = match?.match.id {
                    Task { await viewModel.updateScore(matchID: matchID, scoreA: newValue, scoreB: scoreB) }
                }
            }
            .onChange(of: scoreB) { _, newValue in
                if let matchID = match?.match.id {
                    Task { await viewModel.updateScore(matchID: matchID, scoreA: scoreA, scoreB: newValue) }
                }
            }
        }
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
        format: .tournamentSingleElim,
        formatSettings: [:],
        joinCode: "7K2P9Q",
        status: "active"
    )
    return TournamentMatchDetailSheet(
        viewModel: BracketViewModel(game: game),
        tournamentMatch: TournamentMatch(
            id: UUID(),
            tournamentId: UUID(),
            matchId: nil,
            bracket: "winners",
            round: 1,
            slot: 0,
            nextMatchId: nil,
            teamAPlayerIds: [UUID()],
            teamBPlayerIds: [UUID()],
            advancesToSlot: nil,
            loserNextMatchId: nil,
            loserAdvancesToSlot: nil
        )
    )
}
