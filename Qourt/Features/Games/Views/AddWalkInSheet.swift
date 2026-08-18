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
    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    private var isNameEmpty: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Text("Add player")
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
                        }
                        .background(Color(.systemGray5), in: Capsule())
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            Task {
                                isSaving = true
                                await viewModel.addWalkIn(name: name, skillLevel: skillLevel)
                                isSaving = false
                                dismiss()
                            }
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Add")
                                        .font(.custom("DIN-Medium", size: 15))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .background(isNameEmpty ? Color(.systemGray5) : accentColor, in: Capsule())
                        .buttonStyle(.plain)
                        .disabled(isNameEmpty || isSaving)
                    }
                }
                .padding()

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(labelColor)

                        TextField("Name", text: $name)
                            .font(.custom("DIN-Regular", size: 17))
                            .padding()
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                    }

                    HStack {
                        Text("Skill level")
                            .font(.custom("DIN-Regular", size: 17))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Picker("Skill level", selection: $skillLevel) {
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

                    Spacer()
                }
                .padding()
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
