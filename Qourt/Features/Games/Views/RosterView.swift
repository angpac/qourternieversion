//
//  RosterView.swift
//  Qourt
//

import SwiftUI

struct RosterView: View {
    @State private var viewModel: RosterViewModel
    private let skipsInitialLoad: Bool

    init(game: Game, previewViewModel: RosterViewModel? = nil) {
        _viewModel = State(initialValue: previewViewModel ?? RosterViewModel(game: game))
        skipsInitialLoad = previewViewModel != nil
    }

    private var grouped: [(PlayerStatus, [GamePlayer])] {
        let order: [PlayerStatus] = [.onCourt, .queued, .resting, .removed]
        return order.compactMap { status in
            let players = viewModel.players.filter { $0.status == status }
            return players.isEmpty ? nil : (status, players)
        }
    }

    private var pendingPlayers: [GamePlayer] {
        viewModel.players.filter { $0.status == .pending }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.players.isEmpty {
                emptyState
            } else {
                List {
                    if !pendingPlayers.isEmpty {
                        Section {
                            ForEach(pendingPlayers) { player in
                                PendingRosterRow(player: player, viewModel: viewModel)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        } header: {
                            sectionHeader("Waiting for approval")
                        }
                    }
                    ForEach(grouped, id: \.0) { status, players in
                        Section {
                            ForEach(players) { player in
                                RosterRow(player: player, viewModel: viewModel)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        } header: {
                            sectionHeader(sectionTitle(status))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Roster")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !skipsInitialLoad else { return }
            await viewModel.start()
        }
        .onDisappear {
            guard !skipsInitialLoad else { return }
            viewModel.stop()
        }
        .refreshable { await viewModel.load() }
        .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom("DIN-Regular", size: 15))
            .foregroundStyle(Color.appSecondaryText)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.3")
                .font(.system(size: 80))
                .foregroundStyle(Color.primary)

            Text("No players yet")
                .font(.custom("DIN-Regular", size: 36))
                .fontWeight(.bold)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionTitle(_ status: PlayerStatus) -> String {
        switch status {
        case .onCourt: "On court"
        case .queued: "Queue"
        case .resting: "Resting"
        case .removed: "Removed"
        case .pending: "Waiting for approval"
        }
    }
}

private struct PendingRosterRow: View {
    let player: GamePlayer
    var viewModel: RosterViewModel

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                    .font(.custom("DIN-Medium", size: 17))
                    .foregroundStyle(Color.primary)
                Text(player.skillLevel)
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)
            }

            Spacer()

            Button {
                Task { await viewModel.reject(player) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

            Button {
                Task { await viewModel.approve(player) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct RosterRow: View {
    let player: GamePlayer
    var viewModel: RosterViewModel

    private let labelColor = Color.appSecondaryText

    private var matchCount: Int { viewModel.matchCounts[player.id] ?? 0 }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                    .font(.custom("DIN-Medium", size: 17))
                    .foregroundStyle(Color.primary)
                Text(player.skillLevel)
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)
            }

            Spacer()

            Text("\(matchCount) played")
                .font(.custom("DIN-Regular", size: 13))
                .foregroundStyle(labelColor)
                .padding(.trailing, 4)

            Menu {
                Menu("Skill level") {
                    ForEach(viewModel.skillLevels, id: \.self) { level in
                        Button(level) {
                            Task { await viewModel.setSkillLevel(player, to: level) }
                        }
                    }
                }

                switch player.status {
                case .queued:
                    Button("Pause") { Task { await viewModel.pause(player) } }
                    Button("Remove", role: .destructive) { Task { await viewModel.remove(player) } }
                case .resting:
                    Button("Return to queue") { Task { await viewModel.returnToQueue(player) } }
                    Button("Remove", role: .destructive) { Task { await viewModel.remove(player) } }
                case .onCourt:
                    Button("Remove", role: .destructive) { Task { await viewModel.remove(player) } }
                case .removed:
                    Button("Restore to queue") { Task { await viewModel.returnToQueue(player) } }
                case .pending:
                    EmptyView()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(Color.primary)
            }
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
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

#Preview("With roster") {
    let vm = RosterViewModel(game: previewGame)
    vm.isLoading = false
    vm.players = [
        GamePlayer(id: UUID(), gameId: previewGame.id, profileId: nil, displayName: "Awan Minton", skillLevel: "Advanced", status: .pending, queuePosition: nil, joinedAt: Date()),
        GamePlayer(id: UUID(), gameId: previewGame.id, profileId: nil, displayName: "Alex Chen", skillLevel: "Intermediate", status: .onCourt, queuePosition: nil, joinedAt: Date()),
        GamePlayer(id: UUID(), gameId: previewGame.id, profileId: nil, displayName: "Jamie Lee", skillLevel: "Advanced", status: .onCourt, queuePosition: nil, joinedAt: Date()),
        GamePlayer(id: UUID(), gameId: previewGame.id, profileId: nil, displayName: "Valentine G", skillLevel: "Beginner", status: .queued, queuePosition: 0, joinedAt: Date()),
        GamePlayer(id: UUID(), gameId: previewGame.id, profileId: nil, displayName: "Ernesto R", skillLevel: "Intermediate", status: .resting, queuePosition: nil, joinedAt: Date())
    ]
    vm.matchCounts = [:]
    return NavigationStack {
        RosterView(game: previewGame, previewViewModel: vm)
    }
}

#Preview("Empty") {
    let vm = RosterViewModel(game: previewGame)
    vm.isLoading = false
    return NavigationStack {
        RosterView(game: previewGame, previewViewModel: vm)
    }
}

#Preview("Loading") {
    let vm = RosterViewModel(game: previewGame)
    vm.isLoading = true
    return NavigationStack {
        RosterView(game: previewGame, previewViewModel: vm)
    }
}
