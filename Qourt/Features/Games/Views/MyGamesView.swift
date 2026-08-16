//
//  MyGamesView.swift
//  Qourt
//

import Supabase
import SwiftUI

struct MyGamesView: View {
    var auth: AuthViewModel

    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @State private var selectedGame: Game?
    @State private var games: [Game] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isJoiningGame = false
    @State private var isShowingSettings = false
    @State private var pendingJoinCode = ""
    @State private var isRedeemingAdminInvite = false
    @State private var adminInviteCode = ""
    @State private var adminInviteError: String?
    @State private var createGameViewModel = CreateGameViewModel()
    @State private var showArchived = false
    @State private var isCreatingGame = false
    @State private var isChoosingTemplate = false
    @State private var pendingCreateAfterTemplate = false
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var realtimeSubscription: RealtimeSubscription?

    private var ongoingGames: [Game] { games.filter { !$0.hasEnded && !$0.archived } }
    private var endedGames: [Game] { games.filter { $0.hasEnded && !$0.archived } }
    private var archivedGames: [Game] { games.filter { $0.archived } }

    var body: some View {
        // NavigationSplitView adapts on its own: two panes side-by-side on
        // iPad, and it collapses to the exact same push-navigation stack
        // iPhone had before — no separate code paths needed per device.
        NavigationSplitView {
            sidebar
                .background(Color.appBackground.ignoresSafeArea())
        } detail: {
            NavigationStack {
                if let selectedGame {
                    destination(for: selectedGame)
                } else {
                    ContentUnavailableView(
                        "Select a game",
                        systemImage: "sportscourt",
                        description: Text("Choose a game from the list to open its dashboard.")
                    )
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
        }
        .task { await loadGames() }
        .task { await consumePendingJoinLinkIfAny() }
        .task { await subscribeToGameChanges() }
        .onDisappear {
            realtimeSubscription?.cancel()
            realtimeSubscription = nil
            Task { await realtimeChannel?.unsubscribe() }
        }
        .onChange(of: auth.role) {
            selectedGame = nil
            Task { await loadGames() }
        }
        .onChange(of: deepLinkRouter.pendingJoinCode) {
            Task { await consumePendingJoinLinkIfAny() }
        }
    }

    /// The games list otherwise only ever loads once (plus a handful of
    /// explicit reload call sites like "just created a game") — ending a
    /// game from its own live dashboard, another co-admin's device, or a
    /// game a player joined all changed `games` state that this view had
    /// no way of finding out about short of a full relaunch. Every other
    /// live view in the app (LiveDashboardViewModel, BracketViewModel,
    /// PlayerLiveStatusViewModel) already subscribes to its own realtime
    /// changes for the exact same reason.
    @MainActor
    private func subscribeToGameChanges() async {
        let channel = supabase.realtimeV2.channel("my-games-\(auth.userID?.uuidString ?? "anon")")
        realtimeChannel = channel
        let subscription = channel.onPostgresChange(AnyAction.self, schema: "public", table: "games") { action in
            Task { @MainActor in applyGameChange(action) }
        }
        realtimeSubscription = subscription
        try? await channel.subscribeWithError()
    }

    /// Applying the change's own row data in place — rather than
    /// re-fetching the whole list on every event — is what makes this
    /// smooth: a full reload replaces the array wholesale (a visible
    /// flash/reflow), where patching just the one changed game lets
    /// SwiftUI animate it moving between the Ongoing/Ended/Archived
    /// sections instead. A brand new game (insert) still falls back to a
    /// full reload since there's no existing row to patch.
    @MainActor
    private func applyGameChange(_ action: AnyAction) {
        switch action {
        case .insert:
            Task { await loadGames() }
        case .update(let update):
            guard let updated = try? update.decodeRecord(as: Game.self, decoder: AnyJSON.decoder),
                  let index = games.firstIndex(where: { $0.id == updated.id }) else { return }
            withAnimation {
                games[index] = updated
            }
        case .delete(let delete):
            guard let removed = try? delete.decodeOldRecord(as: Game.self, decoder: AnyJSON.decoder) else { return }
            withAnimation {
                games.removeAll { $0.id == removed.id }
            }
        }
    }

    private var titleHeader: some View {
        HStack(alignment: .center) {
            Text("My games")
                .font(.custom("DIN-Regular", size: 34))
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 18))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    //.background(Color(.blue))
                    .background(Color(.systemGray5), in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleHeader
            sidebarContent
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if games.isEmpty {
                emptyState
            } else if auth.role == .admin {
                List(selection: $selectedGame) {
                    if !ongoingGames.isEmpty {
                        Section("Ongoing") {
                            ForEach(ongoingGames) { game in
                                gameRow(game).tag(game)
                            }
                        }
                    }
                    if !endedGames.isEmpty {
                        Section("Ended") {
                            ForEach(endedGames) { game in
                                gameRow(game)
                                    .tag(game)
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
                            DisclosureGroup(
                                "Archived (\(archivedGames.count))",
                                isExpanded: $showArchived
                            ) {
                                ForEach(archivedGames) { game in
                                    gameRow(game)
                                        .tag(game)
                                        .swipeActions {
                                            Button("Unarchive") {
                                                Task { await setArchived(game, archived: false) }
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            } else {
                List(games, selection: $selectedGame) { game in
                    gameRow(game).tag(game)
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
        }

        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // TEMPORARY — purely to verify a rebuild actually reached the
        // device; safe to remove once that's confirmed.
        .safeAreaInset(edge: .bottom) {
            Text("build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
        }
        .overlay(alignment: .bottomTrailing) {
            Group {
                if auth.role == .admin {
                    Menu {
                        Button {
                            createGameViewModel = CreateGameViewModel()
                            isCreatingGame = true
                        } label: {
                            Label("Create a game", systemImage: "plus")
                        }
                        //Button {
                        //    isChoosingTemplate = true
                        //} label: {
                        //    Label("Start from a template", systemImage: "square.stack")
                        //}
                        Button {
                            adminInviteCode = ""
                            adminInviteError = nil
                            isRedeemingAdminInvite = true
                        } label: {
                            Label("Join as co-admin", systemImage: "person.badge.key")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255), in: Circle())
                            .shadow(radius: 4, y: 2)
                    }
                } else {
                    Button {
                        isJoiningGame = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255), in: Circle())
                            .shadow(radius: 4, y: 2)
                    }
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $isJoiningGame) {
            JoinGameView(auth: auth, initialCode: pendingJoinCode) { game in
                Task { await loadGames() }
                selectedGame = game
            }
            .presentationBackground(Color.appBackground)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(auth: auth)
        }
        .sheet(
            isPresented: $isChoosingTemplate,
            onDismiss: {
                if pendingCreateAfterTemplate {
                    pendingCreateAfterTemplate = false
                    isCreatingGame = true
                }
            }
        ) {
            NavigationStack {
                TemplatesView { template in
                    createGameViewModel.apply(template)
                    pendingCreateAfterTemplate = true
                    isChoosingTemplate = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isChoosingTemplate = false }
                    }
                }
            }
        }
        // fullScreenCover, not .sheet: this flow ends on the live
        // dashboard, which is where an admin spends most of their time —
        // it shouldn't look/feel like a temporary card (rounded corners,
        // drag handle, swipe-to-dismiss) that's visually different from
        // the exact same screen reached normally from the sidebar. A full
        // screen cover renders edge-to-edge with no such chrome and isn't
        // swipe-dismissible, so "Cancel"/"Done" are the only ways out —
        // without touching NavigationSplitView's selection-driven
        // navigation, which is exactly what caused the original bug.
        .fullScreenCover(isPresented: $isCreatingGame) {
            NavigationStack {
                CreateGameView(
                    viewModel: createGameViewModel,
                    auth: auth,
                    onFinished: {
                        // By the time this fires, the admin has already
                        // been using the live game itself (pushed inline
                        // inside this same sheet from InvitePlayersView) —
                        // this just closes that sheet and keeps the
                        // sidebar's selection in sync for when they land
                        // back here.
                        isCreatingGame = false
                        let newGame = createGameViewModel.createdGame
                        Task {
                            await loadGames()
                            selectedGame = newGame
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $isRedeemingAdminInvite) {
            let labelColor = Color(red: 0x4D / 255, green: 0x3E / 255, blue: 0x00 / 255)
            NavigationStack {
                VStack(spacing: 0) {
                    HStack {
                        Button("Cancel") { isRedeemingAdminInvite = false }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .foregroundStyle(.black)
                            .background(Color(.systemGray5), in: Capsule())
                            .buttonStyle(.plain)

                        Spacer()

                        Text("Join as co-admin")
                            .font(.headline)

                        Spacer()

                        Button("Join") {
                            Task { await redeemAdminInvite() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(.black)
                        .background(Color(.systemGray5), in: Capsule())
                        .buttonStyle(.plain)
                        .disabled(adminInviteCode.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding()

                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Invite Code")
                                .font(.subheadline)
                                .foregroundStyle(labelColor)

                            TextField("Invite Code", text: $adminInviteCode)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                        }

                        Text("Ask the game's owner for their co-admin invite code (not the player join code).")
                            .font(.subheadline)
                            .foregroundStyle(labelColor)

                        if let adminInviteError {
                            Text(adminInviteError)
                                .foregroundStyle(.red)
                        }

                        Spacer()
                    }
                    .padding()
                }
                .background(Color.appBackground.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
            }
            .presentationBackground(Color.appBackground)
        }
    }

    /// Matches the exact routing that existed before this was a split
    /// view: admins get routed to Game Summary once a game has ended;
    /// players always land on their live status/bracket regardless of
    /// whether the game has ended, same as before.
    @ViewBuilder
    private func destination(for game: Game) -> some View {
        if auth.role == .admin {
            if game.hasEnded {
                GameSummaryView(game: game)
            } else {
                LiveDashboardView(game: game)
            }
        } else if game.format.isTournament {
            PlayerBracketView(game: game)
        } else {
            PlayerLiveStatusView(game: game)
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
            // No reload here — the realtime subscription's applyGameChange
            // already patches this exact row smoothly the moment the
            // update comes back through, same as ending a game. Calling
            // loadGames() here too was fighting that: a full reload
            // flashes the list (isLoading briefly clears it and rebuilds
            // everything) right on top of the animated in-place update.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "figure.badminton")
                .font(.system(size: 140))
                .foregroundStyle(Color(.black))
                //.frame(width: 140, height: 293)

            Text("No games yet")
                //.font(.title3.bold())
                .font(.custom("DIN-Regular", size: 36))
                .fontWeight(.bold)

            Text(auth.role == .admin
                 ? "Create a game to get your first session running."
                 : "Join a game with a QR code or join code to get started.")
            .font(.custom("DIN-Regular", size: 18))
                //.font(.subheadline)
                .foregroundStyle(Color(red: 0x5F / 255, green: 0x4C / 255, blue: 0x00 / 255))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            selectedGame = game
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
    
    var vm = AuthViewModel()
    vm.role = .admin

     return MyGamesView(auth: vm).environment(DeepLinkRouter())
    //MyGamesView(auth: AuthViewModel())
}
