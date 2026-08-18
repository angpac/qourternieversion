//
//  PlayerRosterView.swift
//  Qourt
//

import SwiftUI
import Supabase

struct PlayerRosterView: View {
    let game: Game

    @State private var players: [GamePlayer] = []
    @State private var isLoading = true

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if players.isEmpty {
                emptyState
            } else {
                List(players) { player in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.displayName)
                                .font(.custom("DIN-Regular", size: 17))
                                .foregroundStyle(Color.primary)
                            if player.status == .onCourt {
                                Text("On court")
                                    .font(.custom("DIN-Regular", size: 13))
                                    .foregroundStyle(accentColor)
                            } else if player.status == .resting {
                                Text("Resting")
                                    .font(.custom("DIN-Regular", size: 13))
                                    .foregroundStyle(labelColor)
                            }
                        }
                        Spacer()
                        Text(player.skillLevel)
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(labelColor)
                    }
                    .listRowBackground(Color.appSurface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Roster")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.3")
                .font(.system(size: 80))
                .foregroundStyle(Color.primary)

            Text("No players yet")
                .font(.custom("DIN-Regular", size: 28))
                .fontWeight(.bold)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        players = (try? await supabase.from("game_players")
            .select()
            .eq("game_id", value: game.id)
            .neq("status", value: PlayerStatus.removed.rawValue)
            .order("display_name", ascending: true)
            .execute()
            .value) ?? []
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        PlayerRosterView(game: Game(
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
