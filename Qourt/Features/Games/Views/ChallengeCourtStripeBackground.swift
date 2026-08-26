//
//  ChallengeCourtStripeBackground.swift
//  Qourt
//
//  The one visual flourish reserved for the Challenge Court format's
//  special court — a diagonal hazard-stripe pattern that reads as "this
//  one's different" at a glance across the Live Dashboard, the spectator
//  Scoreboard, and its own card in the format picker. Every other format
//  is told apart by its icon alone.
//

import SwiftUI

struct ChallengeCourtStripeBackground: View {
    var baseColor: Color
    var stripeColor: Color
    var spacing: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(baseColor))

            let stripeWidth = spacing / 2
            var path = Path()
            var x = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            context.stroke(path, with: .color(stripeColor), lineWidth: stripeWidth)
        }
    }
}
