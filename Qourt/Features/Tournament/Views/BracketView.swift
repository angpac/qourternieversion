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
    @State private var isShowingScoreboard = false

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    init(game: Game) {
        _viewModel = State(initialValue: BracketViewModel(game: game))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.gameStatus == "ended" {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("This game has ended.", systemImage: "checkmark.seal")
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(labelColor)
                        NavigationLink("View game summary") {
                            GameSummaryView(game: viewModel.game)
                        }
                        .font(.custom("DIN-Medium", size: 13))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12))
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
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Bracket")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingScoreboard = true
                } label: {
                    Label("Scoreboard", systemImage: "rectangle.on.rectangle")
                }
                .disabled(viewModel.tournament == nil)
            }
        }
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
        .refreshable { await viewModel.loadAll() }
        .fullScreenCover(isPresented: $isShowingScoreboard) {
            TournamentScoreboardView(viewModel: viewModel)
        }
        .sheet(item: $matchToStart) { tm in
            NavigationStack {
                List(viewModel.openCourts) { court in
                    Button(court.name) {
                        Task {
                            await viewModel.startMatch(tm, on: court)
                            matchToStart = nil
                        }
                    }
                    .font(.custom("DIN-Regular", size: 17))
                    .foregroundStyle(Color.primary)
                    .listRowBackground(Color.appSurface)
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground.ignoresSafeArea())
                .navigationTitle("Choose a court")
                .navigationBarTitleDisplayMode(.inline)
                .overlay {
                    if viewModel.openCourts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "sportscourt")
                                .font(.system(size: 60))
                                .foregroundStyle(Color.primary)
                            Text("No open courts")
                                .font(.custom("DIN-Medium", size: 20))
                                .foregroundStyle(Color.primary)
                        }
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
                .foregroundStyle(labelColor)
            Text("Bracket not set up yet")
                .font(.custom("DIN-Medium", size: 20))
                .foregroundStyle(Color.primary)
            Text("Once everyone's joined, seed players and generate the bracket.")
                .font(.custom("DIN-Regular", size: 15))
                .foregroundStyle(labelColor)
                .multilineTextAlignment(.center)
            Button {
                isShowingSetup = true
            } label: {
                Text("Set up tournament")
                    .font(.custom("DIN-Medium", size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(accentColor, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func championBanner(_ name: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill").font(.system(size: 32)).foregroundStyle(.yellow)
            Text("Champion")
                .font(.custom("DIN-Regular", size: 13))
                .foregroundStyle(labelColor)
            Text(name)
                .font(.custom("DIN-Medium", size: 20))
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
    }

    private var readySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ready to play")
                .font(.custom("DIN-Medium", size: 17))
                .foregroundStyle(labelColor)
            ForEach(viewModel.readyMatches) { tm in
                Button {
                    matchToStart = tm
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(viewModel.name(for: tm.teamAPlayerIds)) vs \(viewModel.name(for: tm.teamBPlayerIds))")
                                .font(.custom("DIN-Regular", size: 15))
                                .foregroundStyle(Color.primary)
                            Text(roundLabel(bracket: tm.bracket, round: tm.round))
                                .font(.custom("DIN-Regular", size: 13))
                                .foregroundStyle(labelColor)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill").foregroundStyle(accentColor)
                    }
                    .padding(10)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func roundSection(bracket: String, round: Int) -> some View {
        let matches = viewModel.tournamentMatches
            .filter { $0.bracket == bracket && $0.round == round }
            .sorted { $0.slot < $1.slot }

        return VStack(alignment: .leading, spacing: 8) {
            Text(roundLabel(bracket: bracket, round: round))
                .font(.custom("DIN-Medium", size: 17))
                .foregroundStyle(labelColor)
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
                        .font(.custom(isWinner(tm, team: "a") ? "DIN-Medium" : "DIN-Regular", size: 15))
                        .foregroundStyle(Color.primary)
                    Text(viewModel.name(for: tm.teamBPlayerIds))
                        .font(.custom(isWinner(tm, team: "b") ? "DIN-Medium" : "DIN-Regular", size: 15))
                        .foregroundStyle(Color.primary)
                }
                Spacer()
                if let match = mwp?.match, let a = match.scoreA, let b = match.scoreB {
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
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
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

#Preview {
    NavigationStack {
        BracketView(game: Game(
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
