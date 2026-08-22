//
//  AddWalkInSheet.swift
//  Qourt
//

import SwiftUI

struct AddWalkInSheet: View {
    var viewModel: LiveDashboardViewModel

    private struct Entry: Identifiable {
        let id = UUID()
        var name = ""
        var skillLevel = "Beginner"
    }

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [Entry] = (0..<10).map { _ in Entry() }
    @State private var isSaving = false

    private let skillLevels = ["Beginner", "Intermediate", "Advanced"]
    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    private var hasAnyName: Bool {
        entries.contains { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(entries.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.custom("DIN-Regular", size: 13))
                                    .foregroundStyle(labelColor)
                                    .frame(width: 16, alignment: .leading)

                                TextField("Player name", text: $entries[index].name)
                                    .font(.custom("DIN-Regular", size: 17))

                                Spacer(minLength: 8)

                                Picker("Skill level", selection: $entries[index].skillLevel) {
                                    ForEach(skillLevels, id: \.self) { Text($0) }
                                }
                                .pickerStyle(.menu)
                                .tint(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5), in: Capsule())
                            }
                            .padding()
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding()
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Add players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            await viewModel.addWalkIns(entries.map { (name: $0.name, skillLevel: $0.skillLevel) })
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    .disabled(!hasAnyName || isSaving)
                }
            }
        }
    }
}

#Preview {
    AddWalkInSheet(viewModel: LiveDashboardViewModel(game: Game(
        id: UUID(),
        name: "Sunday Open Play",
        location: "Community Center",
        startsAt: Date(),
        numCourts: 4,
        isDoubles: true,
        format: .kingOfTheCourt,
        formatSettings: [:],
        joinCode: "7K2P9Q",
        status: "draft"
    )))
}
