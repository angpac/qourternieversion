//
//  TournamentMatchDetailSheet.swift
//  Qourt
//

import SwiftUI

struct TournamentMatchDetailSheet: View {
    var viewModel: BracketViewModel
    let tournamentMatch: TournamentMatch

    @Environment(\.dismiss) private var dismiss
    @State private var scoreA = 0
    @State private var scoreB = 0

    private var match: MatchWithPlayers? { viewModel.activeMatches[tournamentMatch.id] }

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                scoreboardRow(
                    teamName: viewModel.name(for: tournamentMatch.teamAPlayerIds),
                    score: $scoreA
                )

                Text("vs")
                    .font(.custom("DIN-Regular", size: 13))
                    .foregroundStyle(labelColor)

                scoreboardRow(
                    teamName: viewModel.name(for: tournamentMatch.teamBPlayerIds),
                    score: $scoreB
                )

                Button {
                    Task {
                        await viewModel.endMatch(tournamentMatch, scoreA: scoreA, scoreB: scoreB)
                        dismiss()
                    }
                } label: {
                    Text("End match")
                        .font(.custom("DIN-Medium", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(scoreA == scoreB ? Color(.systemGray5) : accentColor, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(scoreA == scoreB)

                Spacer()
            }
            .padding()
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.custom("DIN-Regular", size: 17))
                    }
                }
            }
            .onAppear {
                scoreA = match?.match.scoreA ?? 0
                scoreB = match?.match.scoreB ?? 0
            }
            .onChange(of: scoreA) { _, newValue in
                if let matchID = match?.match.id {
                    Task { await viewModel.updateScore(matchID: matchID, scoreA: newValue, scoreB: scoreB) }
                }
            }
            .onChange(of: scoreB) { _, newValue in
                if let matchID = match?.match.id {
                    Task { await viewModel.updateScore(matchID: matchID, scoreA: scoreA, scoreB: newValue) }
                }
            }
        }
    }

    private func scoreboardRow(teamName: String, score: Binding<Int>) -> some View {
        VStack(spacing: 8) {
            Text(teamName)
                .font(.custom("DIN-Medium", size: 17))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                Button {
                    guard score.wrappedValue > 0 else { return }
                    score.wrappedValue -= 1
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                }

                Text("\(score.wrappedValue)")
                    .font(.custom("DIN-Regular", size: 48))
                    .foregroundStyle(Color.primary)
                    .frame(minWidth: 70)
                    .contentTransition(.numericText())
                    .animation(.default, value: score.wrappedValue)

                Button {
                    score.wrappedValue += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                }
            }
            .foregroundStyle(accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
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
        format: .tournamentSingleElim,
        formatSettings: [:],
        joinCode: "7K2P9Q",
        status: "active"
    )
    return TournamentMatchDetailSheet(
        viewModel: BracketViewModel(game: game),
        tournamentMatch: TournamentMatch(
            id: UUID(),
            tournamentId: UUID(),
            matchId: nil,
            bracket: "winners",
            round: 1,
            slot: 0,
            nextMatchId: nil,
            teamAPlayerIds: [UUID()],
            teamBPlayerIds: [UUID()],
            advancesToSlot: nil,
            loserNextMatchId: nil,
            loserAdvancesToSlot: nil
        )
    )
}
