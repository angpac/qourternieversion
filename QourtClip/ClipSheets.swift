//
//  ClipSheets.swift
//  QourtClip
//
//  The two modals from the web status page: reporting a score, and the
//  Peg Board Picker choosing three players.
//

import SwiftUI

struct ClipReportScoreSheet: View {
    let status: ClipStatus
    @Binding var scoreA: Int
    @Binding var scoreB: Int
    let onSubmit: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    scoreRow(
                        label: status.team_a?.map(\.display_name).joined(separator: " & ") ?? "Us",
                        score: $scoreA
                    )
                    scoreRow(
                        label: status.team_b?.map(\.display_name).joined(separator: " & ") ?? "Them",
                        score: $scoreB
                    )
                } footer: {
                    Text("The host confirms the final score before it counts.")
                }
            }
            .navigationTitle("Report score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await onSubmit()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func scoreRow(label: String, score: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 12)
            Stepper(value: score, in: 0...99) {
                Text("\(score.wrappedValue)")
                    .font(.title3.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .fixedSize()
        }
    }
}

struct ClipPickerSheet: View {
    let pool: [ClipPoolPlayer]
    @Binding var pickedIDs: [UUID]
    @Binding var errorMessage: String?
    /// Returns true when the match actually started, so the sheet only
    /// closes on success.
    let onStart: () async -> Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if pool.isEmpty {
                        Text("No one else is in line yet.")
                            .foregroundStyle(ClipTheme.zinc500)
                    }
                    ForEach(pool) { player in
                        row(player)
                    }
                } header: {
                    Text("Pick 3 players to join your match")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(ClipTheme.red600)
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
                    Button("Start (\(pickedIDs.count)/3)") {
                        Task { if await onStart() { dismiss() } }
                    }
                    .fontWeight(.semibold)
                    .disabled(pickedIDs.count != 3)
                }
            }
        }
    }

    private func row(_ player: ClipPoolPlayer) -> some View {
        let picked = pickedIDs.contains(player.id)
        // Full at 3 — the remaining rows go dim rather than silently
        // doing nothing when tapped.
        let disabled = !picked && pickedIDs.count >= 3

        return Button {
            if picked {
                pickedIDs.removeAll { $0 == player.id }
            } else if pickedIDs.count < 3 {
                pickedIDs.append(player.id)
            }
        } label: {
            HStack {
                Text(player.display_name)
                    .foregroundStyle(picked ? ClipTheme.emerald800 : ClipTheme.zinc700)
                    .fontWeight(picked ? .semibold : .regular)
                Spacer()
                Text(player.skill_level)
                    .font(.caption)
                    .foregroundStyle(ClipTheme.zinc400)
                if picked {
                    Image(systemName: "checkmark")
                        .foregroundStyle(ClipTheme.emerald700)
                }
            }
        }
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .listRowBackground(picked ? ClipTheme.emerald50 : Color(.systemBackground))
    }
}
