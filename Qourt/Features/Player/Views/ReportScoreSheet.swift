//
//  ReportScoreSheet.swift
//  Qourt
//

import SwiftUI

struct ReportScoreSheet: View {
    var viewModel: PlayerLiveStatusViewModel
    let matchWithPlayers: MatchWithPlayers

    @Environment(\.dismiss) private var dismiss
    @State private var scoreA: Int
    @State private var scoreB: Int
    @State private var isSaving = false

    init(viewModel: PlayerLiveStatusViewModel, matchWithPlayers: MatchWithPlayers) {
        self.viewModel = viewModel
        self.matchWithPlayers = matchWithPlayers
        _scoreA = State(initialValue: matchWithPlayers.match.scoreA ?? 0)
        _scoreB = State(initialValue: matchWithPlayers.match.scoreB ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(matchWithPlayers.teamA.map(\.displayName).joined(separator: " & ")) {
                    Stepper("Score: \(scoreA)", value: $scoreA, in: 0...99)
                }
                Section(matchWithPlayers.teamB.map(\.displayName).joined(separator: " & ")) {
                    Stepper("Score: \(scoreB)", value: $scoreB, in: 0...99)
                }
            }
            .navigationTitle("Report score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            await viewModel.reportScore(scoreA: scoreA, scoreB: scoreB)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Submit")
                        }
                    }
                    .disabled(isSaving)
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
        format: .kingOfTheCourt,
        formatSettings: [:],
        joinCode: "7K2P9Q",
        status: "active"
    )
    let playerA = GamePlayer(id: UUID(), gameId: game.id, profileId: nil, displayName: "Alex Chen", skillLevel: "Intermediate", status: .onCourt, queuePosition: nil, joinedAt: Date())
    let playerB = GamePlayer(id: UUID(), gameId: game.id, profileId: nil, displayName: "Jamie Lee", skillLevel: "Advanced", status: .onCourt, queuePosition: nil, joinedAt: Date())
    let match = Match(id: UUID(), gameId: game.id, courtId: UUID(), status: .inProgress, scoreA: 5, scoreB: 3, startedAt: Date(), endedAt: nil)
    return ReportScoreSheet(
        viewModel: PlayerLiveStatusViewModel(game: game),
        matchWithPlayers: MatchWithPlayers(match: match, teamA: [playerA], teamB: [playerB])
    )
}
