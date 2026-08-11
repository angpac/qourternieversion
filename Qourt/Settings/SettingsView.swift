//
//  SettingsView.swift
//  Qourt
//

import SwiftUI

struct SettingsView: View {
    var auth: AuthViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var skillLevel = "Beginner"
    @State private var isSaving = false

    private let skillLevels = ["Beginner", "Intermediate", "Advanced"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Default skill level", selection: $skillLevel) {
                        ForEach(skillLevels, id: \.self) { Text($0) }
                    }
                    .onChange(of: skillLevel) { _, newValue in
                        Task { await auth.setDefaultSkillLevel(newValue) }
                    }
                }

                if auth.role == .admin {
                    Section {
                        NavigationLink {
                            ClubsListView(auth: auth)
                        } label: {
                            Label("Manage Clubs", systemImage: "person.3.sequence")
                        }
                    }
                }

                Section {
                    Button {
                        auth.role = auth.role == .admin ? .player : .admin
                        dismiss()
                    } label: {
                        Label(
                            auth.role == .admin ? "Switch to Play" : "Switch to Admin",
                            systemImage: "arrow.left.arrow.right"
                        )
                    }
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            await auth.setDisplayName(name)
                            isSaving = false
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .onAppear {
                name = auth.displayName ?? ""
                skillLevel = auth.defaultSkillLevel
            }
        }
    }
}

#Preview {
    SettingsView(auth: AuthViewModel())
}
