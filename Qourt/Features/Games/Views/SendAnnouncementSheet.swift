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

    var body: some View {
        NavigationStack {
            Form {
                Section("Send to") {
                    Picker("Recipient", selection: $targetPlayer) {
                        Text("Everyone").tag(nil as GamePlayer?)
                        ForEach(roster) { player in
                            Text(player.displayName).tag(player as GamePlayer?)
                        }
                    }
                }

                Section("Message") {
                    TextField("What's up?", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Send announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await send() }
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Send")
                        }
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
            }
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
