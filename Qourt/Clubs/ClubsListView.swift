//
//  ClubsListView.swift
//  Qourt
//

import Supabase
import SwiftUI

struct ClubsListView: View {
    var auth: AuthViewModel

    @State private var viewModel = ClubsViewModel()
    @State private var isCreatingClub = false
    @State private var isRedeemingInvite = false
    @State private var inviteCode = ""
    @State private var inviteError: String?

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.clubs.isEmpty {
                ContentUnavailableView(
                    "No clubs yet",
                    systemImage: "person.3.sequence",
                    description: Text("Create a club to link multiple games under one admin roster.")
                )
            } else {
                List(viewModel.clubs) { club in
                    NavigationLink(value: club) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(club.name).font(.headline)
                            if !club.sports.isEmpty {
                                Text(club.sports.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Clubs")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Club.self) { club in
            ManageClubAdminsView(club: club)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isCreatingClub = true
                    } label: {
                        Label("Create a club", systemImage: "plus")
                    }
                    Button {
                        inviteCode = ""
                        inviteError = nil
                        isRedeemingInvite = true
                    } label: {
                        Label("Join as club admin", systemImage: "person.badge.key")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreatingClub) {
            CreateClubView(auth: auth) { _ in
                Task { await viewModel.load() }
            }
        }
        .sheet(isPresented: $isRedeemingInvite) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Invite code", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    } footer: {
                        Text("Ask the club's owner for their club admin invite code.")
                    }
                    if let inviteError {
                        Section {
                            Text(inviteError).foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("Join as club admin")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isRedeemingInvite = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Join") {
                            Task { await redeemInvite() }
                        }
                        .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .task { await viewModel.load() }
    }

    @MainActor
    private func redeemInvite() async {
        struct Params: Encodable { let p_invite_code: String }
        do {
            let _: Club = try await supabase.rpc(
                "redeem_club_admin_invite",
                params: Params(p_invite_code: inviteCode.trimmingCharacters(in: .whitespaces))
            )
            .select()
            .single()
            .execute()
            .value
            isRedeemingInvite = false
            await viewModel.load()
        } catch let error as PostgrestError {
            inviteError = error.message
        } catch {
            inviteError = error.localizedDescription
        }
    }
}
