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

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        VStack(spacing: 4) {
                            Text("\(totalMatches)")
                                .font(.custom("DIN-BlackAlternate", size: 44))
                                .foregroundStyle(Color.primary)
                            Text("Matches played")
                                .font(.custom("DIN-Regular", size: 15))
                                .foregroundStyle(labelColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    if let standout = tallies.max(by: { $0.wins < $1.wins }), standout.wins > 0 {
                        Section {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(standout.name)
                                    .font(.custom("DIN-Medium", size: 17))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Text("\(standout.wins) wins")
                                    .font(.custom("DIN-Regular", size: 15))
                                    .foregroundStyle(labelColor)
                            }
                            .padding()
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        } header: {
                            Text("Standout performer")
                                .font(.custom("DIN-Regular", size: 15))
                                .foregroundStyle(labelColor)
                        }
                    }

                    Section {
                        VStack(spacing: 0) {
                            let sorted = tallies.sorted { $0.gamesPlayed > $1.gamesPlayed }
                            ForEach(sorted) { tally in
                                HStack {
                                    Text(tally.name)
                                        .font(.custom("DIN-Regular", size: 17))
                                        .foregroundStyle(Color.primary)
                                    Spacer()
                                    Text("\(tally.gamesPlayed) played · \(tally.wins) won")
                                        .font(.custom("DIN-Regular", size: 13))
                                        .foregroundStyle(labelColor)
                                }
                                .padding()

                                if tally.id != sorted.last?.id {
                                    Rectangle()
                                        .fill(labelColor.opacity(0.15))
                                        .frame(height: 1)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    } header: {
                        Text("Games per player")
                            .font(.custom("DIN-Regular", size: 15))
                            .foregroundStyle(labelColor)
                    }

                    Section {
                        if didSaveTemplate {
                            Label("Saved as template", systemImage: "checkmark.circle.fill")
                                .font(.custom("DIN-Medium", size: 16))
                                .foregroundStyle(accentColor)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            Button {
                                templateName = game.name
                                templateSaveError = nil
                                isSavingTemplate = true
                            } label: {
                                Text("Save this setup as a template")
                                    .font(.custom("DIN-Medium", size: 16))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(accentColor, in: Capsule())
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
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
