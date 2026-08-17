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

    private let labelColor = Color(red: 0x4D / 255, green: 0x3E / 255, blue: 0x00 / 255)
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    private var perTeam: Int { viewModel.playersPerTeam(for: court) }
    private var isDoubles: Bool { perTeam > 1 }
    private var canStart: Bool { teamA.count == perTeam && teamB.count == perTeam }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(.black)
                        .background(Color(.systemGray5), in: Capsule())
                        .buttonStyle(.plain)

                    Spacer()

                    Text(isDoubles ? "Build teams" : "Pick players")
                        .font(.headline)

                    Spacer()

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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .foregroundStyle(canStart ? .white : .black)
                    .background(canStart ? accentColor : Color(.systemGray5), in: Capsule())
                    .buttonStyle(.plain)
                    .disabled(!canStart || isStarting)
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        teamSection(title: "Team A", players: teamA) { player in
                            teamA.removeAll { $0.id == player.id }
                        }

                        teamSection(title: "Team B", players: teamB) { player in
                            teamB.removeAll { $0.id == player.id }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Queue")
                                .font(.subheadline)
                                .foregroundStyle(labelColor)

                            VStack(spacing: 0) {
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
                                        .padding()
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(teamA.count == perTeam && teamB.count == perTeam)

                                    if player.id != availablePlayers.last?.id {
                                        Rectangle()
                                            .fill(labelColor.opacity(0.15))
                                            .frame(height: 1)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
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
    private func teamSection(title: String, players: [GamePlayer], remove: @escaping (GamePlayer) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(labelColor)

            VStack(alignment: .leading, spacing: 0) {
                if players.isEmpty {
                    Text("No players yet")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 12)

                    Rectangle()
                        .fill(labelColor.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Text("Tap a player below to add")
                        .font(.subheadline)
                        .foregroundStyle(labelColor)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
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
                            .padding()
                        }
                        .buttonStyle(.plain)

                        if player.id != players.last?.id {
                            Rectangle()
                                .fill(labelColor.opacity(0.15))
                                .frame(height: 1)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    let game = Game(
        id: UUID(),
        name: "Sunday Open Play",
        location: "Community Center",
        startsAt: Date(),
        numCourts: 4,
        isDoubles: true,
        format: .kingOfTheCourt,
        formatSettings: [:],
        joinCode: "7K2P9Q",
        status: "draft"
    )
    return StartMatchSheet(
        viewModel: LiveDashboardViewModel(game: game),
        court: Court(id: UUID(), gameId: game.id, name: "Court 1", position: 0, isLaneSplit: false, isChallengeCourt: false, winStreak: 0, singlesOverride: nil)
    )
}
