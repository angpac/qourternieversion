//
//  RotationFormatSettingsView.swift
//  Qourt
//

import SwiftUI

struct RotationFormatSettingsView: View {
    @Bindable var viewModel: CreateGameViewModel
    var auth: AuthViewModel
    var onFinished: () -> Void

    @State private var isCreating = false
    /// Drives the push by VALUE, not by a Bool.
    ///
    /// This was `@State private var navigateToInvite = false` paired with
    /// `navigationDestination(isPresented:)` whose body was
    /// `if let game = viewModel.createdGame { ... }`. Those are two
    /// independent pieces of state: the flag says "push now" while the
    /// optional says "here's what to show". If the push resolved while the
    /// optional read as nil, SwiftUI pushed an EMPTY destination — the blank
    /// white screen, with the game already inserted in the database. Holding
    /// the game itself means there is nothing to push until there's
    /// something to show.
    @State private var createdGame: Game?

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    var body: some View {
        Form {
            Section {
                switch viewModel.format {
                case .manual:
                    Text("No settings needed, you'll build every match yourself from the queue.")
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(labelColor)

                case .kingOfTheCourt:
                    Stepper(
                        "Round length: \(viewModel.formatSettings.roundMinutes) min",
                        value: $viewModel.formatSettings.roundMinutes,
                        in: 3...20
                    )
                    Stepper(
                        "Prep time before each round: \(viewModel.formatSettings.prepSeconds) sec",
                        value: $viewModel.formatSettings.prepSeconds,
                        in: 0...60,
                        step: 5
                    )
                    Toggle("Auto-rotate when timer ends", isOn: $viewModel.formatSettings.autoRotate)
                        .tint(accentColor)

                case .pegBoard:
                    Stepper(
                        "Picker chooses from next \(viewModel.formatSettings.pickerPoolSize)",
                        value: $viewModel.formatSettings.pickerPoolSize,
                        in: 8...12
                    )

                case .fourOffFourOn:
                    Stepper(
                        "Point target: \(viewModel.formatSettings.pointTarget)",
                        value: $viewModel.formatSettings.pointTarget,
                        in: 11...21,
                        step: 1
                    )

                case .challengeCourt:
                    Picker("Win cap", selection: $viewModel.formatSettings.winCap) {
                        Text("2 in a row").tag(2)
                        Text("3 in a row").tag(3)
                    }

                case .halfCourtKingminton:
                    Picker("Point target", selection: $viewModel.formatSettings.kingmintonPointTarget) {
                        Text("First to 3").tag(3)
                        Text("First to 5").tag(5)
                    }

                case .tournamentSingleElim, .tournamentDoubleElim:
                    Stepper(
                        "Point target: \(viewModel.formatSettings.pointTarget)",
                        value: $viewModel.formatSettings.pointTarget,
                        in: 11...21,
                        step: 1
                    )
                }
            } header: {
                Text(viewModel.format.title)
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
            }

            if viewModel.format.isTournament {
                Section {
                    Text("Once players have joined, set up the bracket from the Live Dashboard: seed players, then start matches court by court.")
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(labelColor)
                }
            } else if viewModel.format != .manual {
                Section {
                    Toggle("Manually match players", isOn: $viewModel.formatSettings.manualMatching)
                        .tint(accentColor)
                } footer: {
                    Text("You'll build each match yourself from the queue on the Live Dashboard, instead of the app pairing players automatically.")
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(labelColor)
                }
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
                        guard let userID = auth.userID else { return }
                        isCreating = true
                        let success = await viewModel.createGame(ownerID: userID)
                        isCreating = false
                        // Only navigate once the game is actually in hand.
                        // If creation reported success but produced no game,
                        // surface it rather than pushing a blank screen and
                        // leaving the admin to create a duplicate.
                        if success {
                            if let game = viewModel.createdGame {
                                createdGame = game
                            } else {
                                viewModel.errorMessage = "The game was created but couldn't be opened. Pull to refresh your games list."
                            }
                        }
                    }
                } label: {
                    Group {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create game")
                                .font(.custom("DIN-Medium", size: 16))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColor, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isCreating)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Rotation settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $createdGame) { game in
            InvitePlayersView(game: game, onFinished: onFinished)
        }
    }
}

#Preview {
    NavigationStack {
        RotationFormatSettingsView(viewModel: CreateGameViewModel(), auth: AuthViewModel(), onFinished: {})
    }
}
