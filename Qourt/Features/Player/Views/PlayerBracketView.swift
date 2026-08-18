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

    private let labelColor = Color.appSecondaryText

    init(game: Game) {
        _viewModel = State(initialValue: BracketViewModel(game: game))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if viewModel.tournament == nil {
                    emptyState
                } else {
                    if let championName = viewModel.championName {
                        VStack(spacing: 8) {
                            Image(systemName: "trophy.fill").font(.system(size: 32)).foregroundStyle(.yellow)
                            Text("Champion")
                                .font(.custom("DIN-Regular", size: 13))
                                .foregroundStyle(labelColor)
                            Text(championName)
                                .font(.custom("DIN-Medium", size: 20))
                                .foregroundStyle(Color.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                    }

                    ForEach(rounds, id: \.self) { key in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(roundLabel(bracket: key.bracket, round: key.round))
                                .font(.custom("DIN-Medium", size: 17))
                                .foregroundStyle(labelColor)
                            ForEach(viewModel.tournamentMatches.filter { $0.bracket == key.bracket && $0.round == key.round }.sorted(by: { $0.slot < $1.slot })) { tm in
                                matchRow(tm)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Bracket")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
        .refreshable { await viewModel.loadAll() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "trophy")
                .font(.system(size: 80))
                .foregroundStyle(Color.primary)

            Text("Bracket not set up yet")
                .font(.custom("DIN-Regular", size: 28))
                .fontWeight(.bold)

            Text("The admin will generate the bracket once everyone's joined.")
                .font(.custom("DIN-Regular", size: 15))
                .foregroundStyle(labelColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
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
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(Color.primary)
                Text(viewModel.name(for: tm.teamBPlayerIds))
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(Color.primary)
            }
            Spacer()
            if let match, let a = match.scoreA, let b = match.scoreB {
                Text("\(a) – \(b)")
                    .font(.custom("DIN-Medium", size: 15))
                    .foregroundStyle(Color.primary)
            } else if tm.isReadyToStart {
                Text("Ready")
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)
            } else {
                Text("TBD")
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)
            }
        }
        .padding(10)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))
    }

    private func roundLabel(bracket: String, round: Int) -> String {
        switch bracket {
        case "final": return "Grand Final"
        case "losers": return "Losers Round \(round)"
        default: return "Round \(round)"
        }
    }
}

#Preview {
    NavigationStack {
        PlayerBracketView(game: Game(
            id: UUID(),
            name: "Sunday Open Play",
            location: "Community Center",
            startsAt: Date(),
            numCourts: 4,
            isDoubles: true,
            format: .tournamentSingleElim,
            formatSettings: [:],
            joinCode: "7K2P9Q",
            status: "active"
        ))
    }
}
