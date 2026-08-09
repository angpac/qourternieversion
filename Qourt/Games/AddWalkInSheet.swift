//
//  AddWalkInSheet.swift
//  Qourt
//

import SwiftUI

struct AddWalkInSheet: View {
    var viewModel: LiveDashboardViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var skillLevel = "Beginner"
    @State private var isSaving = false

    private let skillLevels = ["Beginner", "Intermediate", "Advanced"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Skill level", selection: $skillLevel) {
                    ForEach(skillLevels, id: \.self) { Text($0) }
                }
            }
            .navigationTitle("Add player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            await viewModel.addWalkIn(name: name, skillLevel: skillLevel)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }
}
