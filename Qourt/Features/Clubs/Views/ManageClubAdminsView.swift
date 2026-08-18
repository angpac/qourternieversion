//
//  ManageClubAdminsView.swift
//  Qourt
//

import SwiftUI

struct ManageClubAdminsView: View {
    @State private var viewModel: ManageClubAdminsViewModel

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)
    private let skipsInitialLoad: Bool

    init(club: Club, previewViewModel: ManageClubAdminsViewModel? = nil) {
        _viewModel = State(initialValue: previewViewModel ?? ManageClubAdminsViewModel(club: club))
        skipsInitialLoad = previewViewModel != nil
    }

    var body: some View {
        List {
            if !viewModel.club.sports.isEmpty {
                Section {
                    Text(viewModel.club.sports.joined(separator: ", "))
                        .font(.custom("DIN-Regular", size: 17))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } header: {
                    Text("Sports")
                        .font(.custom("DIN-Regular", size: 15))
                        .foregroundStyle(labelColor)
                }
            }

            Section {
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
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            } header: {
                Text("Club admin invite code")
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
            } footer: {
                Text("Anyone with this code becomes an admin of this club, and automatically an admin of every game linked to it, current and future, no per-game invite needed.")
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)
            }

            Section {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if viewModel.admins.isEmpty {
                    Text("No club admins yet")
                        .font(.custom("DIN-Regular", size: 17))
                        .foregroundStyle(labelColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.admins) { admin in
                        Text(admin.profiles.displayName)
                            .font(.custom("DIN-Regular", size: 17))
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.remove(admin) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                Text("Club admins")
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(viewModel.club.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !skipsInitialLoad else { return }
            await viewModel.load()
        }
        .refreshable { await viewModel.load() }
        .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

private let previewClub = Club(
    id: UUID(),
    ownerId: UUID(),
    name: "Riverside Badminton Club",
    sports: ["Badminton"],
    courts: 4,
    clubAdminInviteCode: "AB12CD"
)

#Preview("With admins") {
    let vm = ManageClubAdminsViewModel(club: previewClub)
    vm.isLoading = false
    vm.admins = [
        ClubAdminRow(profileId: UUID(), profiles: .init(displayName: "Awan Minton")),
        ClubAdminRow(profileId: UUID(), profiles: .init(displayName: "Valentine G")),
        ClubAdminRow(profileId: UUID(), profiles: .init(displayName: "Ernesto R"))
    ]
    return NavigationStack {
        ManageClubAdminsView(club: previewClub, previewViewModel: vm)
    }
}

#Preview("No admins") {
    let vm = ManageClubAdminsViewModel(club: previewClub)
    vm.isLoading = false
    return NavigationStack {
        ManageClubAdminsView(club: previewClub, previewViewModel: vm)
    }
}

#Preview("Loading") {
    let vm = ManageClubAdminsViewModel(club: previewClub)
    vm.isLoading = true
    return NavigationStack {
        ManageClubAdminsView(club: previewClub, previewViewModel: vm)
    }
}
