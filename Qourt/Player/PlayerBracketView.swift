//
//  PlayerBracketView.swift
//  Qourt
//

import SwiftUI

/// Read-only mirror of the admin's BracketView — players can watch the
/// whole bracket live, but only an admin can start/score matches, so this
/// has no tappable actions at all.
struct PlayerBracketView: View {
    @State private var viewModel: BracketViewModel

    init(game: Game) {
        _viewModel = State(initialValue: BracketViewModel(game: game))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if viewModel.tournament == nil {
                    ContentUnavailableView(
                        "Bracket not set up yet",
                        systemImage: "trophy",
                        description: Text("The admin will generate the bracket once everyone's joined.")
                    )
                } else {
                    if let championName = viewModel.championName {
                        VStack(spacing: 8) {
                            Image(systemName: "trophy.fill").font(.system(size: 32)).foregroundStyle(.yellow)
                            Text("Champion").font(.caption).foregroundStyle(.secondary)
                            Text(championName).font(.title2.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                    }

                    ForEach(rounds, id: \.self) { key in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(roundLabel(bracket: key.bracket, round: key.round)).font(.headline)
                            ForEach(viewModel.tournamentMatches.filter { $0.bracket == key.bracket && $0.round == key.round }.sorted(by: { $0.slot < $1.slot })) { tm in
                                matchRow(tm)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Bracket")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
        .refreshable { await viewModel.loadAll() }
    }

    private var rounds: [BracketRoundKey] {
        Array(Set(viewModel.tournamentMatches.map { BracketRoundKey(bracket: $0.bracket, round: $0.round) }))
            .sorted { bracketOrder($0.bracket, $0.round) < bracketOrder($1.bracket, $1.round) }
    }

    private func bracketOrder(_ bracket: String, _ round: Int) -> (Int, Int) {
        let bracketRank = ["winners": 0, "losers": 1, "final": 2][bracket] ?? 3
        return (bracketRank, round)
    }

    private func matchRow(_ tm: TournamentMatch) -> some View {
        let match = viewModel.activeMatches[tm.id]?.match
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.name(for: tm.teamAPlayerIds))
                Text(viewModel.name(for: tm.teamBPlayerIds))
            }
            Spacer()
            if let match, let a = match.scoreA, let b = match.scoreB {
                Text("\(a) – \(b)").font(.subheadline.monospacedDigit())
            } else if tm.isReadyToStart {
                Text("Ready").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("TBD").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func roundLabel(bracket: String, round: Int) -> String {
        switch bracket {
        case "final": return "Grand Final"
        case "losers": return "Losers — Round \(round)"
        default: return "Round \(round)"
        }
    }
}
