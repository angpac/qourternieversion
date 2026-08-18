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
    @State private var courts = 0
    @State private var isCreating = false
    @Environment(\.dismiss) private var dismiss

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    private var isNameEmpty: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Create a Club")
                            .font(.custom("DIN-BlackAlternate", size: 34))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Club Name")
                                .font(.custom("DIN-Regular", size: 15))
                                .foregroundStyle(labelColor)

                            TextField("Club Name", text: $name)
                                .font(.custom("DIN-Regular", size: 17))
                                .padding()
                                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Available Courts")
                                .font(.custom("DIN-Regular", size: 15))
                                .foregroundStyle(labelColor)

                            HStack {
                                Text("\(courts) Court\(courts <= 1 ? "" : "s")")
                                    .font(.custom("DIN-Regular", size: 17))
                                    .foregroundStyle(Color.primary)

                                Spacer()

                                HStack(spacing: 12) {
                                    Button {
                                        courts -= 1
                                    } label: {
                                        Image(systemName: "minus")
                                            .foregroundStyle(Color.primary)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.primary, lineWidth: 1)
                                            )
                                    }
                                    .disabled(courts == 0)

                                    Rectangle()
                                        .fill(labelColor.opacity(0.3))
                                        .frame(width: 1, height: 24)

                                    Button {
                                        courts += 1
                                    } label: {
                                        Image(systemName: "plus")
                                            .foregroundStyle(labelColor)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(labelColor, lineWidth: 1)
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                Button {
                    Task { await createClub() }
                } label: {
                    if isCreating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Create Club")
                            .font(.custom("DIN-Medium", size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(isNameEmpty ? Color(.systemGray5) : accentColor, in: Capsule())
                .buttonStyle(.plain)
                .disabled(isNameEmpty || isCreating)
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
    }

    @MainActor
    private func createClub() async {
        guard let userID = auth.userID else { return }
        isCreating = true
        defer { isCreating = false }

        if let club = await viewModel.createClub(name: name, sports: [], courts: courts, ownerID: userID) {
            onCreated(club)
            dismiss()
        }
    }
}

#Preview {
    CreateClubView(auth: AuthViewModel(), onCreated: { _ in })
}
