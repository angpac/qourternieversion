//
//  JoinQueueView.swift
//  QourtAppClip
//
//  The App Clip's one job: get an iPhone user who doesn't have the full
//  app into the queue in as few taps as possible. Mirrors
//  web/components/JoinForm.tsx (same game_preview_by_code /
//  guest_join_game RPCs, same no-account guest flow) but native.
//

import SwiftUI

struct JoinQueueView: View {
    let initialJoinCode: String
    var onJoined: (GuestJoinResponse) -> Void

    @State private var joinCode: String
    @State private var name = ""
    @State private var skillLevel = "Beginner"
    @State private var preview: GamePreview?
    @State private var previewError: String?
    @State private var isLoadingPreview = false
    @State private var isJoining = false
    @State private var errorMessage: String?

    private let skillLevels = ["Beginner", "Intermediate", "Advanced"]
    private let labelColor = Color(red: 0x4D / 255, green: 0x3E / 255, blue: 0x00 / 255)
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    init(initialJoinCode: String, onJoined: @escaping (GuestJoinResponse) -> Void) {
        self.initialJoinCode = initialJoinCode
        self.onJoined = onJoined
        _joinCode = State(initialValue: initialJoinCode)
    }

    private var isNameEmpty: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Qourt")
                        .font(.custom("DIN-BlackAlternate", size: 34))
                    Text("Join the queue")
                        .font(.custom("DIN-Regular", size: 17))
                        .foregroundStyle(labelColor)
                }
                .padding(.top, 24)

                if let preview {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Joining")
                            .font(.custom("DIN-Regular", size: 13))
                            .foregroundStyle(.secondary)
                        Text(preview.name)
                            .font(.custom("DIN-Bold", size: 20))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                } else if isLoadingPreview {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let previewError {
                    Text(previewError)
                        .font(.custom("DIN-Regular", size: 15))
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your name")
                        .font(.custom("DIN-Regular", size: 15))
                        .foregroundStyle(labelColor)
                    TextField("Name", text: $name)
                        .font(.custom("DIN-Regular", size: 17))
                        .textInputAutocapitalization(.words)
                        .padding()
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Skill level")
                        .font(.custom("DIN-Regular", size: 15))
                        .foregroundStyle(labelColor)
                    Picker("Skill level", selection: $skillLevel) {
                        ForEach(skillLevels, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.custom("DIN-Regular", size: 13))
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await join() }
                } label: {
                    if isJoining {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Join queue")
                            .font(.custom("DIN-Medium", size: 17))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(canJoin ? accentColor : Color(.systemGray4), in: Capsule())
                .buttonStyle(.plain)
                .disabled(!canJoin || isJoining)
            }
            .padding()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .task { await loadPreview() }
    }

    private var canJoin: Bool {
        !isNameEmpty && !joinCode.trimmingCharacters(in: .whitespaces).isEmpty && previewError == nil
    }

    @MainActor
    private func loadPreview() async {
        let code = joinCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        isLoadingPreview = true
        defer { isLoadingPreview = false }
        do {
            struct Params: Encodable { let p_join_code: String }
            let result: GamePreview = try await supabase.rpc(
                "game_preview_by_code",
                params: Params(p_join_code: code)
            )
            .execute()
            .value
            if result.status == "ended" {
                previewError = "This game has ended. The code no longer works."
            } else {
                preview = result
            }
        } catch {
            previewError = error.localizedDescription
        }
    }

    @MainActor
    private func join() async {
        errorMessage = nil
        isJoining = true
        defer { isJoining = false }
        do {
            struct Params: Encodable {
                let p_join_code: String
                let p_display_name: String
                let p_skill_level: String
            }
            let response: GuestJoinResponse = try await supabase.rpc(
                "guest_join_game",
                params: Params(
                    p_join_code: joinCode.trimmingCharacters(in: .whitespaces),
                    p_display_name: name.trimmingCharacters(in: .whitespaces),
                    p_skill_level: skillLevel
                )
            )
            .execute()
            .value
            onJoined(response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    JoinQueueView(initialJoinCode: "7K2P9Q", onJoined: { _ in })
}
