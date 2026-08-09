//
//  RosterView.swift
//  Qourt
//

import SwiftUI

struct RosterView: View {
    @State private var viewModel: RosterViewModel

    init(game: Game) {
        _viewModel = State(initialValue: RosterViewModel(game: game))
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
            } else if viewModel.players.isEmpty {
                ContentUnavailableView("No players yet", systemImage: "person.3")
            } else {
                List {
                    if !pendingPlayers.isEmpty {
                        Section("Waiting for approval") {
                            ForEach(pendingPlayers) { player in
                                PendingRosterRow(player: player, viewModel: viewModel)
                            }
                        }
                    }
                    ForEach(grouped, id: \.0) { status, players in
                        Section(sectionTitle(status)) {
                            ForEach(players) { player in
                                RosterRow(player: player, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Roster")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
        .refreshable { await viewModel.load() }
        .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                Text(player.skillLevel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await viewModel.reject(player) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

            Button {
                Task { await viewModel.approve(player) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct RosterRow: View {
    let player: GamePlayer
    var viewModel: RosterViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                Text(player.skillLevel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
                    .font(.title3)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RosterView(game: Game(
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
