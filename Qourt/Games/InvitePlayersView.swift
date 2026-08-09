//
//  InvitePlayersView.swift
//  Qourt
//

import CoreImage.CIFilterBuiltins
import SwiftUI

struct InvitePlayersView: View {
    let game: Game
    var onFinished: () -> Void

    private var joinURL: URL {
        URL(string: "https://qourt-web.vercel.app/join/\(game.joinCode)")!
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(game.name)
                        .font(.title2.bold())
                    Text("Share this with players to join")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                if let qrImage = QRCodeGenerator.image(for: joinURL.absoluteString) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 220, height: 220)
                        .padding()
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 2)
                }

                VStack(spacing: 8) {
                    Text("Join code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(game.joinCode)
                        .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                        .tracking(4)
                }

                ShareLink(item: joinURL) {
                    Label("Share invite link", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)

                Button("Done", action: onFinished)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Invite players")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

enum QRCodeGenerator {
    static func image(for string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    NavigationStack {
        InvitePlayersView(
            game: Game(
                id: UUID(),
                name: "Sunday Open Play",
                location: "Community Center",
                startsAt: Date(),
                numCourts: 4,
                isDoubles: true,
                format: .kingOfTheCourt,
                formatSettings: [:],
                joinCode: "7K2P9Q",
                status: "draft"
            ),
            onFinished: {}
        )
    }
}
