//
//  CreateClubView.swift
//  Qourt
//

import SwiftUI

struct CreateClubView: View {
    var auth: AuthViewModel
    var onCreated: (Club) -> Void

    @State private var viewModel = ClubsViewModel()
    @State private var name = ""
    @State private var selectedSports: Set<String> = []
    @State private var customSport = ""
    @State private var isCreating = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Club name") {
                    TextField("e.g. Riverside Badminton Club", text: $name)
                }

                Section {
                    ForEach(CommonSport.allCases) { sport in
                        Button {
                            toggle(sport.rawValue)
                        } label: {
                            HStack {
                                Text(sport.rawValue).foregroundStyle(.primary)
                                Spacer()
                                if selectedSports.contains(sport.rawValue) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                    TextField("Other sport", text: $customSport)
                } header: {
                    Text("Sports this club runs")
                } footer: {
                    Text("You can run more than one sport under the same club, pick as many as apply.")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create a club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createClub() }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
    }

    private func toggle(_ sport: String) {
        if selectedSports.contains(sport) {
            selectedSports.remove(sport)
        } else {
            selectedSports.insert(sport)
        }
    }

    @MainActor
    private func createClub() async {
        guard let userID = auth.userID else { return }
        isCreating = true
        defer { isCreating = false }

        var sports = Array(selectedSports)
        let trimmedCustom = customSport.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCustom.isEmpty { sports.append(trimmedCustom) }

        if let club = await viewModel.createClub(name: name, sports: sports, ownerID: userID) {
            onCreated(club)
            dismiss()
        }
    }
}

#Preview {
    CreateClubView(auth: AuthViewModel(), onCreated: { _ in })
}
