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
