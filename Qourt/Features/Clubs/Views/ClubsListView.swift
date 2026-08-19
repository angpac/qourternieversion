//
//  ClubsListView.swift
//  Qourt
//

import Supabase
import SwiftUI

struct ClubsListView: View {
    var auth: AuthViewModel

    @State private var viewModel: ClubsViewModel
    @State private var isCreatingClub = false
    @State private var isRedeemingInvite = false
    @State private var inviteCode = ""
    @State private var inviteError: String?

    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    init(auth: AuthViewModel, previewViewModel: ClubsViewModel? = nil) {
        self.auth = auth
        _viewModel = State(initialValue: previewViewModel ?? ClubsViewModel())
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.clubs.isEmpty {
                emptyState
            } else {
                List(viewModel.clubs) { club in
                    NavigationLink(value: club) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(club.name)
                                .font(.custom("DIN-Medium", size: 17))
                            if !club.sports.isEmpty {
                                Text(club.sports.joined(separator: ", "))
                                    .font(.custom("DIN-Regular", size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Clubs")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Club.self) { club in
            ManageClubAdminsView(club: club)
        }
        .overlay(alignment: .bottomTrailing) {
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
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(accentColor, in: Circle())
                    .shadow(radius: 4, y: 2)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $isCreatingClub) {
            CreateClubView(auth: auth) { _ in
                Task { await viewModel.load() }
            }
        }
        .sheet(isPresented: $isRedeemingInvite) {
            let isJoinActive = !inviteCode.trimmingCharacters(in: .whitespaces).isEmpty
            NavigationStack {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            isRedeemingInvite = false
                        } label: {
                            Text("Cancel")
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("Join as club admin")
                            .font(.headline)

                        Spacer()

                        Button {
                            Task { await redeemInvite() }
                        } label: {
                            Text("Join")
                                .foregroundStyle(isJoinActive ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isJoinActive ? accentColor : Color(.systemGray5), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!isJoinActive)
                    }
                    .padding()

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
                    .scrollContentBackground(.hidden)
                }
                .background(Color.appBackground.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .task { await viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.3.sequence")
                .font(.system(size: 80))
                .foregroundStyle(Color.primary)

            Text("No clubs yet")
                .font(.custom("DIN-Regular", size: 36))
                .fontWeight(.bold)

            Text("Create a club to link multiple games under one admin roster.")
                .font(.custom("DIN-Regular", size: 18))
                .foregroundStyle(Color.appSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

#Preview("With clubs") {
    let vm = ClubsViewModel()
    vm.isLoading = false
    vm.clubs = [
        Club(id: UUID(), ownerId: UUID(), name: "Riverside Badminton Club", sports: ["Badminton"], courts: 4, clubAdminInviteCode: "AB12CD"),
        Club(id: UUID(), ownerId: UUID(), name: "Downtown Pickleball", sports: ["Pickleball"], courts: 2, clubAdminInviteCode: "XY98ZT")
    ]
    return NavigationStack {
        ClubsListView(auth: AuthViewModel(), previewViewModel: vm)
    }
}

#Preview("Empty") {
    let vm = ClubsViewModel()
    vm.isLoading = false
    return NavigationStack {
        ClubsListView(auth: AuthViewModel(), previewViewModel: vm)
    }
}

#Preview("Loading") {
    let vm = ClubsViewModel()
    vm.isLoading = true
    return NavigationStack {
        ClubsListView(auth: AuthViewModel(), previewViewModel: vm)
    }
}
