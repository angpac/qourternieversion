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

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if players.isEmpty {
                ContentUnavailableView("No players yet", systemImage: "person.3")
            } else {
                List(players) { player in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(player.displayName)
                            if player.status == .onCourt {
                                Text("On court")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else if player.status == .resting {
                                Text("Resting")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(player.skillLevel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Roster")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
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
