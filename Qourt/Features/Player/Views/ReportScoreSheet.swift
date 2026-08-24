//
//  ReportScoreSheet.swift
//  Qourt
//

import SwiftUI

struct ReportScoreSheet: View {
    var viewModel: PlayerLiveStatusViewModel
    let matchWithPlayers: MatchWithPlayers

    @Environment(\.dismiss) private var dismiss
    @State private var scoreA: Int
    @State private var scoreB: Int
    @State private var isSaving = false

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    init(viewModel: PlayerLiveStatusViewModel, matchWithPlayers: MatchWithPlayers) {
        self.viewModel = viewModel
        self.matchWithPlayers = matchWithPlayers
        _scoreA = State(initialValue: matchWithPlayers.match.scoreA ?? 0)
        _scoreB = State(initialValue: matchWithPlayers.match.scoreB ?? 0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    // Centered independently of the HStack below — the X
                    // button and Submit aren't the same width, so two
                    // Spacers either side of the title would center it
                    // between them instead of on the row itself.
                    Text("Report score")
                        .font(.custom("DIN-Medium", size: 17))
                        .foregroundStyle(Color.primary)

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

                        Button {
                            Task {
                                isSaving = true
                                await viewModel.reportScore(scoreA: scoreA, scoreB: scoreB)
                                isSaving = false
                                dismiss()
                            }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Submit")
                                    .font(.custom("DIN-Regular", size: 18))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(accentColor, in: Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                }
                .padding()

                Form {
                    Section {
                        Stepper("Score: \(scoreA)", value: $scoreA, in: 0...99)
                            .font(.custom("DIN-Regular", size: 17))
                    } header: {
                        Text(matchWithPlayers.teamA.map(\.displayName).joined(separator: " & "))
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(labelColor)
                    }
                    Section {
                        Stepper("Score: \(scoreB)", value: $scoreB, in: 0...99)
                            .font(.custom("DIN-Regular", size: 17))
                    } header: {
                        Text(matchWithPlayers.teamB.map(\.displayName).joined(separator: " & "))
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(labelColor)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    let game = Game(
        id: UUID(),
        name: "Sunday Open Play",
        location: "Community Center",
        startsAt: Date(),
        numCourts: 4,
        isDoubles: true,
        format: .kingOfTheCourt,
        formatSettings: [:],
        joinCode: "7K2P9Q",
        status: "active"
    )
    let playerA = GamePlayer(id: UUID(), gameId: game.id, profileId: nil, displayName: "Alex Chen", skillLevel: "Intermediate", status: .onCourt, queuePosition: nil, joinedAt: Date())
    let playerB = GamePlayer(id: UUID(), gameId: game.id, profileId: nil, displayName: "Jamie Lee", skillLevel: "Advanced", status: .onCourt, queuePosition: nil, joinedAt: Date())
    let match = Match(id: UUID(), gameId: game.id, courtId: UUID(), status: .inProgress, scoreA: 5, scoreB: 3, startedAt: Date(), endedAt: nil)
    return ReportScoreSheet(
        viewModel: PlayerLiveStatusViewModel(game: game),
        matchWithPlayers: MatchWithPlayers(match: match, teamA: [playerA], teamB: [playerB])
    )
}
