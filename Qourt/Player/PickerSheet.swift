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

    private let teammatesNeeded = 3

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("You're the Picker! Choose \(teammatesNeeded) players to build your doubles match.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Your match") {
                    if selected.isEmpty {
                        Text("No teammates picked yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selected) { player in
                            Button {
                                selected.removeAll { $0.id == player.id }
                            } label: {
                                HStack {
                                    Text(player.displayName).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Next in line") {
                    ForEach(viewModel.pickerPool) { player in
                        Button {
                            toggle(player)
                        } label: {
                            HStack {
                                Text(player.displayName).foregroundStyle(.primary)
                                Spacer()
                                Text(player.skillLevel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if selected.contains(where: { $0.id == player.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .disabled(selected.count == teammatesNeeded && !selected.contains(where: { $0.id == player.id }))
                    }
                }
            }
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
                        }
                    }
                    .disabled(selected.count != teammatesNeeded || viewModel.isStartingPickerMatch)
                }
            }
            .overlay(alignment: .bottom) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
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
