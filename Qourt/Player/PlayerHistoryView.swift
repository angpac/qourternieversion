//
//  PlayerHistoryView.swift
//  Qourt
//

import SwiftUI
import Supabase

private struct MatchHistoryItem: Identifiable {
    let id: UUID
    let opponents: String
    let scoreA: Int
    let scoreB: Int
    let won: Bool
}

struct PlayerHistoryView: View {
    let game: Game

    @State private var thisGameMatches: [MatchHistoryItem] = []
    @State private var allTimeGamesPlayed = 0
    @State private var allTimeWins = 0
    @State private var isLoading = true

    private var winRate: Double {
        allTimeGamesPlayed == 0 ? 0 : Double(allTimeWins) / Double(allTimeGamesPlayed)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List {
                    Section("All-time") {
                        LabeledContent("Games played", value: "\(allTimeGamesPlayed)")
                        LabeledContent("Wins", value: "\(allTimeWins)")
                        LabeledContent("Win rate", value: allTimeGamesPlayed == 0 ? "None yet" : "\(Int(winRate * 100))%")
                    }

                    Section("This game") {
                        if thisGameMatches.isEmpty {
                            Text("No completed matches yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(thisGameMatches) { match in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(match.won ? "Won" : "Lost")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(match.won ? .green : .red)
                                        Text("vs \(match.opponents)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(match.scoreA) – \(match.scoreB)")
                                        .font(.subheadline.monospacedDigit())
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History & stats")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let userID = (try? await supabase.auth.session)?.user.id else { return }

        struct MyPlayerRow: Decodable { let id: UUID }
        guard let myPlayer: MyPlayerRow = try? await supabase.from("game_players")
            .select("id")
            .eq("game_id", value: game.id)
            .eq("profile_id", value: userID)
            .single()
            .execute()
            .value
        else { return }

        await loadThisGameHistory(myGamePlayerID: myPlayer.id)
        await loadAllTimeStats(profileID: userID)
    }

    private func loadThisGameHistory(myGamePlayerID: UUID) async {
        struct MatchPlayerRow: Decodable {
            let match_id: UUID
            let team: String
            let game_players: NameOnly
        }
        struct NameOnly: Decodable { let display_name: String }

        let myRows: [MatchPlayerRow] = (try? await supabase.from("match_players")
            .select("match_id, team, game_players(display_name)")
            .eq("game_player_id", value: myGamePlayerID)
            .execute()
            .value) ?? []

        guard !myRows.isEmpty else { return }

        let matches: [Match] = (try? await supabase.from("matches")
            .select()
            .in("id", values: myRows.map(\.match_id))
            .eq("status", value: MatchStatus.confirmed.rawValue)
            .order("ended_at", ascending: false)
            .execute()
            .value) ?? []

        guard !matches.isEmpty else { return }

        let allRows: [MatchPlayerRow] = (try? await supabase.from("match_players")
            .select("match_id, team, game_players(display_name)")
            .in("match_id", values: matches.map(\.id))
            .execute()
            .value) ?? []

        thisGameMatches = matches.compactMap { match in
            guard let scoreA = match.scoreA, let scoreB = match.scoreB,
                  let myRow = myRows.first(where: { $0.match_id == match.id }) else { return nil }
            let won = myRow.team == "a" ? scoreA > scoreB : scoreB > scoreA
            let opponents = allRows
                .filter { $0.match_id == match.id && $0.team != myRow.team }
                .map(\.game_players.display_name)
                .joined(separator: " & ")
            return MatchHistoryItem(id: match.id, opponents: opponents, scoreA: scoreA, scoreB: scoreB, won: won)
        }
    }

    private func loadAllTimeStats(profileID: UUID) async {
        struct GamePlayerIDRow: Decodable { let id: UUID }
        let myGamePlayerRows: [GamePlayerIDRow] = (try? await supabase.from("game_players")
            .select("id")
            .eq("profile_id", value: profileID)
            .execute()
            .value) ?? []

        guard !myGamePlayerRows.isEmpty else { return }
        let myIDs = myGamePlayerRows.map(\.id)

        struct MatchPlayerRow: Decodable {
            let match_id: UUID
            let game_player_id: UUID
            let team: String
        }
        let myRows: [MatchPlayerRow] = (try? await supabase.from("match_players")
            .select("match_id, game_player_id, team")
            .in("game_player_id", values: myIDs)
            .execute()
            .value) ?? []

        guard !myRows.isEmpty else { return }

        struct MatchScoreRow: Decodable {
            let id: UUID
            let score_a: Int?
            let score_b: Int?
        }
        let matches: [MatchScoreRow] = (try? await supabase.from("matches")
            .select("id, score_a, score_b")
            .in("id", values: Array(Set(myRows.map(\.match_id))))
            .eq("status", value: MatchStatus.confirmed.rawValue)
            .execute()
            .value) ?? []

        let matchByID = Dictionary(uniqueKeysWithValues: matches.map { ($0.id, $0) })
        var played = 0
        var wins = 0
        for row in myRows {
            guard let match = matchByID[row.match_id],
                  let scoreA = match.score_a, let scoreB = match.score_b else { continue }
            played += 1
            let won = row.team == "a" ? scoreA > scoreB : scoreB > scoreA
            if won { wins += 1 }
        }
        allTimeGamesPlayed = played
        allTimeWins = wins
    }
}

#Preview {
    NavigationStack {
        PlayerHistoryView(game: Game(
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
