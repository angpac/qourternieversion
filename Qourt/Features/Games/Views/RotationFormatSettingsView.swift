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
    @State private var navigateToInvite = false

    var body: some View {
        Form {
            Section(viewModel.format.title) {
                switch viewModel.format {
                case .manual:
                    Text("No settings needed, you'll build every match yourself from the queue.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

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
            }

            if viewModel.format.isTournament {
                Section {
                    Text("Once players have joined, set up the bracket from the Live Dashboard: seed players, then start matches court by court.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.format != .manual {
                Section {
                    Toggle("Manually match players", isOn: $viewModel.formatSettings.manualMatching)
                } footer: {
                    Text("You'll build each match yourself from the queue on the Live Dashboard, instead of the app pairing players automatically.")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
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
                        if success {
                            navigateToInvite = true
                        }
                    }
                } label: {
                    if isCreating {
                        ProgressView()
                    } else {
                        Text("Create game")
                    }
                }
                .disabled(isCreating)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Rotation settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToInvite) {
            if let game = viewModel.createdGame {
                InvitePlayersView(game: game, onFinished: onFinished)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RotationFormatSettingsView(viewModel: CreateGameViewModel(), auth: AuthViewModel(), onFinished: {})
    }
}
