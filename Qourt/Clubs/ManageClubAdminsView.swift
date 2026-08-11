//
//  ManageClubAdminsView.swift
//  Qourt
//

import SwiftUI

struct ManageClubAdminsView: View {
    @State private var viewModel: ManageClubAdminsViewModel

    init(club: Club) {
        _viewModel = State(initialValue: ManageClubAdminsViewModel(club: club))
    }

    var body: some View {
        List {
            if !viewModel.club.sports.isEmpty {
                Section("Sports") {
                    Text(viewModel.club.sports.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text(viewModel.club.clubAdminInviteCode ?? "None yet")
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                if let code = viewModel.club.clubAdminInviteCode {
                    ShareLink(item: "Join me as a co-admin of \"\(viewModel.club.name)\" on Qourt. Enter this code in the app: \(code)") {
                        Label("Share invite code", systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Text("Club admin invite code")
            } footer: {
                Text("Anyone with this code becomes an admin of this club, and automatically an admin of every game linked to it, current and future, no per-game invite needed.")
            }

            Section("Club admins") {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.admins.isEmpty {
                    Text("No club admins yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.admins) { admin in
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
