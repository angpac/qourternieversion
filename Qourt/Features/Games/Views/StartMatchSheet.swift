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

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    private var perTeam: Int { viewModel.playersPerTeam(for: court) }
    private var isDoubles: Bool { perTeam > 1 }
    private var canStart: Bool { teamA.count == perTeam && teamB.count == perTeam }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Text(isDoubles ? "Build teams" : "Pick players")
                        .font(.custom("DIN-Medium", size: 17))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.custom("DIN-Medium", size: 15))
                                .foregroundStyle(Color.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            Task {
                                isStarting = true
                                await viewModel.startMatch(court: court, teamA: teamA, teamB: teamB)
                                isStarting = false
                                dismiss()
                            }
                        } label: {
                            Group {
                                if isStarting {
                                    ProgressView()
                                        .tint(canStart ? .white : Color.primary)
                                } else {
                                    Text("Assign")
                                        .font(.custom("DIN-Medium", size: 15))
                                        .foregroundStyle(canStart ? Color.white : Color.primary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(canStart ? accentColor : Color(.systemGray5), in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canStart || isStarting)
                    }
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
                                .font(.custom("DIN-Regular", size: 15))
                                .foregroundStyle(labelColor)

                            VStack(spacing: 0) {
                                ForEach(availablePlayers) { player in
                                    Button {
                                        assign(player)
                                    } label: {
                                        HStack {
                                            Text("\(player.displayName) - \(gamesPlayed(for: player)) played")
                                                .font(.custom("DIN-Regular", size: 17))
                                                .foregroundStyle(Color.primary)
                                            Spacer()
                                            Text(player.skillLevel)
                                                .font(.custom("DIN-Regular", size: 13))
                                                .foregroundStyle(labelColor)
                                        }
                                        .padding()
                                        .contentShape(Rectangle())
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
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
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

    private func gamesPlayed(for player: GamePlayer) -> Int {
        viewModel.gamesPlayedCount[player.id] ?? 0
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
                .font(.custom("DIN-Regular", size: 15))
                .foregroundStyle(labelColor)

            VStack(alignment: .leading, spacing: 0) {
                if players.isEmpty {
                    Text("No players yet")
                        .font(.custom("DIN-Medium", size: 17))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal)
                        .padding(.top, 12)

                    Rectangle()
                        .fill(labelColor.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Text("Tap a player below to add")
                        .font(.custom("DIN-Regular", size: 15))
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
                                    .font(.custom("DIN-Regular", size: 17))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(labelColor)
                            }
                            .padding()
                            .contentShape(Rectangle())
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
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
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
