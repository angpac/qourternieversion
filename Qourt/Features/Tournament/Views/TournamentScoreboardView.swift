//
//  TournamentScoreboardView.swift
//  Qourt
//
//  The tournament counterpart to ScoreboardView: a big-screen view for a
//  second device (an iPad courtside) showing which matches are live right
//  now with big scores, plus the full bracket underneath so spectators can
//  see where each match slots in — the pairing the PRD calls for
//  explicitly for tournament mode. Reuses the same BracketViewModel the
//  admin's Bracket View already subscribes with, so scores update here the
//  instant any player's Watch writes a new score.
//
//  Sizing is driven by GeometryReader rather than fixed device breakpoints,
//  same as ScoreboardView, so it scales smoothly across the whole iPad
//  lineup instead of needing separate layouts per model.
//

import SwiftUI

struct TournamentScoreboardView: View {
    var viewModel: BracketViewModel

    @Environment(\.dismiss) private var dismiss

    private let labelColor = Color.appSecondaryText

    var body: some View {
        GeometryReader { geo in
            let scale = scoreboardScale(for: geo.size)

            VStack(alignment: .leading, spacing: 0) {
                header(scale: scale)

                ScrollView {
                    if let championName = viewModel.championName {
                        championBanner(championName, scale: scale)
                            .padding(.horizontal, 32 * scale)
                            .padding(.top, 8 * scale)
                    }

                    if !liveMatches.isEmpty {
                        liveMatchesSection(scale: scale)
                    }

                    bracketSection(scale: scale)

                    Spacer(minLength: 24 * scale)
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    /// Same shorter-side ratio as ScoreboardView, kept in sync so a game
    /// that mixes rotation and tournament formats across sessions reads at
    /// a consistent scale on the same device.
    private func scoreboardScale(for size: CGSize) -> CGFloat {
        let shorterSide = min(size.width, size.height)
        let referenceShortSide: CGFloat = 834
        return min(max(shorterSide / referenceShortSide, 0.8), 1.35)
    }

    /// Tournament matches currently on a court, in progress or awaiting the
    /// admin's confirmation — the ones worth a dedicated live-score card, as
    /// opposed to the full bracket list further down.
    private var liveMatches: [TournamentMatch] {
        viewModel.tournamentMatches.filter { tm in
            guard let status = viewModel.activeMatches[tm.id]?.match.status else { return false }
            return status == .inProgress || status == .awaitingConfirmation
        }
    }

    private func courtName(for tm: TournamentMatch) -> String? {
        guard let courtId = viewModel.activeMatches[tm.id]?.match.courtId else { return nil }
        return viewModel.courts.first { $0.id == courtId }?.name
    }

    private var rounds: [BracketRoundKey] {
        Array(Set(viewModel.tournamentMatches.map { BracketRoundKey(bracket: $0.bracket, round: $0.round) }))
            .sorted { bracketOrder($0.bracket, $0.round) < bracketOrder($1.bracket, $1.round) }
    }

    private func bracketOrder(_ bracket: String, _ round: Int) -> (Int, Int) {
        let bracketRank = ["winners": 0, "losers": 1, "final": 2][bracket] ?? 3
        return (bracketRank, round)
    }

    private func roundLabel(bracket: String, round: Int) -> String {
        switch bracket {
        case "final": return "Grand Final"
        case "losers": return "Losers Round \(round)"
        default: return "Round \(round)"
        }
    }

    private func isWinner(_ tm: TournamentMatch, team: String) -> Bool {
        guard let match = viewModel.activeMatches[tm.id]?.match,
              match.status == .confirmed,
              let a = match.scoreA, let b = match.scoreB
        else { return false }
        return team == "a" ? a > b : b > a
    }

    private func header(scale: CGFloat) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17 * scale, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 44 * scale, height: 44 * scale)
                    .background(Color(.systemGray5), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2 * scale) {
                Text(viewModel.game.name)
                    .font(.custom("DIN-BlackAlternate", size: 30 * scale))
                    .foregroundStyle(Color.primary)
                Text(viewModel.tournament?.eliminationType == "double" ? "Double elimination" : "Single elimination")
                    .font(.custom("DIN-Regular", size: 15 * scale))
                    .foregroundStyle(labelColor)
            }

            Spacer()

            // Balances the close button so the title stays centered.
            Color.clear.frame(width: 44 * scale, height: 44 * scale)
        }
        .padding(.horizontal, 32 * scale)
        .padding(.top, 20 * scale)
        .padding(.bottom, 12 * scale)
    }

    private func championBanner(_ name: String, scale: CGFloat) -> some View {
        VStack(spacing: 8 * scale) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 40 * scale))
                .foregroundStyle(.yellow)
            Text("Champion")
                .font(.custom("DIN-Regular", size: 15 * scale))
                .foregroundStyle(labelColor)
            Text(name)
                .font(.custom("DIN-BlackAlternate", size: 32 * scale))
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(28 * scale)
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 20 * scale))
    }

    private func liveMatchesSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            Text("Live now")
                .font(.custom("DIN-Medium", size: 20 * scale))
                .foregroundStyle(labelColor)
                .padding(.horizontal, 32 * scale)
                .padding(.top, 24 * scale)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 340 * scale, maximum: 560 * scale), spacing: 20 * scale)],
                spacing: 20 * scale
            ) {
                ForEach(liveMatches) { tm in
                    TournamentScoreboardMatchCard(
                        courtName: courtName(for: tm),
                        roundLabel: roundLabel(bracket: tm.bracket, round: tm.round),
                        teamAName: viewModel.name(for: tm.teamAPlayerIds),
                        teamBName: viewModel.name(for: tm.teamBPlayerIds),
                        match: viewModel.activeMatches[tm.id],
                        scale: scale
                    )
                }
            }
            .padding(.horizontal, 32 * scale)
        }
    }

    private func bracketSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 24 * scale) {
            Text("Bracket")
                .font(.custom("DIN-Medium", size: 20 * scale))
                .foregroundStyle(labelColor)
                .padding(.horizontal, 32 * scale)
                .padding(.top, 28 * scale)

            ForEach(rounds, id: \.self) { key in
                VStack(alignment: .leading, spacing: 10 * scale) {
                    Text(roundLabel(bracket: key.bracket, round: key.round))
                        .font(.custom("DIN-Medium", size: 17 * scale))
                        .foregroundStyle(labelColor)

                    ForEach(
                        viewModel.tournamentMatches
                            .filter { $0.bracket == key.bracket && $0.round == key.round }
                            .sorted { $0.slot < $1.slot }
                    ) { tm in
                        bracketMatchRow(tm, scale: scale)
                    }
                }
                .padding(.horizontal, 32 * scale)
            }
        }
    }

    private func bracketMatchRow(_ tm: TournamentMatch, scale: CGFloat) -> some View {
        let mwp = viewModel.activeMatches[tm.id]
        return HStack {
            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(viewModel.name(for: tm.teamAPlayerIds))
                    .font(.custom(isWinner(tm, team: "a") ? "DIN-Medium" : "DIN-Regular", size: 16 * scale))
                    .foregroundStyle(Color.primary)
                Text(viewModel.name(for: tm.teamBPlayerIds))
                    .font(.custom(isWinner(tm, team: "b") ? "DIN-Medium" : "DIN-Regular", size: 16 * scale))
                    .foregroundStyle(Color.primary)
            }
            Spacer()
            if let match = mwp?.match, let a = match.scoreA, let b = match.scoreB {
                Text("\(a) – \(b)")
                    .font(.custom("DIN-Medium", size: 16 * scale))
                    .foregroundStyle(Color.primary)
            } else if tm.isReadyToStart {
                Text("Ready")
                    .font(.custom("DIN-Regular", size: 14 * scale))
                    .foregroundStyle(labelColor)
            } else {
                Text("TBD")
                    .font(.custom("DIN-Regular", size: 14 * scale))
                    .foregroundStyle(labelColor)
            }
        }
        .padding(16 * scale)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14 * scale))
    }
}

private struct TournamentScoreboardMatchCard: View {
    let courtName: String?
    let roundLabel: String
    let teamAName: String
    let teamBName: String
    let match: MatchWithPlayers?
    let scale: CGFloat

    private let labelColor = Color.appSecondaryText

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            HStack {
                Text(courtName ?? roundLabel)
                    .font(.custom("DIN-Medium", size: 22 * scale))
                    .foregroundStyle(Color.primary)
                Spacer()
                if match?.match.status == .awaitingConfirmation {
                    Text("Needs confirmation")
                        .font(.custom("DIN-Medium", size: 13 * scale))
                        .foregroundStyle(.orange)
                }
            }
            if courtName != nil {
                Text(roundLabel)
                    .font(.custom("DIN-Regular", size: 13 * scale))
                    .foregroundStyle(labelColor)
            }

            VStack(spacing: 4 * scale) {
                Text(teamAName)
                    .font(.custom("DIN-Regular", size: 18 * scale))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 16 * scale) {
                    Text("\(match?.match.scoreA ?? 0)")
                    Text("–")
                        .foregroundStyle(labelColor)
                    Text("\(match?.match.scoreB ?? 0)")
                }
                .font(.custom("DIN-BlackAlternate", size: 64 * scale))
                .foregroundStyle(Color.primary)
                .contentTransition(.numericText())
                .animation(.default, value: match?.match.scoreA)
                .animation(.default, value: match?.match.scoreB)

                Text(teamBName)
                    .font(.custom("DIN-Regular", size: 18 * scale))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24 * scale)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 20 * scale))
    }
}

private let previewGame = Game(
    id: UUID(),
    name: "Summer Smash Open",
    location: "Community Center",
    startsAt: Date(),
    numCourts: 4,
    isDoubles: true,
    format: .tournamentSingleElim,
    formatSettings: [:],
    joinCode: "7K2P9Q",
    status: "active"
)

private func previewViewModel() -> BracketViewModel {
    let vm = BracketViewModel(game: previewGame)
    vm.tournament = Tournament(id: UUID(), gameId: previewGame.id, bracketSize: 4, eliminationType: "single", seedingMethod: "skill")

    let players = ["Alex Chen", "Sam Park", "Jamie Lee", "Drew Kim", "Morgan Reyes", "Casey Wu", "Riley Nguyen", "Taylor Brooks"]
        .map { name in (id: UUID(), name: name) }
    vm.playerNames = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.name) })

    let court = Court(id: UUID(), gameId: previewGame.id, name: "Court 1", position: 0, isLaneSplit: false, isChallengeCourt: false, winStreak: 0, singlesOverride: nil)
    vm.courts = [court]

    let semiA = TournamentMatch(
        id: UUID(), tournamentId: vm.tournament!.id, matchId: UUID(),
        bracket: "winners", round: 1, slot: 0, nextMatchId: nil,
        teamAPlayerIds: [players[0].id], teamBPlayerIds: [players[1].id],
        advancesToSlot: nil, loserNextMatchId: nil, loserAdvancesToSlot: nil
    )
    let semiB = TournamentMatch(
        id: UUID(), tournamentId: vm.tournament!.id, matchId: nil,
        bracket: "winners", round: 1, slot: 1, nextMatchId: nil,
        teamAPlayerIds: [players[2].id], teamBPlayerIds: [players[3].id],
        advancesToSlot: nil, loserNextMatchId: nil, loserAdvancesToSlot: nil
    )
    let final = TournamentMatch(
        id: UUID(), tournamentId: vm.tournament!.id, matchId: nil,
        bracket: "final", round: 1, slot: 0, nextMatchId: nil,
        teamAPlayerIds: nil, teamBPlayerIds: nil,
        advancesToSlot: nil, loserNextMatchId: nil, loserAdvancesToSlot: nil
    )
    vm.tournamentMatches = [semiA, semiB, final]

    vm.activeMatches = [
        semiA.id: MatchWithPlayers(
            match: Match(id: semiA.matchId!, gameId: previewGame.id, courtId: court.id, status: .inProgress, scoreA: 14, scoreB: 11, startedAt: Date(), endedAt: nil),
            teamA: [], teamB: []
        )
    ]

    return vm
}

#Preview("iPad Pro 13-inch", traits: .fixedLayout(width: 1366, height: 1024)) {
    TournamentScoreboardView(viewModel: previewViewModel())
}

#Preview("iPad Pro 11-inch", traits: .fixedLayout(width: 1194, height: 834)) {
    TournamentScoreboardView(viewModel: previewViewModel())
}

#Preview("iPad mini — Landscape", traits: .fixedLayout(width: 1133, height: 744)) {
    TournamentScoreboardView(viewModel: previewViewModel())
}

#Preview("iPad mini — Portrait", traits: .fixedLayout(width: 744, height: 1133)) {
    TournamentScoreboardView(viewModel: previewViewModel())
}

#Preview("iPhone — Portrait", traits: .fixedLayout(width: 430, height: 932)) {
    TournamentScoreboardView(viewModel: previewViewModel())
}

#Preview("iPhone — Landscape", traits: .fixedLayout(width: 932, height: 430)) {
    TournamentScoreboardView(viewModel: previewViewModel())
}
