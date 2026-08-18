//
//  GuestStatusView.swift
//  QourtAppClip
//
//  "Session Details (Player)" — polls guest_status every 2s (mirroring
//  web/app/status/page.tsx) and offers the same self-service actions the
//  web guest client has: step out/in of the queue and leave the game
//  (guest_step_out / guest_step_in / guest_leave_game). Self-reporting a
//  score and the Peg Board Picker UI stay on the web guest client and
//  full app for this first pass.
//

import SwiftUI

struct GuestStatusView: View {
    let session: GuestJoinResponse
    var onLeft: () -> Void

    @State private var status: GuestStatus?
    @State private var errorMessage: String?
    @State private var isConfirmingLeave = false
    @State private var isActing = false

    private let labelColor = Color(red: 0x4D / 255, green: 0x3E / 255, blue: 0x00 / 255)
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(session.gameName)
                    .font(.custom("DIN-BlackAlternate", size: 30))
                    .padding(.top, 24)

                if let status {
                    VStack(spacing: 2) {
                        Text(status.myDisplayName)
                            .font(.custom("DIN-Bold", size: 20))
                            .foregroundStyle(labelColor)
                        Text(status.mySkillLevel)
                            .font(.custom("DIN-Regular", size: 15))
                            .foregroundStyle(labelColor)
                    }
                    .frame(maxWidth: .infinity)

                    statusCard(status)

                    if status.playerStatus == .queued || status.playerStatus == .resting {
                        selfServiceButtons(status)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(.red)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Join Code")
                            .font(.custom("DIN-Regular", size: 15))
                            .foregroundStyle(labelColor)
                        Text(status.joinCode)
                            .font(.custom("DIN-Bold", size: 17))
                            .foregroundStyle(labelColor)
                    }
                } else if errorMessage == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .task { await pollLoop() }
        .confirmationDialog(
            "Leave this game?",
            isPresented: $isConfirmingLeave,
            titleVisibility: .visible
        ) {
            Button("Leave game", role: .destructive) {
                Task { await leave() }
            }
        }
    }

    @ViewBuilder
    private func statusCard(_ status: GuestStatus) -> some View {
        switch status.playerStatus {
        case .queued:
            VStack(spacing: 8) {
                Image(systemName: "figure.stand.line.dotted.figure.stand")
                    .font(.system(size: 40))
                    .foregroundStyle(labelColor)
                Text(status.queuePosition.map { "You're #\($0) in line" } ?? "You're in line")
                    .font(.custom("DIN-Bold", size: 22))
                    .foregroundStyle(labelColor)
                    .multilineTextAlignment(.center)
                Text(status.gameFormat.title)
                    .font(.custom("DIN-Regular", size: 15))
                    .foregroundStyle(labelColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))

        case .resting:
            VStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(labelColor)
                Text("Taking a break")
                    .font(.custom("DIN-Bold", size: 22))
                    .foregroundStyle(labelColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))

        case .onCourt:
            VStack(alignment: .leading, spacing: 12) {
                if let teamA = status.teamA, let teamB = status.teamB {
                    Text("\(teamA.map(\.displayName).joined(separator: " & ")) vs \(teamB.map(\.displayName).joined(separator: " & "))")
                        .font(.custom("DIN-Regular", size: 15))
                }
                if let scoreA = status.scoreA, let scoreB = status.scoreB {
                    Text("\(scoreA) – \(scoreB)")
                        .font(.custom("DIN-Bold", size: 40))
                }
                if status.matchStatus == .awaitingConfirmation {
                    Text("Score submitted, waiting on the admin to confirm")
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))

        default:
            EmptyView()
        }
    }

    private func selfServiceButtons(_ status: GuestStatus) -> some View {
        VStack(spacing: 12) {
            Button {
                Task { await toggleStepInOut(status) }
            } label: {
                Text(status.playerStatus == .resting ? "Step back in" : "Skip my turn")
                    .font(.custom("DIN-Medium", size: 16))
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .buttonStyle(.plain)
            .disabled(isActing)

            Button {
                isConfirmingLeave = true
            } label: {
                Text("Leave game")
                    .font(.custom("DIN-Medium", size: 16))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .buttonStyle(.plain)
            .disabled(isActing)
        }
    }

    @MainActor
    private func pollLoop() async {
        while !Task.isCancelled {
            await poll()
            try? await Task.sleep(for: .seconds(2))
        }
    }

    @MainActor
    private func poll() async {
        do {
            struct Params: Encodable { let p_session_token: UUID }
            status = try await supabase.rpc(
                "guest_status",
                params: Params(p_session_token: session.sessionToken)
            )
            .execute()
            .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func toggleStepInOut(_ status: GuestStatus) async {
        isActing = true
        defer { isActing = false }
        do {
            struct Params: Encodable { let p_session_token: UUID }
            let functionName = status.playerStatus == .resting ? "guest_step_in" : "guest_step_out"
            try await supabase.rpc(functionName, params: Params(p_session_token: session.sessionToken)).execute()
            await poll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func leave() async {
        isActing = true
        defer { isActing = false }
        do {
            struct Params: Encodable { let p_session_token: UUID }
            try await supabase.rpc("guest_leave_game", params: Params(p_session_token: session.sessionToken)).execute()
            onLeft()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    GuestStatusView(
        session: GuestJoinResponse(
            sessionToken: UUID(),
            gameName: "Wednesday Sesh",
            gameFormat: "manual",
            joinCode: "W5JUXA"
        ),
        onLeft: {}
    )
}
