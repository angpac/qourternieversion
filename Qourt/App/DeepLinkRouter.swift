//
//  DeepLinkRouter.swift
//  Qourt
//

import Foundation

/// Holds a join code received via Universal Link (a tapped share link or a
/// scanned QR code) until whichever screen owns the join flow is ready to
/// consume it — the link can arrive before sign-in completes, so this
/// outlives any single view.
@Observable
final class DeepLinkRouter {
    var pendingJoinCode: String?

    func handle(_ url: URL) {
        guard let code = Self.joinCode(from: url) else { return }
        pendingJoinCode = code
    }

    static func joinCode(from url: URL) -> String? {
        let components = url.pathComponents
        guard let joinIndex = components.firstIndex(of: "join"),
              joinIndex + 1 < components.count else { return nil }
        return components[joinIndex + 1].uppercased()
    }

    /// A scanned QR code is a full join URL; someone could also point the
    /// scanner at a card with just the bare code printed on it, so fall
    /// back to treating the whole string as the code itself.
    static func joinCode(fromScannedText text: String) -> String? {
        if let url = URL(string: text), let code = joinCode(from: url) {
            return code
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
