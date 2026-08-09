//
//  GameSummaryView.swift
//  Qourt
//

import SwiftUI
import Supabase

private struct PlayerTally: Identifiable {
    let id: UUID
    let name: String
    var gamesPlayed = 0
    var wins = 0
}

struct GameSummaryView: View {
    let game: Game

    @State private var totalMatches = 0
    @State private var tallies: [PlayerTally] = []
    @State private var isLoading = true
    @State private var isSavingTemplate = false
    @State private var templateName = ""
    @State private var templateSaveError: String?
    @State private var didSaveTemplate = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List {
                    Section {
                        LabeledContent("Matches played", value: "\(totalMatches)")
                    }

                    if let standout = tallies.max(by: { $0.wins < $1.wins }), standout.wins > 0 {
                        Section("Standout performer") {
                            HStack {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                                Text(standout.name)
                                Spacer()
                                Text("\(standout.wins) wins")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Games per player") {
                        ForEach(tallies.sorted { $0.gamesPlayed > $1.gamesPlayed }) { tally in
                            HStack {
                                Text(tally.name)
                                Spacer()
                                Text("\(tally.gamesPlayed) played · \(tally.wins) won")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section {
                        if didSaveTemplate {
                            Label("Saved as template", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Save this setup as a template") {
                                templateName = game.name
                                templateSaveError = nil
                                isSavingTemplate = true
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Game summary")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Save as template", isPresented: $isSavingTemplate) {
            TextField("Template name", text: $templateName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Task { await saveTemplate() }
            }
        } message: {
            Text("Reuse these courts and rotation settings next time you create a game.")
        }
        .alert("Couldn't save template", isPresented: .constant(templateSaveError != nil)) {
            Button("OK") { templateSaveError = nil }
        } message: {
            Text(templateSaveError ?? "")
        }
    }

    @MainActor
    private func saveTemplate() async {
        guard let userID = (try? await supabase.auth.session)?.user.id else { return }
        let trimmed = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let error = await TemplatesViewModel.save(name: trimmed, from: game, ownerID: userID) {
            templateSaveError = error
        } else {
            didSaveTemplate = true
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        struct MatchRow: Decodable {
            let id: UUID
            let score_a: Int?
            let score_b: Int?
        }
        struct MatchPlayerRow: Decodable {
            let match_id: UUID
            let team: String
            let game_players: NameOnly
        }
        struct NameOnly: Decodable {
            let id: UUID
            let display_name: String
        }

        let matches: [MatchRow] = (try? await supabase.from("matches")
            .select("id, score_a, score_b")
            .eq("game_id", value: game.id)
            .eq("status", value: MatchStatus.confirmed.rawValue)
            .execute()
            .value) ?? []

        totalMatches = matches.count
        guard !matches.isEmpty else { return }

        let rows: [MatchPlayerRow] = (try? await supabase.from("match_players")
            .select("match_id, team, game_players(id, display_name)")
            .in("match_id", values: matches.map(\.id))
            .execute()
            .value) ?? []

        var byPlayer: [UUID: PlayerTally] = [:]
        for match in matches {
            let players = rows.filter { $0.match_id == match.id }
            guard let scoreA = match.score_a, let scoreB = match.score_b else { continue }
            let winningTeam = scoreA > scoreB ? "a" : "b"

            for row in players {
                var tally = byPlayer[row.game_players.id] ?? PlayerTally(id: row.game_players.id, name: row.game_players.display_name)
                tally.gamesPlayed += 1
                if row.team == winningTeam { tally.wins += 1 }
                byPlayer[row.game_players.id] = tally
            }
        }
        tallies = Array(byPlayer.values)
    }
}

#Preview {
    NavigationStack {
        GameSummaryView(game: Game(
            id: UUID(),
            name: "Sunday Open Play",
            location: nil,
            startsAt: nil,
            numCourts: 4,
            isDoubles: true,
            format: .kingOfTheCourt,
            formatSettings: [:],
            joinCode: "ABC123",
            status: "ended"
        ))
    }
}
