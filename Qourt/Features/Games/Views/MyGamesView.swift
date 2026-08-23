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
    /// Player-only: this profile's own `game_players.status` per game, so
    /// a game they've left can be sorted into Ended regardless of its
    /// date. Empty/unused for admins.
    @State private var myPlayerStatusByGameID: [UUID: PlayerStatus] = [:]
    /// Starts true so the very first render shows the spinner rather than
    /// the "No games yet" empty state. With `games` empty and this false,
    /// the empty state won a frame before `.task` could start loading —
    /// which is the screen that flashed right after picking a role.
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isJoiningGame = false
    @State private var isShowingSettings = false
    @State private var pendingJoinCode = ""
    @State private var isRedeemingAdminInvite = false
    @State private var adminInviteCode = ""
    @State private var adminInviteError: String?
    @State private var isScanningAdminInvite = false
    @State private var createGameViewModel = CreateGameViewModel()
    @State private var showArchived = false
    /// Set by the swipe action; the confirmation dialog reads it. Deleting a
    /// game cascades to its roster, matches, and everyone's history, so it
    /// never happens straight off a gesture.
    @State private var gamePendingDeletion: Game?
    @State private var isCreatingGame = false
    @State private var isChoosingTemplate = false
    @State private var pendingCreateAfterTemplate = false
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var realtimeSubscription: RealtimeSubscription?

    /// `previewGames` is Canvas-only: `loadGames()` guards on
    /// `auth.userID`, which is nil for a fresh, unauthenticated
    /// `AuthViewModel()` in a preview, so it returns before ever
    /// overwriting `games` — this seeds the list to skip the empty state
    /// without needing a real signed-in session.
    init(auth: AuthViewModel, previewGames: [Game]? = nil) {
        self.auth = auth
        if let previewGames {
            _games = State(initialValue: previewGames)
            _isLoading = State(initialValue: false)
        }
    }

    private var ongoingGames: [Game] { games.filter { !$0.hasEnded && !$0.archived } }
    private var endedGames: [Game] { games.filter { $0.hasEnded && !$0.archived } }
    private var archivedGames: [Game] { games.filter { $0.archived } }

    /// A player's list is grouped by calendar day rather than by admin-set
    /// status or exact timestamp — a session scheduled for today counts as
    /// Ongoing no matter what time it started, since comparing full
    /// timestamps put an already-started-but-still-running today's game
    /// under Ended the moment its start time passed. Only a date strictly
    /// before today moves there.
    ///
    /// A game the player has left is always Ended regardless of its date —
    /// once they've stepped away there's nothing "ongoing" or "upcoming"
    /// about it from their side, even if the admin's session is still
    /// running or scheduled for later today.
    private func hasLeftGame(_ game: Game) -> Bool {
        myPlayerStatusByGameID[game.id] == .removed
    }

    private var todayGamesForPlayer: [Game] {
        games
            .filter { !hasLeftGame($0) && ($0.startsAt.map { Calendar.current.isDateInToday($0) } ?? false) }
            .sorted { ($0.startsAt ?? .distantFuture) < ($1.startsAt ?? .distantFuture) }
    }
    private var upcomingGamesForPlayer: [Game] {
        games
            .filter { game in
                guard !hasLeftGame(game) else { return false }
                guard let startsAt = game.startsAt else { return true }
                return !Calendar.current.isDateInToday(startsAt) && startsAt > Date()
            }
            .sorted { ($0.startsAt ?? .distantFuture) < ($1.startsAt ?? .distantFuture) }
    }
    private var pastGamesForPlayer: [Game] {
        games
            .filter { game in
                if hasLeftGame(game) { return true }
                guard let startsAt = game.startsAt else { return false }
                return !Calendar.current.isDateInToday(startsAt) && startsAt < Date()
            }
            .sorted { ($0.startsAt ?? .distantPast) > ($1.startsAt ?? .distantPast) }
    }

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
            // Postgres's default replica identity puts only the primary
            // key in a DELETE's old-row payload, not the full row — so
            // decoding straight into `Game` (which needs `name`,
            // `numCourts`, and every other required field) silently
            // failed via `try?` and this case never actually fired.
            struct DeletedGameID: Decodable { let id: UUID }
            guard let removed = try? delete.decodeOldRecord(as: DeletedGameID.self, decoder: AnyJSON.decoder) else { return }
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
                .foregroundStyle(Color.primary)
            Spacer()
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.primary)
                    .frame(width: 44, height: 44)
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
            // Only take over the whole pane when there is genuinely nothing
            // to show. Any reload sets isLoading — coming back from a game
            // you just created runs one — and swapping an already-populated
            // list out for a spinner and straight back is the flash. With
            // games in hand the list simply stays put and updates in place.
            if isLoading && games.isEmpty {
                ProgressView()
            } else if games.isEmpty {
                emptyState
            } else if auth.role == .admin {
                List(selection: $selectedGame) {
                    if !ongoingGames.isEmpty {
                        Section {
                            ForEach(ongoingGames) { game in
                                gameRow(game)
                                    .tag(game)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            Text("Ongoing")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                    }
                    if !endedGames.isEmpty {
                        Section {
                            ForEach(endedGames) { game in
                                gameRow(game)
                                    .tag(game)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing) {
                                        rowActions(for: game)
                                    }
                            }
                        } header: {
                            Text("Ended")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
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
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing) {
                                            rowActions(for: game)
                                        }
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            } else {
                List(selection: $selectedGame) {
                    if !todayGamesForPlayer.isEmpty {
                        Section {
                            ForEach(todayGamesForPlayer) { game in
                                gameRow(game)
                                    .tag(game)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            Text("Ongoing")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                    }
                    if !upcomingGamesForPlayer.isEmpty {
                        Section {
                            ForEach(upcomingGamesForPlayer) { game in
                                gameRow(game)
                                    .tag(game)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            Text("Upcoming")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                    }
                    if !pastGamesForPlayer.isEmpty {
                        Section {
                            ForEach(pastGamesForPlayer) { game in
                                gameRow(game)
                                    .tag(game)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            Text("Ended")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
        }
        // A bare ProgressView has almost no intrinsic height, so while the
        // first load ran this whole screen collapsed to a short band floating
        // in the middle of the window — header, FAB and all — until the List
        // arrived and gave it size. Claiming the full pane up front means
        // every state occupies the same space and nothing jumps.
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        .confirmationDialog(
            "Delete \(gamePendingDeletion?.name ?? "this game")?",
            isPresented: Binding(
                get: { gamePendingDeletion != nil },
                set: { if !$0 { gamePendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete game", role: .destructive) {
                if let game = gamePendingDeletion {
                    Task { await deleteGame(game) }
                }
                gamePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { gamePendingDeletion = nil }
        } message: {
            Text("This removes the roster, every match, and the game's history for all players. Archive instead if you just want it out of the list.")
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
                        Button {
                            isChoosingTemplate = true
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
        .navigationDestination(isPresented: $isShowingSettings) {
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
                        Button("Cancel") {
                            isChoosingTemplate = false
                        }
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
                        // Match by id against the freshly loaded list rather
                        // than reusing the object returned at insert time.
                        // Game is Hashable over all its stored properties, so
                        // the insert-time value stops being equal to the row
                        // in `games` the moment anything changes (status
                        // draft -> live, prep_ends_at, a club link). An
                        // unequal value leaves the sidebar with no matching
                        // tag and the selection highlight broken. Falling
                        // back to the insert-time value keeps navigation
                        // working even if the reload failed.
                        let newGameID = createGameViewModel.createdGame?.id
                        let fallback = createGameViewModel.createdGame
                        Task {
                            await loadGames()
                            guard let newGameID else { return }
                            selectedGame = games.first { $0.id == newGameID } ?? fallback
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $isRedeemingAdminInvite) {
            let labelColor = Color.appSecondaryText
            NavigationStack {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Invite Code")
                                .font(.subheadline)
                                .foregroundStyle(labelColor)

                            TextField("Invite Code", text: $adminInviteCode)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        }

                        Button {
                            isScanningAdminInvite = true
                        } label: {
                            Label("Scan QR code", systemImage: "qrcode.viewfinder")
                                .font(.custom("DIN-Medium", size: 16))
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255))
                                .padding()
                                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                                .contentShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)

                        Text("Ask the game's owner for their co-admin invite code (not the player join code), or scan the QR code on their Co-admins screen.")
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
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255))
                        .disabled(adminInviteCode.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .presentationBackground(Color.appBackground)
        }
        .sheet(isPresented: $isScanningAdminInvite) {
            QRScannerSheet { code in
                adminInviteCode = code
            }
        }
    }

    /// Both roles land on Game Summary once a game has ended — players get
    /// the same recap admins do, just without the "save as template"
    /// action (that's an admin-only capability, not something a player's
    /// view of someone else's game should offer).
    @ViewBuilder
    private func destination(for game: Game) -> some View {
        if game.hasEnded {
            GameSummaryView(game: game, isAdmin: auth.role == .admin)
        } else if auth.role == .admin {
            LiveDashboardView(game: game, onGameEnded: {
                // Update locally first — the realtime event that would
                // otherwise move this into Ended is a separate
                // round-trip and can lag behind clearing the
                // selection, which would drop the admin back on My
                // Games with the game still sitting under Ongoing for
                // a beat.
                if let index = games.firstIndex(where: { $0.id == game.id }) {
                    games[index].status = "ended"
                }
                selectedGame = nil
            })
        } else if game.format.isTournament {
            PlayerBracketView(game: game)
        } else {
            PlayerLiveStatusView(game: game, onLeftGame: {
                myPlayerStatusByGameID[game.id] = .removed
            })
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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.name)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text("\(game.numCourts) courts  •  \(game.format.title)")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }
            Spacer()
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
        // The card draws its own padding, so List's default row insets
        // (~11pt top and bottom) stack on top of it and push the cards far
        // apart. 4pt here leaves an 8pt gap between neighbouring cards.
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }

    /// Trailing swipe actions, shared by the Ended and Archived sections.
    /// Ongoing games skip this entirely — archiving or deleting a game
    /// that's still being played out from under it isn't something the
    /// list should offer.
    ///
    /// Archive is declared first, which makes it the full-swipe action —
    /// the fast gesture does the reversible thing. Delete is deliberately a
    /// deliberate tap plus a confirmation: it cascades to the roster,
    /// matches, and the match history of every player who was in the game,
    /// so it destroys other people's data, not just the admin's.
    @ViewBuilder
    private func rowActions(for game: Game) -> some View {
        if game.archived {
            Button {
                Task { await setArchived(game, archived: false) }
            } label: {
                Label("Unarchive", systemImage: "tray.and.arrow.up")
            }
            .tint(.blue)
        } else {
            Button {
                Task { await setArchived(game, archived: true) }
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.gray)
        }

        Button(role: .destructive) {
            gamePendingDeletion = game
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @MainActor
    private func deleteGame(_ game: Game) async {
        do {
            try await supabase.from("games")
                .delete()
                .eq("id", value: game.id)
                .execute()
            if selectedGame == game { selectedGame = nil }
            withAnimation {
                games.removeAll { $0.id == game.id }
            }
            // No loadGames() here — same reasoning as setArchived, a full
            // reload would fight the animation above. The realtime
            // subscription's applyGameChange also removes this row when
            // its own delete event arrives, which is a harmless no-op
            // against an array that no longer has it, and is what keeps
            // another co-admin's device in sync with this deletion.
        } catch {
            errorMessage = error.localizedDescription
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
                .foregroundStyle(Color.primary)
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
        // Clear the flag on the way out too: this guard returns before the
        // `isLoading = false` at the bottom, so with the flag now defaulting
        // to true, a nil userID would otherwise spin forever.
        guard let userID = auth.userID else {
            isLoading = false
            return
        }
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
                struct JoinedGameRow: Decodable { let status: PlayerStatus; let games: Game }
                let rows: [JoinedGameRow] = try await supabase.from("game_players")
                    .select("status, games(*)")
                    .eq("profile_id", value: userID)
                    .execute()
                    .value
                games = rows.map(\.games)
                myPlayerStatusByGameID = Dictionary(
                    rows.map { ($0.games.id, $0.status) },
                    uniquingKeysWith: { current, _ in current }
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview("With existing games") {
    let vm = AuthViewModel()
    vm.role = .admin

    let sampleGames: [Game] = [
        Game(
            id: UUID(),
            name: "Sunday Open Play",
            location: "Community Center",
            startsAt: Date(),
            numCourts: 4,
            isDoubles: true,
            format: .kingOfTheCourt,
            formatSettings: [:],
            joinCode: "7K2P9Q",
            status: "live"
        ),
        Game(
            id: UUID(),
            name: "Wednesday Peg Board",
            location: "Downtown Sports Hall",
            startsAt: Date().addingTimeInterval(3600 * 24),
            numCourts: 3,
            isDoubles: true,
            format: .pegBoard,
            formatSettings: [:],
            joinCode: "PB44ZZ",
            status: "draft"
        ),
        Game(
            id: UUID(),
            name: "Friday Night Tournament",
            location: "Westside Courts",
            startsAt: Date().addingTimeInterval(-3600 * 24 * 3),
            numCourts: 8,
            isDoubles: true,
            format: .tournamentSingleElim,
            formatSettings: [:],
            joinCode: "TRNY01",
            status: "ended"
        )
    ]

    return MyGamesView(auth: vm, previewGames: sampleGames).environment(DeepLinkRouter())
}

#Preview("Empty") {
    let vm = AuthViewModel()
    vm.role = .admin

    return MyGamesView(auth: vm).environment(DeepLinkRouter())
}
