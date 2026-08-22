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

private struct MyMatchRow: Identifiable {
    let id: UUID
    let scoreA: Int
    let scoreB: Int
    let myTeam: String
    let opponentNames: String
    var won: Bool { myTeam == "a" ? scoreA > scoreB : scoreB > scoreA }
    var myScore: Int { myTeam == "a" ? scoreA : scoreB }
    var opponentScore: Int { myTeam == "a" ? scoreB : scoreA }
}

struct GameSummaryView: View {
    let game: Game
    var isAdmin: Bool = true

    @State private var totalMatches = 0
    @State private var tallies: [PlayerTally] = []
    @State private var myMatches: [MyMatchRow] = []
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

                    if isAdmin {
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
                    }

                    if !isAdmin && !myMatches.isEmpty {
                        Section {
                            VStack(spacing: 0) {
                                ForEach(myMatches) { match in
                                    HStack {
                                        Text(match.opponentNames.isEmpty ? "Match" : "vs \(match.opponentNames)")
                                            .font(.custom("DIN-Regular", size: 17))
                                            .foregroundStyle(Color.primary)
                                        Spacer()
                                        Text("\(match.myScore) – \(match.opponentScore)")
                                            .font(.custom("DIN-Medium", size: 15))
                                            .foregroundStyle(match.won ? accentColor : labelColor)
                                    }
                                    .padding()

                                    if match.id != myMatches.last?.id {
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
                            Text("Your matches")
                                .font(.custom("DIN-Regular", size: 15))
                                .foregroundStyle(labelColor)
                        }
                    }

                    if isAdmin {
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

        if !isAdmin {
            await loadMyMatches()
        }
    }

    /// The viewing player's own confirmed matches — queried from `matches`
    /// directly (rather than ordering `match_players` by an embedded
    /// referenced-table column) since that pattern was the confirmed cause
    /// of a similar "always shows stale data" bug elsewhere in this app.
    @MainActor
    private func loadMyMatches() async {
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

        struct TeamOnly: Decodable { let team: String }
        struct MyMatchQueryRow: Decodable {
            let id: UUID
            let score_a: Int?
            let score_b: Int?
            let match_players: [TeamOnly]
        }

        let matches: [MyMatchQueryRow] = (try? await supabase.from("matches")
            .select("id, score_a, score_b, match_players!inner(team)")
            .eq("game_id", value: game.id)
            .eq("status", value: MatchStatus.confirmed.rawValue)
            .eq("match_players.game_player_id", value: myPlayer.id)
            .order("started_at", ascending: false)
            .execute()
            .value) ?? []

        guard !matches.isEmpty else {
            myMatches = []
            return
        }

        struct NameOnly: Decodable {
            let id: UUID
            let display_name: String
        }
        struct AllPlayersRow: Decodable {
            let match_id: UUID
            let team: String
            let game_players: NameOnly
        }
        let allRows: [AllPlayersRow] = (try? await supabase.from("match_players")
            .select("match_id, team, game_players(id, display_name)")
            .in("match_id", values: matches.map(\.id))
            .execute()
            .value) ?? []

        myMatches = matches.compactMap { match in
            guard let scoreA = match.score_a, let scoreB = match.score_b,
                  let myTeam = match.match_players.first?.team else { return nil }
            let opponentTeam = myTeam == "a" ? "b" : "a"
            let opponentNames = allRows
                .filter { $0.match_id == match.id && $0.team == opponentTeam }
                .map(\.game_players.display_name)
                .joined(separator: " & ")
            return MyMatchRow(id: match.id, scoreA: scoreA, scoreB: scoreB, myTeam: myTeam, opponentNames: opponentNames)
        }
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
