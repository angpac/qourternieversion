//
//  QRScannerSheet.swift
//  Qourt
//

import AVFoundation
import SwiftUI

struct QRScannerSheet: View {
    var onScannedCode: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    var body: some View {
        NavigationStack {
            Group {
                switch authorizationStatus {
                case .authorized:
                    ZStack {
                        QRScannerView { value in
                            guard let code = DeepLinkRouter.joinCode(fromScannedText: value) else { return }
                            onScannedCode(code)
                            dismiss()
                        }
                        .ignoresSafeArea()

                        RoundedRectangle(cornerRadius: 16)
                            .stroke(accentColor, lineWidth: 3)
                            .frame(width: 220, height: 220)
                            .shadow(radius: 4)

                        VStack {
                            Spacer()
                            Text("Point your camera at the game's QR code")
                                .font(.custom("DIN-Medium", size: 13))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(.bottom, 40)
                        }
                    }
                case .notDetermined:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.appBackground.ignoresSafeArea())
                        .task { await requestAccess() }
                default:
                    cameraAccessNeeded
                }
            }
            .navigationTitle("Scan QR code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var cameraAccessNeeded: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.primary)

            Text("Camera access needed")
                .font(.custom("DIN-BlackAlternate", size: 28))

            Text("Enable camera access for Qourt in Settings to scan a QR code, or enter the join code by hand instead.")
                .font(.custom("DIN-Regular", size: 15))
                .foregroundStyle(labelColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func requestAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = granted ? .authorized : .denied
    }
}

#Preview {
    QRScannerSheet(onScannedCode: { _ in })
}
