//
//  PickerSheet.swift
//  Qourt
//

import SwiftUI

/// Peg Board: shown to whichever player is currently at the front of the
/// queue. They pick 3 teammates from the next players in line to build a
/// doubles match; all 4 (including the Picker) return to the back of the
/// queue once the match ends.
struct PickerSheet: View {
    var viewModel: PlayerLiveStatusViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selected: [GamePlayer] = []

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    private var teammatesNeeded: Int { viewModel.pickerTeammatesNeeded }
    private var isSingles: Bool { teammatesNeeded == 1 }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(isSingles
                         ? "You're the Picker! Choose your opponent for a singles match."
                         : "You're the Picker! Choose \(teammatesNeeded) players to build your doubles match.")
                        .font(.custom("DIN-Regular", size: 15))
                        .foregroundStyle(labelColor)
                }

                Section {
                    if selected.isEmpty {
                        Text("No teammates picked yet")
                            .font(.custom("DIN-Regular", size: 17))
                            .foregroundStyle(labelColor)
                    } else {
                        ForEach(selected) { player in
                            Button {
                                selected.removeAll { $0.id == player.id }
                            } label: {
                                HStack {
                                    Text(player.displayName)
                                        .font(.custom("DIN-Regular", size: 17))
                                        .foregroundStyle(Color.primary)
                                    Spacer()
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(labelColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Your match")
                        .font(.custom("DIN-Regular", size: 13))
                }

                Section {
                    ForEach(viewModel.pickerPool) { player in
                        Button {
                            toggle(player)
                        } label: {
                            HStack {
                                Text(player.displayName)
                                    .font(.custom("DIN-Regular", size: 17))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Text(player.skillLevel)
                                    .font(.custom("DIN-Regular", size: 13))
                                    .foregroundStyle(labelColor)
                                if selected.contains(where: { $0.id == player.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(accentColor)
                                }
                            }
                        }
                        .disabled(selected.count == teammatesNeeded && !selected.contains(where: { $0.id == player.id }))
                    }
                } header: {
                    Text("Next in line")
                        .font(.custom("DIN-Regular", size: 13))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("You're the Picker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.startPickerMatch(teammateIDs: selected.map(\.id))
                            if success { dismiss() }
                        }
                    } label: {
                        if viewModel.isStartingPickerMatch {
                            ProgressView()
                        } else {
                            Text("Start match")
                                .font(.custom("DIN-Medium", size: 15))
                        }
                    }
                    .tint(accentColor)
                    .disabled(selected.count != teammatesNeeded || viewModel.isStartingPickerMatch)
                }
            }
            .overlay(alignment: .bottom) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.red, in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                }
            }
        }
    }

    private func toggle(_ player: GamePlayer) {
        if let index = selected.firstIndex(where: { $0.id == player.id }) {
            selected.remove(at: index)
        } else if selected.count < teammatesNeeded {
            selected.append(player)
        }
    }
}

#Preview {
    PickerSheet(viewModel: PlayerLiveStatusViewModel(game: Game(
        id: UUID(),
        name: "Sunday Open Play",
        location: "Community Center",
        startsAt: Date(),
        numCourts: 4,
        isDoubles: true,
        format: .pegBoard,
        formatSettings: [:],
        joinCode: "7K2P9Q",
        status: "active"
    )))
}
