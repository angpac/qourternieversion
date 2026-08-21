//
//  MatchScoreboardView.swift
//  Qourt
//
//  A single-match, spectator-facing scoreboard — huge score, no controls.
//  Meant to run on a device propped up for the audience to watch while the
//  admin or a co-admin enters the score from their own phone elsewhere.
//  Reuses the same LiveDashboardViewModel/Realtime subscription as the Live
//  Dashboard and the multi-court Scoreboard, so a score entered anywhere
//  (including from a player's Watch) appears here within the same
//  broadcast — no polling, no separate connection.
//
//  Works on iPhone as much as iPad: side-by-side panels on a wide screen,
//  stacked top/bottom on a narrow one, decided per-frame from the actual
//  available size rather than an idiom check, so rotating the device (or
//  just running on a phone instead of a tablet) reflows automatically.
//

import SwiftUI

struct MatchScoreboardView: View {
    var viewModel: LiveDashboardViewModel
    let court: Court

    @Environment(\.dismiss) private var dismiss

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    private var match: MatchWithPlayers? { viewModel.activeMatches[court.id] }

    var body: some View {
        GeometryReader { geo in
            let scale = matchScale(for: geo.size)
            let isWide = geo.size.width > geo.size.height

            VStack(spacing: 0) {
                header(scale: scale)

                if let match, !(match.teamA.isEmpty && match.teamB.isEmpty) {
                    let scoreA = match.match.scoreA ?? 0
                    let scoreB = match.match.scoreB ?? 0
                    Group {
                        if isWide {
                            HStack(spacing: 0) {
                                teamPanel(
                                    name: match.teamA.map(\.displayName).joined(separator: " & "),
                                    score: scoreA,
                                    isLeading: scoreA > scoreB,
                                    scale: scale
                                )
                                Rectangle().fill(accentColor).frame(width: 3 * scale)
                                teamPanel(
                                    name: match.teamB.map(\.displayName).joined(separator: " & "),
                                    score: scoreB,
                                    isLeading: scoreB > scoreA,
                                    scale: scale
                                )
                            }
                        } else {
                            VStack(spacing: 0) {
                                teamPanel(
                                    name: match.teamA.map(\.displayName).joined(separator: " & "),
                                    score: scoreA,
                                    isLeading: scoreA > scoreB,
                                    scale: scale
                                )
                                Rectangle().fill(accentColor).frame(height: 3 * scale)
                                teamPanel(
                                    name: match.teamB.map(\.displayName).joined(separator: " & "),
                                    score: scoreB,
                                    isLeading: scoreB > scoreA,
                                    scale: scale
                                )
                            }
                        }
                    }
                } else {
                    emptyState(scale: scale)
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    /// Same shorter-side ratio as ScoreboardView/TournamentScoreboardView,
    /// so switching between the grid and a single-match focus doesn't
    /// visibly jump in scale.
    private func matchScale(for size: CGSize) -> CGFloat {
        let shorterSide = min(size.width, size.height)
        let referenceShortSide: CGFloat = 834
        return min(max(shorterSide / referenceShortSide, 0.8), 1.6)
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
                Text(court.name)
                    .font(.custom("DIN-Medium", size: 22 * scale))
                    .foregroundStyle(Color.primary)
                if match?.match.status == .awaitingConfirmation {
                    Text("Needs confirmation")
                        .font(.custom("DIN-Medium", size: 13 * scale))
                        .foregroundStyle(.orange)
                } else {
                    Text(viewModel.game.name)
                        .font(.custom("DIN-Regular", size: 13 * scale))
                        .foregroundStyle(labelColor)
                }
            }

            Spacer()

            Color.clear.frame(width: 44 * scale, height: 44 * scale)
        }
        .padding(.horizontal, 24 * scale)
        .padding(.top, 16 * scale)
        .padding(.bottom, 8 * scale)
    }

    private func teamPanel(name: String, score: Int, isLeading: Bool, scale: CGFloat) -> some View {
        VStack(spacing: 12 * scale) {
            Text(name)
                .font(.custom("DIN-Medium", size: 24 * scale))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 20 * scale)

            Spacer()

            Text("\(score)")
                .font(.custom("DIN-BlackAlternate", size: 220 * scale))
                .foregroundStyle(isLeading ? accentColor : Color.primary)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.default, value: score)

            Spacer()
        }
        .padding(.vertical, 24 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appSurface)
    }

    private func emptyState(scale: CGFloat) -> some View {
        VStack(spacing: 16 * scale) {
            Spacer()
            Image(systemName: "sportscourt")
                .font(.system(size: 60 * scale))
                .foregroundStyle(labelColor)
            Text("No match on this court right now")
                .font(.custom("DIN-Medium", size: 20 * scale))
                .foregroundStyle(Color.primary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private let previewGame = Game(
    id: UUID(),
    name: "Sunday Open Play",
    location: "Community Center",
    startsAt: Date(),
    numCourts: 4,
    isDoubles: true,
    format: .kingOfTheCourt,
    formatSettings: [:],
    joinCode: "7K2P9Q",
    status: "live"
)

private func previewViewModel() -> (LiveDashboardViewModel, Court) {
    let vm = LiveDashboardViewModel(game: previewGame)
    let court = Court(id: UUID(), gameId: previewGame.id, name: "Court 2", position: 0, isLaneSplit: false, isChallengeCourt: false, winStreak: 0, singlesOverride: nil)
    vm.courts = [court]

    func player(_ name: String) -> GamePlayer {
        GamePlayer(id: UUID(), gameId: previewGame.id, profileId: nil, displayName: name, skillLevel: "Advanced", status: .onCourt, queuePosition: nil, joinedAt: Date())
    }

    vm.activeMatches = [
        court.id: MatchWithPlayers(
            match: Match(id: UUID(), gameId: previewGame.id, courtId: court.id, status: .inProgress, scoreA: 20, scoreB: 17, startedAt: Date(), endedAt: nil),
            teamA: [player("Steve")],
            teamB: [player("Jay")]
        )
    ]

    return (vm, court)
}

#Preview("iPad 11\" — Landscape", traits: .fixedLayout(width: 1194, height: 834)) {
    let (vm, court) = previewViewModel()
    MatchScoreboardView(viewModel: vm, court: court)
}

#Preview("iPad 11\" — Portrait", traits: .fixedLayout(width: 834, height: 1194)) {
    let (vm, court) = previewViewModel()
    MatchScoreboardView(viewModel: vm, court: court)
}

#Preview("iPad mini — Landscape", traits: .fixedLayout(width: 1133, height: 744)) {
    let (vm, court) = previewViewModel()
    MatchScoreboardView(viewModel: vm, court: court)
}

#Preview("iPad mini — Portrait", traits: .fixedLayout(width: 744, height: 1133)) {
    let (vm, court) = previewViewModel()
    MatchScoreboardView(viewModel: vm, court: court)
}

#Preview("iPhone — Landscape", traits: .fixedLayout(width: 932, height: 430)) {
    let (vm, court) = previewViewModel()
    MatchScoreboardView(viewModel: vm, court: court)
}

#Preview("iPhone — Portrait", traits: .fixedLayout(width: 430, height: 932)) {
    let (vm, court) = previewViewModel()
    MatchScoreboardView(viewModel: vm, court: court)
}
