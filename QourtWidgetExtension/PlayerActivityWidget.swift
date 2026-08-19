//
//  PlayerActivityWidget.swift
//  QourtWidgetExtension
//

import ActivityKit
import SwiftUI
import WidgetKit

struct PlayerActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlayerActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(red: 0.02, green: 0.29, blue: 0.24))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: iconName(for: context.state))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    trailingText(context.state)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    bottomText(context.attributes, context.state)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: iconName(for: context.state))
            } compactTrailing: {
                trailingText(context.state)
                    .font(.caption.bold())
            } minimal: {
                Image(systemName: iconName(for: context.state))
            }
        }
    }

    private func iconName(for state: PlayerActivityAttributes.ContentState) -> String {
        state.status == "onCourt" ? "sportscourt.fill" : "figure.stand.line.dotted.figure.stand"
    }

    @ViewBuilder
    private func trailingText(_ state: PlayerActivityAttributes.ContentState) -> some View {
        if state.status == "onCourt", let a = state.scoreA, let b = state.scoreB {
            Text("\(a)–\(b)")
        } else if let position = state.queuePosition {
            Text("#\(position)")
        } else {
            EmptyView()
        }
    }

    private func bottomText(_ attributes: PlayerActivityAttributes, _ state: PlayerActivityAttributes.ContentState) -> Text {
        if state.status == "onCourt" {
            return Text(state.courtName ?? attributes.gameName)
        }
        return Text("In line for \(attributes.gameName)")
    }
}

private struct LockScreenView: View {
    let attributes: PlayerActivityAttributes
    let state: PlayerActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: state.status == "onCourt" ? "sportscourt.fill" : "figure.stand.line.dotted.figure.stand")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(attributes.gameName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                if state.status == "onCourt" {
                    Text(state.courtName ?? "On court")
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let teammates = state.teammateNames, let opponents = state.opponentNames {
                        Text("\(teammates) vs \(opponents)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                } else {
                    Text("You're #\(state.queuePosition ?? 0) in line")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            if state.status == "onCourt", let scoreA = state.scoreA, let scoreB = state.scoreB {
                Text("\(scoreA) – \(scoreB)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding()
    }
}

private let previewOnCourtState = PlayerActivityAttributes.ContentState(
    status: "onCourt",
    queuePosition: nil,
    courtName: "Court 2",
    teammateNames: "Alex Chen",
    opponentNames: "Jamie Lee & Sam Park",
    scoreA: 11,
    scoreB: 7
)

private let previewQueuedState = PlayerActivityAttributes.ContentState(
    status: "queued",
    queuePosition: 3,
    courtName: nil,
    teammateNames: nil,
    opponentNames: nil,
    scoreA: nil,
    scoreB: nil
)

#Preview("Notification", as: .content, using: PlayerActivityAttributes(gameName: "Sunday Open Play")) {
    PlayerActivityWidget()
} contentStates: {
    previewOnCourtState
    previewQueuedState
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: PlayerActivityAttributes(gameName: "Sunday Open Play")) {
    PlayerActivityWidget()
} contentStates: {
    previewOnCourtState
    previewQueuedState
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: PlayerActivityAttributes(gameName: "Sunday Open Play")) {
    PlayerActivityWidget()
} contentStates: {
    previewOnCourtState
    previewQueuedState
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: PlayerActivityAttributes(gameName: "Sunday Open Play")) {
    PlayerActivityWidget()
} contentStates: {
    previewOnCourtState
    previewQueuedState
}
