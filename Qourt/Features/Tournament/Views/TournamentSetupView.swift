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

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(game.format == .tournamentDoubleElim ? "Double" : "Single")
                        .font(.custom("DIN-Regular", size: 17))
                        .foregroundStyle(Color.primary)
                } label: {
                    Text("Elimination")
                        .font(.custom("DIN-Regular", size: 17))
                        .foregroundStyle(Color.primary)
                }
                LabeledContent {
                    Text("\(viewModel.roster.count)")
                        .font(.custom("DIN-Regular", size: 17))
                        .foregroundStyle(Color.primary)
                } label: {
                    Text("Players in queue")
                        .font(.custom("DIN-Regular", size: 17))
                        .foregroundStyle(Color.primary)
                }
            }

            Section {
                Picker("Seed by", selection: $viewModel.seedingMethod) {
                    Text("Skill level").tag("skill")
                    Text("Random").tag("random")
                    Text("Manual order").tag("manual")
                }
                .pickerStyle(.segmented)
                .tint(accentColor)
            } header: {
                Text("Seeding")
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)
            }

            if viewModel.seedingMethod == "manual" {
                Section {
                    ForEach(viewModel.manualOrder) { player in
                        Text(player.displayName)
                            .font(.custom("DIN-Regular", size: 17))
                            .foregroundStyle(Color.primary)
                    }
                    .onMove { indices, newOffset in
                        viewModel.manualOrder.move(fromOffsets: indices, toOffset: newOffset)
                    }
                } header: {
                    Text("Seed order")
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(labelColor)
                } footer: {
                    Text("Top of the list is seed #1, kept furthest apart from seed #2 in the bracket.")
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(labelColor)
                }
                .environment(\.editMode, .constant(.active))
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(.red)
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
                    Group {
                        if viewModel.isGenerating {
                            ProgressView()
                        } else {
                            Text("Generate bracket")
                                .font(.custom("DIN-Medium", size: 16))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        (viewModel.isGenerating || viewModel.roster.count < 2) ? Color(.systemGray5) : accentColor,
                        in: Capsule()
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGenerating || viewModel.roster.count < 2)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("This locks in the bracket. Anyone who joins after this can't be added to it.")
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Set up tournament")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

#Preview {
    NavigationStack {
        TournamentSetupView(
            game: Game(
                id: UUID(),
                name: "Sunday Open Play",
                location: "Community Center",
                startsAt: Date(),
                numCourts: 4,
                isDoubles: true,
                format: .tournamentSingleElim,
                formatSettings: [:],
                joinCode: "7K2P9Q",
                status: "draft"
            ),
            onGenerated: { _ in }
        )
    }
}
