//
//  BracketView.swift
//  Qourt
//

import SwiftUI

struct BracketView: View {
    @State private var viewModel: BracketViewModel
    @State private var matchToStart: TournamentMatch?
    @State private var matchToScore: TournamentMatch?
    @State private var isShowingSetup = false

    init(game: Game) {
        _viewModel = State(initialValue: BracketViewModel(game: game))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.gameStatus == "ended" {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("This game has ended.", systemImage: "checkmark.seal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        NavigationLink("View game summary") {
                            GameSummaryView(game: viewModel.game)
                        }
                        .font(.footnote.bold())
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if viewModel.tournament == nil {
                    noBracketYet
                } else {
                    if let championName = viewModel.championName {
                        championBanner(championName)
                    }

                    if !viewModel.readyMatches.isEmpty {
                        readySection
                    }

                    ForEach(rounds, id: \.self) { key in
                        roundSection(bracket: key.bracket, round: key.round)
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
        .sheet(item: $matchToStart) { tm in
            NavigationStack {
                List(viewModel.openCourts) { court in
                    Button(court.name) {
                        Task {
                            await viewModel.startMatch(tm, on: court)
                            matchToStart = nil
                        }
                    }
                }
                .navigationTitle("Choose a court")
                .navigationBarTitleDisplayMode(.inline)
                .overlay {
                    if viewModel.openCourts.isEmpty {
                        ContentUnavailableView("No open courts", systemImage: "sportscourt")
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { matchToStart = nil }
                    }
                }
            }
        }
        .sheet(item: $matchToScore) { tm in
            TournamentMatchDetailSheet(viewModel: viewModel, tournamentMatch: tm)
        }
        .sheet(isPresented: $isShowingSetup) {
            NavigationStack {
                TournamentSetupView(game: viewModel.game) { _ in
                    isShowingSetup = false
                    Task { await viewModel.loadAll() }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingSetup = false }
                    }
                }
            }
        }
    }

    private var rounds: [BracketRoundKey] {
        Array(Set(viewModel.tournamentMatches.map { BracketRoundKey(bracket: $0.bracket, round: $0.round) }))
            .sorted { bracketOrder($0.bracket, $0.round) < bracketOrder($1.bracket, $1.round) }
    }

    private func bracketOrder(_ bracket: String, _ round: Int) -> (Int, Int) {
        let bracketRank = ["winners": 0, "losers": 1, "final": 2][bracket] ?? 3
        return (bracketRank, round)
    }

    private var noBracketYet: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Bracket not set up yet")
                .font(.title3.bold())
            Text("Once everyone's joined, seed players and generate the bracket.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Set up tournament") { isShowingSetup = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func championBanner(_ name: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill").font(.system(size: 32)).foregroundStyle(.yellow)
            Text("Champion").font(.caption).foregroundStyle(.secondary)
            Text(name).font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
    }

    private var readySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ready to play").font(.headline)
            ForEach(viewModel.readyMatches) { tm in
                Button {
                    matchToStart = tm
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(viewModel.name(for: tm.teamAPlayerIds)) vs \(viewModel.name(for: tm.teamBPlayerIds))")
                            Text(roundLabel(bracket: tm.bracket, round: tm.round))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill").foregroundStyle(.tint)
                    }
                }
                .buttonStyle(.plain)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func roundSection(bracket: String, round: Int) -> some View {
        let matches = viewModel.tournamentMatches
            .filter { $0.bracket == bracket && $0.round == round }
            .sorted { $0.slot < $1.slot }

        return VStack(alignment: .leading, spacing: 8) {
            Text(roundLabel(bracket: bracket, round: round)).font(.headline)
            ForEach(matches) { tm in
                matchRow(tm)
            }
        }
    }

    @ViewBuilder
    private func matchRow(_ tm: TournamentMatch) -> some View {
        let mwp = viewModel.activeMatches[tm.id]
        Button {
            if mwp != nil { matchToScore = tm }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.name(for: tm.teamAPlayerIds))
                        .fontWeight(isWinner(tm, team: "a") ? .bold : .regular)
                    Text(viewModel.name(for: tm.teamBPlayerIds))
                        .fontWeight(isWinner(tm, team: "b") ? .bold : .regular)
                }
                Spacer()
                if let match = mwp?.match, let a = match.scoreA, let b = match.scoreB {
                    Text("\(a) – \(b)").font(.subheadline.monospacedDigit())
                } else if tm.isReadyToStart {
                    Text("Ready").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("TBD").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .disabled(mwp == nil)
    }

    private func isWinner(_ tm: TournamentMatch, team: String) -> Bool {
        guard let match = viewModel.activeMatches[tm.id]?.match,
              match.status == .confirmed,
              let a = match.scoreA, let b = match.scoreB
        else { return false }
        return team == "a" ? a > b : b > a
    }

    private func roundLabel(bracket: String, round: Int) -> String {
        switch bracket {
        case "final": return "Grand Final"
        case "losers": return "Losers Round \(round)"
        default: return "Round \(round)"
        }
    }
}
