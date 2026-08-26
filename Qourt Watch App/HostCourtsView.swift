//
//  HostCourtsView.swift
//  Qourt Watch App
//

import SwiftUI

struct HostCourtsView: View {
    @Bindable var viewModel: WatchHostViewModel
    let game: WatchGame
    @State private var editing: WatchCourtMatch?

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else {
                courtsList
            }
        }
        .navigationTitle(game.name)
        .task { await viewModel.start(gameID: game.id) }
        .onDisappear { Task { await viewModel.unsubscribe() } }
        .sheet(item: $editing) { court in
            if let matchID = court.matchID {
                ScoreEntryView(
                    title: court.courtName,
                    scoreA: court.scoreA,
                    scoreB: court.scoreB,
                    onChange: { a, b in
                        await viewModel.updateScore(matchID: matchID, scoreA: a, scoreB: b)
                    },
                    onSubmit: { a, b in
                        await viewModel.reportFinalScore(matchID: matchID, scoreA: a, scoreB: b)
                    },
                    submitLabel: "Report final"
                )
            }
        }
    }

    private var courtsList: some View {
        List {
            if viewModel.courts.isEmpty {
                Text("No courts yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.courts) { court in
                Button {
                    guard court.hasLiveMatch else { return }
                    editing = court
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(court.courtName)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                            // Status never rides on colour alone, per the
                            // design brief — there's always a word here.
                            Text(court.hasLiveMatch
                                 ? (court.status == .awaitingConfirmation ? "Reported" : "Live")
                                 : "Open")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if court.hasLiveMatch {
                            Text("\(court.scoreA)–\(court.scoreB)")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        } else {
                            Image(systemName: "sportscourt")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!court.hasLiveMatch)
            }
        }
    }
}
