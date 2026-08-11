//
//  CreateGameView.swift
//  Qourt
//

import SwiftUI

struct CreateGameView: View {
    @Bindable var viewModel: CreateGameViewModel
    var auth: AuthViewModel
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var locationSearch = LocationSearchViewModel()
    @State private var suppressLocationQuery = false

    var body: some View {
        Form {
            Section("Game details") {
                TextField("Name", text: $viewModel.name)
                TextField("Location", text: $viewModel.location)
                    .onChange(of: viewModel.location) { _, newValue in
                        if suppressLocationQuery {
                            suppressLocationQuery = false
                            return
                        }
                        locationSearch.updateQuery(newValue)
                    }
                if !locationSearch.suggestions.isEmpty {
                    ForEach(Array(locationSearch.suggestions.enumerated()), id: \.offset) { _, suggestion in
                        Button {
                            suppressLocationQuery = true
                            viewModel.location = suggestion.subtitle.isEmpty ? suggestion.title : "\(suggestion.title), \(suggestion.subtitle)"
                            locationSearch.clearSuggestions()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title).foregroundStyle(.primary)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                DatePicker("Date & time", selection: $viewModel.startsAt)
            }

            if !viewModel.availableClubs.isEmpty {
                Section {
                    Picker("Club", selection: $viewModel.selectedClubId) {
                        Text("None").tag(UUID?.none)
                        ForEach(viewModel.availableClubs) { club in
                            Text(club.name).tag(Optional(club.id))
                        }
                    }
                } footer: {
                    Text("Linking this game to a club means every club admin can manage it too, and it shares the club's roster going forward.")
                }
            }

            Section {
                Stepper("Number of courts: \(viewModel.numCourts)", value: $viewModel.numCourts, in: 1...20)
                if viewModel.format.isTournament {
                    LabeledContent("Format", value: "Singles")
                } else {
                    Picker("Format", selection: $viewModel.formatMode) {
                        ForEach(GameFormatMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                if viewModel.formatMode == .mixed && !viewModel.format.isTournament {
                    ForEach(0..<viewModel.numCourts, id: \.self) { index in
                        Picker("Court \(index + 1)", selection: courtSinglesBinding(index)) {
                            Text("Doubles").tag(false)
                            Text("Singles").tag(true)
                        }
                    }
                }
            } footer: {
                if viewModel.format.isTournament {
                    Text("Tournament brackets are singles-only for now.")
                } else if viewModel.formatMode == .mixed {
                    Text("Set each court's format below — handy for a session where most courts are doubles but one's set aside for stronger singles players (or the other way around).")
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
                        if format.isTournament {
                            viewModel.isDoubles = false
                            viewModel.formatMode = .singles
                        }
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
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .task {
            locationSearch.requestLocation()
            if let userID = auth.userID {
                await viewModel.loadAvailableClubs(ownerID: userID)
            }
        }
    }

    private func courtSinglesBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { viewModel.courtSinglesOverrides[index] ?? !viewModel.isDoubles },
            set: { viewModel.courtSinglesOverrides[index] = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        CreateGameView(viewModel: CreateGameViewModel(), auth: AuthViewModel(), onFinished: {})
    }
}
