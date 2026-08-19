//
//  SendAnnouncementSheet.swift
//  Qourt
//

import SwiftUI
import Supabase

struct SendAnnouncementSheet: View {
    let game: Game
    let roster: [GamePlayer]

    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var targetPlayer: GamePlayer?
    @State private var isSending = false
    @State private var errorMessage: String?

    private let labelColor = Color.appSecondaryText
    private let accentColor = Color(red: 0x2C / 255, green: 0x9C / 255, blue: 0x5B / 255)

    private var isMessageEmpty: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Text("Send announcement")
                        .font(.custom("DIN-Medium", size: 17))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.custom("DIN-Medium", size: 15))
                                .foregroundStyle(Color.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            Task { await send() }
                        } label: {
                            Group {
                                if isSending {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Send")
                                        .font(.custom("DIN-Medium", size: 15))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isMessageEmpty ? Color(.systemGray5) : accentColor, in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isMessageEmpty || isSending)
                    }
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Send to")
                                .font(.custom("DIN-Regular", size: 13))
                                .foregroundStyle(labelColor)

                            Menu {
                                Button("Everyone") { targetPlayer = nil }
                                ForEach(roster) { player in
                                    Button(player.displayName) { targetPlayer = player }
                                }
                            } label: {
                                HStack {
                                    Text(targetPlayer?.displayName ?? "Everyone")
                                        .font(.custom("DIN-Regular", size: 17))
                                        .foregroundStyle(Color.primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.footnote)
                                        .foregroundStyle(labelColor)
                                }
                                .padding()
                                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message")
                                .font(.custom("DIN-Regular", size: 13))
                                .foregroundStyle(labelColor)

                            TextField("What's up?", text: $message, axis: .vertical)
                                .font(.custom("DIN-Regular", size: 17))
                                .lineLimit(3...6)
                                .padding()
                                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.custom("DIN-Regular", size: 13))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding()
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func send() async {
        guard let userID = (try? await supabase.auth.session)?.user.id else { return }

        struct NewAnnouncement: Encodable {
            let game_id: UUID
            let sender_id: UUID
            let target_player_id: UUID?
            let message: String
        }

        isSending = true
        do {
            try await supabase.from("announcements")
                .insert(NewAnnouncement(
                    game_id: game.id,
                    sender_id: userID,
                    target_player_id: targetPlayer?.id,
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines)
                ))
                .execute()
            isSending = false
            dismiss()
        } catch {
            isSending = false
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    let game = Game(
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
    )
    return SendAnnouncementSheet(
        game: game,
        roster: [
            GamePlayer(id: UUID(), gameId: game.id, profileId: nil, displayName: "Alex Chen", skillLevel: "Intermediate", status: .queued, queuePosition: 1, joinedAt: Date()),
            GamePlayer(id: UUID(), gameId: game.id, profileId: nil, displayName: "Jamie Lee", skillLevel: "Advanced", status: .queued, queuePosition: 2, joinedAt: Date())
        ]
    )
}
