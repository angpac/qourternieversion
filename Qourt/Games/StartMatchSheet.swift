//
//  StartMatchSheet.swift
//  Qourt
//

import SwiftUI

struct StartMatchSheet: View {
    var viewModel: LiveDashboardViewModel
    let court: Court

    @Environment(\.dismiss) private var dismiss
    @State private var teamA: [GamePlayer] = []
    @State private var teamB: [GamePlayer] = []
    @State private var isStarting = false

    private var perTeam: Int { viewModel.playersPerTeam(for: court) }
    private var isDoubles: Bool { perTeam > 1 }
    private var canStart: Bool { teamA.count == perTeam && teamB.count == perTeam }

    var body: some View {
        NavigationStack {
            List {
                Section("Team A") {
                    teamRow(teamA) { player in teamA.removeAll { $0.id == player.id } }
                    if teamA.count < perTeam {
                        Text("Tap a player below to add")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Team B") {
                    teamRow(teamB) { player in teamB.removeAll { $0.id == player.id } }
                    if teamB.count < perTeam {
                        Text("Tap a player below to add")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Queue") {
                    ForEach(availablePlayers) { player in
                        Button {
                            assign(player)
                        } label: {
                            HStack {
                                Text(player.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(player.skillLevel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(teamA.count == perTeam && teamB.count == perTeam)
                    }
                }
            }
            .navigationTitle(isDoubles ? "Build teams" : "Pick players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isStarting = true
                            await viewModel.startMatch(court: court, teamA: teamA, teamB: teamB)
                            isStarting = false
                            dismiss()
                        }
                    } label: {
                        if isStarting {
                            ProgressView()
                        } else {
                            Text("Assign")
                        }
                    }
                    .disabled(!canStart || isStarting)
                }
            }
        }
    }

    private var availablePlayers: [GamePlayer] {
        let assignedIDs = Set((teamA + teamB).map(\.id))
        return viewModel.queue.filter { !assignedIDs.contains($0.id) }
    }

    private func assign(_ player: GamePlayer) {
        if teamA.count < perTeam {
            teamA.append(player)
        } else if teamB.count < perTeam {
            teamB.append(player)
        }
    }

    @ViewBuilder
    private func teamRow(_ players: [GamePlayer], remove: @escaping (GamePlayer) -> Void) -> some View {
        if players.isEmpty {
            Text("No players yet")
                .foregroundStyle(.secondary)
        } else {
            ForEach(players) { player in
                Button {
                    remove(player)
                } label: {
                    HStack {
                        Text(player.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
