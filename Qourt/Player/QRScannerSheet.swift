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
                            .stroke(.white, lineWidth: 3)
                            .frame(width: 220, height: 220)
                            .shadow(radius: 4)

                        VStack {
                            Spacer()
                            Text("Point your camera at the game's QR code")
                                .font(.footnote.bold())
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(.bottom, 40)
                        }
                    }
                case .notDetermined:
                    ProgressView().task { await requestAccess() }
                default:
                    ContentUnavailableView(
                        "Camera access needed",
                        systemImage: "camera.fill",
                        description: Text("Enable camera access for Qourt in Settings to scan a QR code, or enter the join code by hand instead.")
                    )
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

    private func requestAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = granted ? .authorized : .denied
    }
}
