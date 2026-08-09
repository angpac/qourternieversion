//
//  MyGamesView.swift
//  Qourt
//

import Supabase
import SwiftUI

/// Ended games route straight to their Game Summary instead of the live
/// dashboard — a separate navigation value type so the same `Game.self`
/// destination used for ongoing games can keep going to the dashboard.
private struct EndedGameLink: Hashable {
    let game: Game
}

struct MyGamesView: View {
    var auth: AuthViewModel

    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @State private var path = NavigationPath()
    @State private var games: [Game] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isJoiningGame = false
    @State private var isShowingSettings = false
    @State private var pendingJoinCode = ""
    @State private var isRedeemingAdminInvite = false
    @State private var adminInviteCode = ""
    @State private var adminInviteError: String?
    @State private var createGameViewModel = CreateGameViewModel()
    @State private var showArchived = false

    private var ongoingGames: [Game] { games.filter { !$0.hasEnded && !$0.archived } }
    private var endedGames: [Game] { games.filter { $0.hasEnded && !$0.archived } }
    private var archivedGames: [Game] { games.filter { $0.archived } }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isLoading {
                    ProgressView()
                } else if games.isEmpty {
                    emptyState
                } else if auth.role == .admin {
                    List {
                        if !ongoingGames.isEmpty {
                            Section("Ongoing") {
                                ForEach(ongoingGames) { game in
                                    NavigationLink(value: game) {
                                        gameRow(game)
                                    }
                                }
                            }
                        }
                        if !endedGames.isEmpty {
                            Section("Ended") {
                                ForEach(endedGames) { game in
                                    NavigationLink(value: EndedGameLink(game: game)) {
                                        gameRow(game)
                                    }
                                    .swipeActions {
                                        Button("Archive") {
                                            Task { await setArchived(game, archived: true) }
                                        }
                                        .tint(.gray)
                                    }
                                }
                            }
                        }
                        if !archivedGames.isEmpty {
                            Section {
                                if showArchived {
                                    ForEach(archivedGames) { game in
                                        NavigationLink(value: EndedGameLink(game: game)) {
                                            gameRow(game)
                                        }
                                        .swipeActions {
                                            Button("Unarchive") {
                                                Task { await setArchived(game, archived: false) }
                                            }
                                            .tint(.blue)
                                        }
                                    }
                                } else {
                                    Button("Show \(archivedGames.count) archived game\(archivedGames.count == 1 ? "" : "s")") {
                                        showArchived = true
                                    }
                                }
                            }
                        }
                    }
                } else {
                    List(games) { game in
                        NavigationLink(value: game) {
                            gameRow(game)
                        }
                    }
                }
            }
            .navigationTitle("My games")
            .navigationDestination(for: EndedGameLink.self) { link in
                GameSummaryView(game: link.game)
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "templates" {
                    TemplatesView { template in
                        createGameViewModel.apply(template)
                        path.append("create")
                    }
                } else {
                    CreateGameView(
                        viewModel: createGameViewModel,
                        auth: auth,
                        onFinished: {
                            path = NavigationPath()
                            Task { await loadGames() }
                        }
                    )
                }
            }
            .navigationDestination(for: Game.self) { game in
                if auth.role == .admin {
                    LiveDashboardView(game: game)
                } else if game.format.isTournament {
                    PlayerBracketView(game: game)
                } else {
                    PlayerLiveStatusView(game: game)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if auth.role == .admin {
                        Menu {
                            Button {
                                createGameViewModel = CreateGameViewModel()
                                path.append("create")
                            } label: {
                                Label("Create a game", systemImage: "plus")
                            }
                            Button {
                                createGameViewModel = CreateGameViewModel()
                                path.append("templates")
                            } label: {
                                Label("Start from a template", systemImage: "square.stack")
                            }
                            Button {
                                adminInviteCode = ""
                                adminInviteError = nil
                                isRedeemingAdminInvite = true
                            } label: {
                                Label("Join as co-admin", systemImage: "person.badge.key")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    } else {
                        Button {
                            isJoiningGame = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
            .sheet(isPresented: $isJoiningGame) {
                JoinGameView(auth: auth, initialCode: pendingJoinCode) { game in
                    Task { await loadGames() }
                    path.append(game)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(auth: auth)
            }
            .sheet(isPresented: $isRedeemingAdminInvite) {
                NavigationStack {
                    Form {
                        Section {
                            TextField("Invite code", text: $adminInviteCode)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        } footer: {
                            Text("Ask the game's owner for their co-admin invite code (not the player join code).")
                        }
                        if let adminInviteError {
                            Section {
                                Text(adminInviteError).foregroundStyle(.red)
                            }
                        }
                    }
                    .navigationTitle("Join as co-admin")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { isRedeemingAdminInvite = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Join") {
                                Task { await redeemAdminInvite() }
                            }
                            .disabled(adminInviteCode.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
        }
        .task { await loadGames() }
        .task { await consumePendingJoinLinkIfAny() }
        .onChange(of: auth.role) {
            path = NavigationPath()
            Task { await loadGames() }
        }
        .onChange(of: deepLinkRouter.pendingJoinCode) {
            Task { await consumePendingJoinLinkIfAny() }
        }
    }

    /// A tapped share link or scanned QR code arrives as a Universal Link
    /// and may land before sign-in/role selection finish, so this re-checks
    /// on every relevant change rather than only once at launch.
    @MainActor
    private func consumePendingJoinLinkIfAny() async {
        guard let code = deepLinkRouter.pendingJoinCode else { return }
        deepLinkRouter.pendingJoinCode = nil
        if auth.role != .player {
            auth.chooseRole(.player)
        }
        pendingJoinCode = code
        isJoiningGame = true
    }

    private func gameRow(_ game: Game) -> some View {
        VStack(alignment: .leading) {
            Text(game.name).font(.headline)
            Text("\(game.numCourts) courts · \(game.format.title)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func setArchived(_ game: Game, archived: Bool) async {
        do {
            try await supabase.from("games")
                .update(["archived": archived])
                .eq("id", value: game.id)
                .execute()
            await loadGames()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "sportscourt")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No games yet")
                .font(.title3.bold())

            Text(auth.role == .admin
                 ? "Create a game to get your first session running."
                 : "Join a game with a QR code or join code to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    @MainActor
    private func redeemAdminInvite() async {
        struct Params: Encodable { let p_invite_code: String }
        do {
            let game: Game = try await supabase.rpc(
                "redeem_admin_invite",
                params: Params(p_invite_code: adminInviteCode.trimmingCharacters(in: .whitespaces))
            )
            .select()
            .single()
            .execute()
            .value
            isRedeemingAdminInvite = false
            await loadGames()
            path.append(game)
        } catch let error as PostgrestError {
            adminInviteError = error.message
        } catch {
            adminInviteError = error.localizedDescription
        }
    }

    private func loadGames() async {
        guard let userID = auth.userID else { return }
        isLoading = true
        do {
            if auth.role == .admin {
                struct CoAdminRow: Decodable { let game_id: UUID }
                let coAdminRows: [CoAdminRow] = (try? await supabase.from("game_admins")
                    .select("game_id")
                    .eq("profile_id", value: userID)
                    .execute()
                    .value) ?? []

                if coAdminRows.isEmpty {
                    games = try await supabase.from("games")
                        .select()
                        .eq("owner_id", value: userID)
                        .order("created_at", ascending: false)
                        .execute()
                        .value
                } else {
                    let coAdminIDs = coAdminRows.map(\.game_id.uuidString).joined(separator: ",")
                    games = try await supabase.from("games")
                        .select()
                        .or("owner_id.eq.\(userID),id.in.(\(coAdminIDs))")
                        .order("created_at", ascending: false)
                        .execute()
                        .value
                }
            } else {
                struct JoinedGameRow: Decodable { let games: Game }
                let rows: [JoinedGameRow] = try await supabase.from("game_players")
                    .select("games(*)")
                    .eq("profile_id", value: userID)
                    .execute()
                    .value
                games = rows.map(\.games)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    MyGamesView(auth: AuthViewModel())
}
