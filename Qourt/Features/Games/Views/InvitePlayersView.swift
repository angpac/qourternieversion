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

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Invite Players")
                    .font(.custom("DIN-Regular", size: 28))
                    .fontWeight(.bold)

                Spacer()

                Button("Done") { onFinished() }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(accentColor, in: Capsule())
                    .buttonStyle(.plain)
            }
            .padding()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text(game.name)
                            .font(.custom("DIN-Regular", size: 28))
                            .fontWeight(.bold)
                            .foregroundStyle(labelColor)
                        Text("Share this with the players to join")
                            .font(.subheadline)
                            .foregroundStyle(labelColor)
                    }
                    .padding(.top, 8)

                    if let qrImage = QRCodeGenerator.image(for: joinURL.absoluteString) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 220, height: 220)
                            .padding()
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 2)
                    }

                    VStack(spacing: 8) {
                        Text("Join code")
                            .font(.subheadline)
                            .foregroundStyle(labelColor)
                        Text(game.joinCode)
                            .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                            .tracking(4)
                            .foregroundStyle(labelColor)
                    }

                    ShareLink(item: joinURL) {
                        Label("Share invite link", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(accentColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 32)
                }
                .padding()
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
