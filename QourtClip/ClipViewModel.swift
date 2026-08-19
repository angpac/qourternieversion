//
//  ClipViewModel.swift
//  QourtClip
//
//  Drives the whole clip: resolve the code that invoked us, join, then
//  poll status the same way the web client does.
//

import Foundation
import Observation

@Observable
@MainActor
final class ClipViewModel {
    enum Phase {
        case joining
        case joined
    }

    var phase: Phase = .joining

    // Join screen
    var joinCode = ""
    /// True when the guest has to type the code themselves — a code that
    /// arrived in the invoking URL is already correct, so it's shown as a
    /// settled confirmation instead of another blank-looking field.
    var isEditingCode = true
    var name = ""
    var skillLevel = "Beginner"
    var preview: ClipGamePreview?
    var previewError: String?
    var isLoadingPreview = false
    var isJoining = false
    var joinError: String?

    // Status screen
    var status: ClipStatus?
    var announcements: [ClipAnnouncement] = []
    var statusError: String?

    static let skillLevels = ["Beginner", "Intermediate", "Advanced"]
    /// Same cadence as the web client.
    private static let pollInterval: Duration = .seconds(2)

    private var sessionToken: UUID? {
        didSet {
            guard let sessionToken else {
                UserDefaults.standard.removeObject(forKey: Self.tokenKey)
                return
            }
            UserDefaults.standard.set(sessionToken.uuidString, forKey: Self.tokenKey)
        }
    }
    private static let tokenKey = "qourt_session_token"
    private static let codeKey = "qourt_session_code"
    private var pollTask: Task<Void, Never>?

    /// The join code the stored session belongs to. Without this, a guest
    /// who scans a *different* game's QR while still holding a session
    /// would silently be shown their old game.
    private var joinedCode: String? {
        didSet {
            guard let joinedCode else {
                UserDefaults.standard.removeObject(forKey: Self.codeKey)
                return
            }
            UserDefaults.standard.set(joinedCode, forKey: Self.codeKey)
        }
    }

    init() {
        // An App Clip can be invoked more than once before the system
        // evicts it, so a guest who already joined comes straight back to
        // their place in line instead of joining twice under two names.
        if let stored = UserDefaults.standard.string(forKey: Self.tokenKey),
           let token = UUID(uuidString: stored) {
            sessionToken = token
            joinedCode = UserDefaults.standard.string(forKey: Self.codeKey)
            phase = .joined
        }
    }

    // MARK: - Invocation

    /// Pulls the join code out of the URL that launched the clip, e.g.
    /// https://qourt-web.vercel.app/join/AB12CD. Same parsing rule as the
    /// full app's `DeepLinkRouter`.
    func handle(url: URL) {
        let components = url.pathComponents
        guard let joinIndex = components.firstIndex(of: "join"),
              joinIndex + 1 < components.count else { return }
        let code = components[joinIndex + 1].uppercased()
        guard !code.isEmpty else { return }

        if phase == .joined {
            // Reopened from the same game's card - leave them where they
            // are rather than making them join twice.
            guard code != joinedCode else { return }
            // A genuinely different game was scanned. The old session is
            // no longer what they asked for, so drop it and start again.
            startOver()
        }

        joinCode = code
        isEditingCode = false
        Task { await loadPreview() }
    }

    // MARK: - Join

    func loadPreview() async {
        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        isLoadingPreview = true
        previewError = nil
        preview = nil
        defer { isLoadingPreview = false }

        do {
            let result = try await ClipAPI.rpc(
                "game_preview_by_code",
                body: ["p_join_code": code],
                as: ClipGamePreview.self
            )
            if result.status == "ended" {
                previewError = "This game has ended. The code no longer works."
                return
            }
            preview = result
        } catch {
            previewError = error.localizedDescription
        }
    }

    func join() async {
        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, !trimmedName.isEmpty else {
            joinError = "Enter a join code and your name."
            return
        }

        isJoining = true
        joinError = nil
        defer { isJoining = false }

        do {
            let result = try await ClipAPI.rpc(
                "guest_join_game",
                body: [
                    "p_join_code": code,
                    "p_display_name": trimmedName,
                    "p_skill_level": skillLevel
                ],
                as: ClipJoinResult.self
            )
            sessionToken = result.session_token
            joinedCode = code
            phase = .joined
        } catch {
            joinError = error.localizedDescription
        }
    }

    // MARK: - Status polling

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        guard let sessionToken else { return }
        do {
            status = try await ClipAPI.rpc(
                "guest_status",
                body: ["p_session_token": sessionToken.uuidString],
                as: ClipStatus.self
            )
            statusError = nil
        } catch {
            // A token that no longer resolves can't be retried out of -
            // polling would just fail forever behind stale data. Send them
            // back to the join form instead.
            if let apiError = error as? ClipAPI.APIError, apiError.isSessionGone {
                startOver()
                return
            }
            statusError = error.localizedDescription
            return
        }
        announcements = (try? await ClipAPI.rpc(
            "guest_announcements",
            body: ["p_session_token": sessionToken.uuidString],
            as: [ClipAnnouncement].self
        )) ?? []
    }

    // MARK: - Guest actions

    func stepOut() async { await act("guest_step_out") }
    func stepIn() async { await act("guest_step_in") }
    func leave() async { await act("guest_leave_game") }

    func reportScore(scoreA: Int, scoreB: Int) async {
        guard let sessionToken else { return }
        _ = try? await ClipAPI.rpc("guest_report_score", body: [
            "p_session_token": sessionToken.uuidString,
            "p_score_a": scoreA,
            "p_score_b": scoreB
        ])
        await refresh()
    }

    /// Peg Board only: the player at the front of the line builds their own
    /// match out of the pool behind them.
    func startPickerMatch(teammateIDs: [UUID]) async -> String? {
        guard let sessionToken, teammateIDs.count == 3 else { return nil }
        do {
            try await ClipAPI.rpc("guest_pick_board_start_match", body: [
                "p_session_token": sessionToken.uuidString,
                "p_teammate_ids": teammateIDs.map(\.uuidString)
            ])
            await refresh()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func act(_ function: String) async {
        guard let sessionToken else { return }
        _ = try? await ClipAPI.rpc(function, body: ["p_session_token": sessionToken.uuidString])
        await refresh()
    }

    /// Drops the stored session and returns to the join form — used when a
    /// session token no longer resolves (the game was deleted, or the clip
    /// was reused for a different game).
    func startOver() {
        stopPolling()
        sessionToken = nil
        joinedCode = nil
        status = nil
        announcements = []
        statusError = nil
        joinCode = ""
        isEditingCode = true
        name = ""
        preview = nil
        previewError = nil
        phase = .joining
    }
}
