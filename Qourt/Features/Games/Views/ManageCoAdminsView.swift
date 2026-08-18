//
//  ManageCoAdminsView.swift
//  Qourt
//

import SwiftUI

struct ManageCoAdminsView: View {
    @State private var viewModel: ManageCoAdminsViewModel

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)
    private let skipsInitialLoad: Bool

    init(game: Game, previewViewModel: ManageCoAdminsViewModel? = nil) {
        _viewModel = State(initialValue: previewViewModel ?? ManageCoAdminsViewModel(game: game))
        skipsInitialLoad = previewViewModel != nil
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Text(viewModel.game.adminInviteCode ?? "None yet")
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)

                    if let code = viewModel.game.adminInviteCode {
                        ShareLink(item: "Join me as a co-admin on Qourt for \"\(viewModel.game.name)\". Enter this code in the app: \(code)") {
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
                Text("Co-admin invite code")
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
            } footer: {
                Text("Anyone with this code can help you manage this game: start matches, edit the roster, send announcements. Keep it separate from the player join code.")
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)
            }

            Section {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if viewModel.coAdmins.isEmpty {
                    Text("No co-admins yet")
                        .font(.custom("DIN-Regular", size: 17))
                        .foregroundStyle(labelColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.coAdmins) { admin in
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
                Text("Current co-admins")
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Co-admins")
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

private let previewGame = Game(
    id: UUID(),
    name: "Sunday Open Play",
    location: nil,
    startsAt: nil,
    numCourts: 4,
    isDoubles: true,
    format: .kingOfTheCourt,
    formatSettings: [:],
    joinCode: "ABC123",
    status: "live"
)

#Preview("With co-admins") {
    let vm = ManageCoAdminsViewModel(game: previewGame)
    vm.isLoading = false
    vm.coAdmins = [
        GameAdminRow(profileId: UUID(), profiles: .init(displayName: "Awan Minton")),
        GameAdminRow(profileId: UUID(), profiles: .init(displayName: "Valentine G"))
    ]
    return NavigationStack {
        ManageCoAdminsView(game: previewGame, previewViewModel: vm)
    }
}

#Preview("No co-admins") {
    let vm = ManageCoAdminsViewModel(game: previewGame)
    vm.isLoading = false
    return NavigationStack {
        ManageCoAdminsView(game: previewGame, previewViewModel: vm)
    }
}

#Preview("Loading") {
    let vm = ManageCoAdminsViewModel(game: previewGame)
    vm.isLoading = true
    return NavigationStack {
        ManageCoAdminsView(game: previewGame, previewViewModel: vm)
    }
}
