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
    private let labelColor = Color(red: 0x5F / 255, green: 0x4C / 255, blue: 0x00 / 255)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            // systemGray5 darkens in dark mode, so a fixed
                            // black glyph would disappear into it.
                            .foregroundStyle(Color.primary)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray5), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Settings")
                        .font(.headline)

                    Spacer()

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
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255),
                                    in: Capsule()
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Profile")
                            .font(.custom("DIN-Regular", size: 34))
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.custom("DIN-Regular", size: 14))
                                .foregroundStyle(Color.appSecondaryText)

                            TextField("Name", text: $name)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        }

                        HStack {
                            Text("Skill level")
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
                        .onChange(of: skillLevel) { _, newValue in
                            Task { await auth.setDefaultSkillLevel(newValue) }
                        }

                        if auth.role == .admin {
                            NavigationLink {
                                ClubsListView(auth: auth)
                            } label: {
                                Label("Manage Clubs", systemImage: "person.3.sequence")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                            .padding()
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        }

                        Button {
                            auth.role = auth.role == .admin ? .player : .admin
                            dismiss()
                        } label: {
                            Label(
                                auth.role == .admin ? "Switch to Player" : "Switch to Admin",
                                systemImage: "arrow.left.arrow.right"
                            )
                            .foregroundStyle(Color.appSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))

                        Button(role: .destructive) {
                            Task { await auth.signOut() }
                        } label: {
                            Text("Sign out")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .background(Color.red, in: Capsule())
                    }
                    .padding()
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
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
