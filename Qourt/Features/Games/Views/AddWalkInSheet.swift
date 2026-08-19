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
                ZStack {
                    Text("Add players")
                        .font(.custom("DIN-Medium", size: 17))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.custom("DIN-Medium", size: 15))
                                .foregroundStyle(Color.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            Task {
                                isSaving = true
                                await viewModel.addWalkIns(entries.map { (name: $0.name, skillLevel: $0.skillLevel) })
                                isSaving = false
                                dismiss()
                            }
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Save")
                                        .font(.custom("DIN-Medium", size: 15))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(hasAnyName ? accentColor : Color(.systemGray5), in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasAnyName || isSaving)
                    }
                }
                .padding()

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
