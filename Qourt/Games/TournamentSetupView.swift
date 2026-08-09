//
//  TournamentSetupView.swift
//  Qourt
//

import SwiftUI

struct TournamentSetupView: View {
    let game: Game
    var onGenerated: (Tournament) -> Void

    @State private var viewModel: TournamentSetupViewModel

    init(game: Game, onGenerated: @escaping (Tournament) -> Void) {
        self.game = game
        self.onGenerated = onGenerated
        _viewModel = State(initialValue: TournamentSetupViewModel(game: game))
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Elimination", value: game.format == .tournamentDoubleElim ? "Double" : "Single")
                LabeledContent("Players in queue", value: "\(viewModel.roster.count)")
            }

            Section("Seeding") {
                Picker("Seed by", selection: $viewModel.seedingMethod) {
                    Text("Skill level").tag("skill")
                    Text("Random").tag("random")
                    Text("Manual order").tag("manual")
                }
                .pickerStyle(.segmented)
            }

            if viewModel.seedingMethod == "manual" {
                Section {
                    ForEach(viewModel.manualOrder) { player in
                        Text(player.displayName)
                    }
                    .onMove { indices, newOffset in
                        viewModel.manualOrder.move(fromOffsets: indices, toOffset: newOffset)
                    }
                } header: {
                    Text("Seed order")
                } footer: {
                    Text("Top of the list is seed #1 — kept furthest apart from seed #2 in the bracket.")
                }
                .environment(\.editMode, .constant(.active))
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task {
                        if let tournament = await viewModel.generateBracket() {
                            onGenerated(tournament)
                        }
                    }
                } label: {
                    if viewModel.isGenerating {
                        ProgressView()
                    } else {
                        Text("Generate bracket")
                    }
                }
                .disabled(viewModel.isGenerating || viewModel.roster.count < 2)
            } footer: {
                Text("This locks in the bracket — anyone who joins after this can't be added to it.")
            }
        }
        .navigationTitle("Set up tournament")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}
