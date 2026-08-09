//
//  ManageCoAdminsView.swift
//  Qourt
//

import SwiftUI

struct ManageCoAdminsView: View {
    @State private var viewModel: ManageCoAdminsViewModel

    init(game: Game) {
        _viewModel = State(initialValue: ManageCoAdminsViewModel(game: game))
    }

    var body: some View {
        List {
            Section {
                Text(viewModel.game.adminInviteCode ?? "—")
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                if let code = viewModel.game.adminInviteCode {
                    ShareLink(item: "Join me as a co-admin on Qourt for \"\(viewModel.game.name)\" — enter this code in the app: \(code)") {
                        Label("Share invite code", systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Text("Co-admin invite code")
            } footer: {
                Text("Anyone with this code can help you manage this game — start matches, edit the roster, send announcements. Keep it separate from the player join code.")
            }

            Section("Current co-admins") {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.coAdmins.isEmpty {
                    Text("No co-admins yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.coAdmins) { admin in
                        HStack {
                            Text(admin.profiles.displayName)
                            Spacer()
                            Button(role: .destructive) {
                                Task { await viewModel.remove(admin) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Co-admins")
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
        ManageCoAdminsView(game: Game(
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
        ))
    }
}
