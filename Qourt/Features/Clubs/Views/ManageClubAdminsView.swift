//
//  ManageClubAdminsView.swift
//  Qourt
//

import SwiftUI

struct ManageClubAdminsView: View {
    @State private var viewModel: ManageClubAdminsViewModel

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    init(club: Club) {
        _viewModel = State(initialValue: ManageClubAdminsViewModel(club: club))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !viewModel.club.sports.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sports")
                            .font(.custom("DIN-Regular", size: 15))
                            .foregroundStyle(labelColor)

                        Text(viewModel.club.sports.joined(separator: ", "))
                            .font(.custom("DIN-Regular", size: 17))
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Club admin invite code")
                        .font(.custom("DIN-Regular", size: 15))
                        .foregroundStyle(labelColor)

                    VStack(spacing: 16) {
                        Text(viewModel.club.clubAdminInviteCode ?? "None yet")
                            .font(.system(.title2, design: .monospaced, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity)

                        if let code = viewModel.club.clubAdminInviteCode {
                            ShareLink(item: "Join me as a co-admin of \"\(viewModel.club.name)\" on Qourt. Enter this code in the app: \(code)") {
                                Label("Share invite code", systemImage: "square.and.arrow.up")
                                    .font(.custom("DIN-Medium", size: 16))
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(accentColor, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))

                    Text("Anyone with this code becomes an admin of this club, and automatically an admin of every game linked to it, current and future, no per-game invite needed.")
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(labelColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Club admins")
                        .font(.custom("DIN-Regular", size: 15))
                        .foregroundStyle(labelColor)

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if viewModel.admins.isEmpty {
                        Text("No club admins yet")
                            .font(.custom("DIN-Regular", size: 17))
                            .foregroundStyle(labelColor)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(viewModel.admins) { admin in
                                HStack {
                                    Text(admin.profiles.displayName)
                                        .font(.custom("DIN-Regular", size: 17))
                                        .foregroundStyle(Color.primary)
                                    Spacer()
                                    Button(role: .destructive) {
                                        Task { await viewModel.remove(admin) }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding()

                                if admin.id != viewModel.admins.last?.id {
                                    Rectangle()
                                        .fill(labelColor.opacity(0.15))
                                        .frame(height: 1)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(viewModel.club.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        ManageClubAdminsView(club: Club(
            id: UUID(),
            ownerId: UUID(),
            name: "Riverside Badminton Club",
            sports: ["Badminton"],
            courts: 4,
            clubAdminInviteCode: "AB12CD"
        ))
    }
}
