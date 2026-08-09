//
//  CreateGameView.swift
//  Qourt
//

import SwiftUI

struct CreateGameView: View {
    @Bindable var viewModel: CreateGameViewModel
    var auth: AuthViewModel
    var onFinished: () -> Void

    var body: some View {
        Form {
            Section("Game details") {
                TextField("Name", text: $viewModel.name)
                TextField("Location", text: $viewModel.location)
                DatePicker("Date & time", selection: $viewModel.startsAt)
            }

            Section {
                Stepper("Number of courts: \(viewModel.numCourts)", value: $viewModel.numCourts, in: 1...20)
                if viewModel.format.isTournament {
                    LabeledContent("Format", value: "Singles")
                } else {
                    Picker("Format", selection: $viewModel.isDoubles) {
                        Text("Doubles").tag(true)
                        Text("Singles").tag(false)
                    }
                }
            } footer: {
                if viewModel.format.isTournament {
                    Text("Tournament brackets are singles-only for now.")
                }
            }

            Section {
                Toggle("Require approval to join", isOn: $viewModel.requiresApproval)
            } footer: {
                Text("New joiners wait for you to approve them from the Roster before they're added to the queue.")
            }

            Section("Rotation format") {
                ForEach(RotationFormat.allCases) { format in
                    Button {
                        viewModel.format = format
                        if format.isTournament { viewModel.isDoubles = false }
                    } label: {
                        HStack {
                            Image(systemName: format.systemImage)
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading) {
                                Text(format.title)
                                    .foregroundStyle(.primary)
                                Text(format.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.format == format {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }

            Section {
                NavigationLink {
                    RotationFormatSettingsView(viewModel: viewModel, auth: auth, onFinished: onFinished)
                } label: {
                    Text("Continue")
                }
                .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Create a game")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CreateGameView(viewModel: CreateGameViewModel(), auth: AuthViewModel(), onFinished: {})
    }
}
