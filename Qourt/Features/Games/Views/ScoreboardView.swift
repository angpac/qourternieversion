//
//  ScoreboardView.swift
//  Qourt
//
//  A read-mostly, big-screen view of a live game meant for a second device
//  (an iPad propped up courtside) rather than the admin's own hands. Reuses
//  the same LiveDashboardViewModel the admin's Live Dashboard already
//  subscribes with, so no extra Realtime connection is opened — scores
//  update here the instant any player's Watch (or the admin's phone) writes
//  a new score to `matches`, the same way they already do everywhere else.
//
//  Every size here is driven by GeometryReader rather than a fixed iPad
//  model breakpoint, so it scales smoothly across the whole iPad lineup —
//  an 8.3" mini and a 13" Pro both read comfortably from across a court,
//  and rotating the device just reflows the grid instead of needing a
//  separate layout.
//

import SwiftUI

struct ScoreboardView: View {
    var viewModel: LiveDashboardViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var focusedCourt: Court?

    private let labelColor = Color.appSecondaryText

    var body: some View {
        GeometryReader { geo in
            let scale = scoreboardScale(for: geo.size)

            VStack(alignment: .leading, spacing: 0) {
                header(scale: scale)

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 340 * scale, maximum: 560 * scale), spacing: 20 * scale)],
                        spacing: 20 * scale
                    ) {
                        ForEach(viewModel.courts) { court in
                            Button {
                                focusedCourt = court
                            } label: {
                                ScoreboardCourtCard(court: court, match: viewModel.activeMatches[court.id], scale: scale)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 32 * scale)
                    .padding(.top, 8 * scale)

                    if !viewModel.queue.isEmpty {
                        queueSection(scale: scale)
                    }

                    Spacer(minLength: 24 * scale)
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .fullScreenCover(item: $focusedCourt) { court in
            MatchScoreboardView(viewModel: viewModel, court: court)
        }
    }

    /// A ratio of the shorter device dimension against the 11" iPad
    /// Pro/Air's own shorter side (834pt), clamped so text never shrinks
    /// past legible on a mini or balloons past comfortable on a 13" Pro.
    /// Using the shorter side (not width) keeps the scale identical in
    /// portrait and landscape on the same physical device.
    private func scoreboardScale(for size: CGSize) -> CGFloat {
        let shorterSide = min(size.width, size.height)
        let referenceShortSide: CGFloat = 834
        return min(max(shorterSide / referenceShortSide, 0.8), 1.35)
    }

    private func header(scale: CGFloat) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    // systemGray5 darkens in dark mode, so a fixed
                    // black glyph would disappear into it.
                    .foregroundStyle(Color.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemGray5), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2 * scale) {
                Text(viewModel.game.name)
                    .font(.custom("DIN-BlackAlternate", size: 30 * scale))
                    .foregroundStyle(Color.primary)
                Text(viewModel.game.format.title)
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

    private func queueSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            Text("Queue (\(viewModel.queue.count) waiting)")
                .font(.custom("DIN-Medium", size: 20 * scale))
                .foregroundStyle(labelColor)
                .padding(.horizontal, 32 * scale)
                .padding(.top, 28 * scale)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20 * scale) {
                    ForEach(Array(viewModel.queue.enumerated()), id: \.element.id) { index, player in
                        VStack(spacing: 6 * scale) {
                            Text("\(index + 1)")
                                .font(.custom("DIN-Medium", size: 22 * scale))
                                .foregroundStyle(Color.appOnInverseSurface)
                                .frame(width: 56 * scale, height: 56 * scale)
                                .background(Color.appInverseSurface, in: Circle())
                            Text(player.displayName)
                                .font(.custom("DIN-Regular", size: 15 * scale))
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                                .frame(width: 88 * scale)
                        }
                    }
                }
                .padding(.horizontal, 32 * scale)
            }
        }
    }
}

private struct ScoreboardCourtCard: View {
    let court: Court
    let match: MatchWithPlayers?
    let scale: CGFloat

    private let labelColor = Color.appSecondaryText
    private let goldColor = Color(red: 0xB8 / 255, green: 0x8A / 255, blue: 0x2B / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            HStack {
                Text(court.name)
                    .font(.custom("DIN-Medium", size: 22 * scale))
                    .foregroundStyle(Color.primary)
                if court.isChallengeCourt {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 18 * scale))
                        .foregroundStyle(goldColor)
                }
                Spacer()
                if let match, match.match.status == .awaitingConfirmation {
                    Text("Needs confirmation")
                        .font(.custom("DIN-Medium", size: 13 * scale))
                        .foregroundStyle(.orange)
                }
            }

            if let match, !(match.teamA.isEmpty && match.teamB.isEmpty) {
                VStack(spacing: 4 * scale) {
                    Text(match.teamA.map(\.displayName).joined(separator: " & "))
                        .font(.custom("DIN-Regular", size: 18 * scale))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(spacing: 16 * scale) {
                        Text("\(match.match.scoreA ?? 0)")
                        Text("–")
                            .foregroundStyle(labelColor)
                        Text("\(match.match.scoreB ?? 0)")
                    }
                    .font(.custom("DIN-BlackAlternate", size: 64 * scale))
                    .foregroundStyle(Color.primary)
                    .contentTransition(.numericText())
                    .animation(.default, value: match.match.scoreA)
                    .animation(.default, value: match.match.scoreB)

                    Text(match.teamB.map(\.displayName).joined(separator: " & "))
                        .font(.custom("DIN-Regular", size: 18 * scale))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8 * scale) {
                    Image(systemName: "sportscourt")
                        .font(.system(size: 40 * scale))
                        .foregroundStyle(labelColor)
                    Text("Open court")
                        .font(.custom("DIN-Regular", size: 17 * scale))
                        .foregroundStyle(labelColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24 * scale)
            }
        }
        .padding(24 * scale)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 20 * scale))
        .overlay {
            if court.isChallengeCourt {
                RoundedRectangle(cornerRadius: 20 * scale)
                    .stroke(goldColor, lineWidth: 2)
            }
        }
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

private func previewViewModel() -> LiveDashboardViewModel {
    let vm = LiveDashboardViewModel(game: previewGame)
    let courts = [
        Court(id: UUID(), gameId: previewGame.id, name: "King's Court", position: 3, isLaneSplit: false, isChallengeCourt: true, winStreak: 2, singlesOverride: nil),
        Court(id: UUID(), gameId: previewGame.id, name: "Court 2", position: 2, isLaneSplit: false, isChallengeCourt: false, winStreak: 0, singlesOverride: nil),
        Court(id: UUID(), gameId: previewGame.id, name: "Court 3", position: 1, isLaneSplit: false, isChallengeCourt: false, winStreak: 0, singlesOverride: nil),
        Court(id: UUID(), gameId: previewGame.id, name: "Court 4", position: 0, isLaneSplit: false, isChallengeCourt: false, winStreak: 0, singlesOverride: nil)
    ]
    vm.courts = courts

    func player(_ name: String, skill: String) -> GamePlayer {
        GamePlayer(id: UUID(), gameId: previewGame.id, profileId: nil, displayName: name, skillLevel: skill, status: .onCourt, queuePosition: nil, joinedAt: Date())
    }

    vm.activeMatches = [
        courts[0].id: MatchWithPlayers(
            match: Match(id: UUID(), gameId: previewGame.id, courtId: courts[0].id, status: .inProgress, scoreA: 11, scoreB: 7, startedAt: Date(), endedAt: nil),
            teamA: [player("Alex Chen", skill: "Advanced"), player("Sam Park", skill: "Advanced")],
            teamB: [player("Jamie Lee", skill: "Intermediate"), player("Drew Kim", skill: "Intermediate")]
        ),
        courts[1].id: MatchWithPlayers(
            match: Match(id: UUID(), gameId: previewGame.id, courtId: courts[1].id, status: .awaitingConfirmation, scoreA: 21, scoreB: 18, startedAt: Date(), endedAt: nil),
            teamA: [player("Morgan Reyes", skill: "Beginner")],
            teamB: [player("Casey Wu", skill: "Beginner")]
        )
    ]

    vm.queue = [
        player("Riley Nguyen", skill: "Intermediate"),
        player("Taylor Brooks", skill: "Advanced"),
        player("Jordan Diaz", skill: "Beginner"),
        player("Avery Scott", skill: "Intermediate"),
        player("Quinn Foster", skill: "Advanced")
    ]

    return vm
}

#Preview("iPad Pro 13-inch", traits: .fixedLayout(width: 1366, height: 1024)) {
    ScoreboardView(viewModel: previewViewModel())
}

#Preview("iPad Pro 11-inch", traits: .fixedLayout(width: 1194, height: 834)) {
    ScoreboardView(viewModel: previewViewModel())
}

#Preview("iPad Air", traits: .fixedLayout(width: 1180, height: 820)) {
    ScoreboardView(viewModel: previewViewModel())
}

#Preview("iPad mini — Landscape", traits: .fixedLayout(width: 1133, height: 744)) {
    ScoreboardView(viewModel: previewViewModel())
}

#Preview("iPad mini — Portrait", traits: .fixedLayout(width: 744, height: 1133)) {
    ScoreboardView(viewModel: previewViewModel())
}

#Preview("iPhone — Portrait", traits: .fixedLayout(width: 430, height: 932)) {
    ScoreboardView(viewModel: previewViewModel())
}

#Preview("iPhone — Landscape", traits: .fixedLayout(width: 932, height: 430)) {
    ScoreboardView(viewModel: previewViewModel())
}
