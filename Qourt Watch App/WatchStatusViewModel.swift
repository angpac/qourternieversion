//
//  WatchStatusViewModel.swift
//  Qourt Watch App
//

import Foundation
import Supabase

struct WatchGame: Codable {
    var id: UUID
    var name: String

    enum CodingKeys: String, CodingKey {
        case id, name
    }
}

@Observable
final class WatchStatusViewModel {
    var isSignedIn = false
    var isLoading = true
    var gameName: String?
    var playerStatus: PlayerStatus?
    var queuePosition: Int?
    var courtName: String?
    var scoreA: Int?
    var scoreB: Int?
    var errorMessage: String?

    @MainActor
    func start() async {
        isLoading = true
        defer { isLoading = false }

        guard let userID = (try? await supabase.auth.session)?.user.id else {
            isSignedIn = false
            return
        }
        isSignedIn = true

        struct ActivePlayerRow: Decodable {
            let id: UUID
            let status: PlayerStatus
            let queue_position: Int?
            let joined_at: Date
            let games: WatchGame
        }

        do {
            let rows: [ActivePlayerRow] = try await supabase.from("game_players")
                .select("id, status, queue_position, joined_at, games(id, name)")
                .eq("profile_id", value: userID)
                .in("status", values: [PlayerStatus.queued.rawValue, PlayerStatus.onCourt.rawValue])
                .order("joined_at", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let active = rows.first else {
                gameName = nil
                playerStatus = nil
                return
            }

            gameName = active.games.name
            playerStatus = active.status

            if active.status == .queued {
                queuePosition = try await computeQueuePosition(gameID: active.games.id, playerID: active.id)
                courtName = nil
                scoreA = nil
                scoreB = nil
            } else {
                queuePosition = nil
                await loadCourtAndScore(playerID: active.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func computeQueuePosition(gameID: UUID, playerID: UUID) async throws -> Int? {
        struct Row: Decodable { let id: UUID }
        let queue: [Row] = try await supabase.from("game_players")
            .select("id")
            .eq("game_id", value: gameID)
            .eq("status", value: PlayerStatus.queued.rawValue)
            .order("queue_position", ascending: true, nullsFirst: false)
            .order("joined_at", ascending: true)
            .execute()
            .value
        guard let index = queue.firstIndex(where: { $0.id == playerID }) else { return nil }
        return index + 1
    }

    @MainActor
    private func loadCourtAndScore(playerID: UUID) async {
        struct MatchPlayerRow: Decodable {
            let matches: MatchInfo
        }
        struct MatchInfo: Decodable {
            let score_a: Int?
            let score_b: Int?
            let status: MatchStatus
            let courts: CourtInfo?
        }
        struct CourtInfo: Decodable {
            let name: String
        }

        let rows: [MatchPlayerRow]? = try? await supabase.from("match_players")
            .select("matches!inner(score_a, score_b, status, courts(name))")
            .eq("game_player_id", value: playerID)
            .in("matches.status", values: [MatchStatus.inProgress.rawValue, MatchStatus.awaitingConfirmation.rawValue])
            .execute()
            .value

        guard let match = rows?.first?.matches else {
            courtName = nil
            scoreA = nil
            scoreB = nil
            return
        }
        courtName = match.courts?.name
        scoreA = match.score_a
        scoreB = match.score_b
    }
}
