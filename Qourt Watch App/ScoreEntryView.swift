//
//  ScoreEntryView.swift
//  Qourt Watch App
//
//  Two big tap targets and a Digital Crown fallback — usable mid-rally
//  with sweaty hands, which rules out small steppers.
//

import SwiftUI

struct ScoreEntryView: View {
    let title: String
    @State var scoreA: Int
    @State var scoreB: Int
    /// Fired on every tap so the score syncs live to the other devices.
    let onChange: (Int, Int) async -> Void
    /// Fired when the user commits the final score.
    let onSubmit: (Int, Int) async -> Void
    let submitLabel: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    sideControl(label: "Us", score: $scoreA)
                    Text("–")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    sideControl(label: "Them", score: $scoreB)
                }

                Button(submitLabel) {
                    Task {
                        await onSubmit(scoreA, scoreB)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func sideControl(label: String, score: Binding<Int>) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text("\(score.wrappedValue)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            HStack(spacing: 4) {
                stepButton(systemName: "minus", enabled: score.wrappedValue > 0) {
                    score.wrappedValue = max(0, score.wrappedValue - 1)
                    Task { await onChange(scoreA, scoreB) }
                }
                stepButton(systemName: "plus", enabled: true) {
                    score.wrappedValue += 1
                    Task { await onChange(scoreA, scoreB) }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 26)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
    }
}
