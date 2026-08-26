//
//  BracketViewModel.swift
//  Qourt
//

import Foundation
import Supabase

struct BracketRoundKey: Hashable {
    let bracket: String
    let round: Int
}

@Observable
final class BracketViewModel {
    let game: Game

    var tournament: Tournament?
    var tournamentMatches: [TournamentMatch] = []
    var courts: [Court] = []
    var activeMatches: [UUID: MatchWithPlayers] = [:] // keyed by tournament_match id
    var playerNames: [UUID: String] = [:]
    var gameStatus: String
    var hasEnded: Bool { gameStatus == "ended" }
    var isLoading = true
    var errorMessage: String?

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeSubscriptions: [RealtimeSubscription] = []

    init(game: Game) {
        self.game = game
        self.gameStatus = game.status
    }

    var readyMatches: [TournamentMatch] {
        tournamentMatches.filter(\.isReadyToStart).sorted { ($0.round, $0.slot) < ($1.round, $1.slot) }
    }

    /// `activeMatches` keeps a finished tournament match's row around
    /// forever (its `matchId` is never cleared) so the bracket can keep
    /// showing the final score and winner — but that means a plain
    /// `courtId` lookup here would treat every court that ever hosted a
    /// match as permanently occupied. Only a match still actually being
    /// played holds its court.
    var openCourts: [Court] {
        let busyCourtIDs = Set(
            activeMatches.values
                .filter { $0.match.status != .confirmed && $0.match.status != .cancelled }
                .compactMap(\.match.courtId)
        )
        return courts.filter { !busyCourtIDs.contains($0.id) }
    }

    /// The unique match nothing advances out of — its winner is the champion.
    var championName: String? {
        guard let finalTM = tournamentMatches.first(where: { $0.nextMatchId == nil }),
              let match = activeMatches[finalTM.id]?.match,
              match.status == .confirmed,
              let scoreA = match.scoreA, let scoreB = match.scoreB
        else { return nil }
        let winnerIDs = scoreA > scoreB ? finalTM.teamAPlayerIds : finalTM.teamBPlayerIds
        return winnerIDs?.compactMap { playerNames[$0] }.joined(separator: " & ")
    }

    func name(for ids: [UUID]?) -> String {
        guard let ids, !ids.isEmpty else { return "TBD" }
        return ids.compactMap { playerNames[$0] }.joined(separator: " & ")
    }

    @MainActor
    func start() async {
        await loadAll()
        await subscribeToChanges()
    }

    func stop() {
        realtimeSubscriptions.forEach { $0.cancel() }
        realtimeSubscriptions.removeAll()
        Task { await realtimeChannel?.unsubscribe() }
    }

    @MainActor
    func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        do {
            struct StatusRow: Decodable { let status: String }
            if let row: StatusRow = try? await supabase.from("games")
                .select("status")
                .eq("id", value: game.id)
                .single()
                .execute()
                .value {
                gameStatus = row.status
            }

            let tournaments: [Tournament] = try await supabase.from("tournaments")
                .select()
                .eq("game_id", value: game.id)
                .execute()
                .value
            tournament = tournaments.first

            let roster: [GamePlayer] = try await supabase.from("game_players")
                .select()
                .eq("game_id", value: game.id)
                .execute()
                .value
            playerNames = Dictionary(uniqueKeysWithValues: roster.map { ($0.id, $0.displayName) })

            courts = try await supabase.from("courts")
                .select()
                .eq("game_id", value: game.id)
                .order("position")
                .execute()
                .value

            guard let tournament else { return }

            tournamentMatches = try await supabase.from("tournament_matches")
                .select()
                .eq("tournament_id", value: tournament.id)
                .execute()
                .value

            await loadActiveMatches()
        } catch is CancellationError {
            // Superseded by a newer load (e.g. pull-to-refresh interrupted
            // by a realtime-triggered reload) — leave state as-is rather
            // than blanking it out or surfacing a bogus error.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadActiveMatches() async {
        let matchIDs = tournamentMatches.compactMap(\.matchId)
        guard !matchIDs.isEmpty else {
            activeMatches = [:]
            return
        }
        struct MatchPlayerRow: Decodable {
            let match_id: UUID
            let team: String
            let game_players: GamePlayer
        }
        do {
            let matches: [Match] = try await supabase.from("matches")
                .select()
                .in("id", values: matchIDs)
                .execute()
                .value
            let rows: [MatchPlayerRow] = try await supabase.from("match_players")
                .select("match_id, team, game_players(*)")
                .in("match_id", values: matchIDs)
                .execute()
                .value

            var byMatchID: [UUID: MatchWithPlayers] = [:]
            for match in matches {
                let matchRows = rows.filter { $0.match_id == match.id }
                let teamA = matchRows.filter { $0.team == "a" }.map(\.game_players)
                let teamB = matchRows.filter { $0.team == "b" }.map(\.game_players)
                byMatchID[match.id] = MatchWithPlayers(match: match, teamA: teamA, teamB: teamB)
            }
            activeMatches = Dictionary(uniqueKeysWithValues: tournamentMatches.compactMap { tm in
                guard let matchID = tm.matchId, let mwp = byMatchID[matchID] else { return nil }
                return (tm.id, mwp)
            })
        } catch is CancellationError {
            // Superseded by a newer load — leave activeMatches as-is.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func subscribeToChanges() async {
        let channel = supabase.realtimeV2.channel("bracket-\(game.id)")
        realtimeChannel = channel
        for table in ["tournament_matches", "matches", "match_players"] {
            let subscription = channel.onPostgresChange(AnyAction.self, schema: "public", table: table) { [weak self] _ in
                Task { await self?.loadAll() }
            }
            realtimeSubscriptions.append(subscription)
        }

        // None of the tables above change when the admin ends the game —
        // that only touches the games row itself — so without this the
        // bracket screen never learns the session ended until something
        // else forces a reload.
        let gamesSubscription = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "games",
            filter: "id=eq.\(game.id)"
        ) { [weak self] _ in
            Task { await self?.loadAll() }
        }
        realtimeSubscriptions.append(gamesSubscription)

        try? await channel.subscribeWithError()
    }

    @MainActor
    func startMatch(_ tournamentMatch: TournamentMatch, on court: Court) async {
        // Same hard requirement as the regular dashboard's startMatch: a
        // match with an empty team must never be writable, non-nil isn't
        // enough on its own to prove there's actually someone in it.
        guard let teamA = tournamentMatch.teamAPlayerIds, let teamB = tournamentMatch.teamBPlayerIds,
              !teamA.isEmpty, !teamB.isEmpty else { return }
        struct NewMatch: Encodable {
            let game_id: UUID
            let court_id: UUID
            let status: String
        }
        do {
            let match: Match = try await supabase.from("matches")
                .insert(NewMatch(game_id: game.id, court_id: court.id, status: MatchStatus.inProgress.rawValue))
                .select()
                .single()
                .execute()
                .value

            let matchPlayers = teamA.map { MatchPlayer(matchId: match.id, gamePlayerId: $0, team: "a") }
                + teamB.map { MatchPlayer(matchId: match.id, gamePlayerId: $0, team: "b") }
            try await supabase.from("match_players").insert(matchPlayers).execute()

            try await supabase.from("tournament_matches")
                .update(["match_id": match.id.uuidString])
                .eq("id", value: tournamentMatch.id)
                .execute()

            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func updateScore(matchID: UUID, scoreA: Int, scoreB: Int) async {
        _ = try? await supabase.from("matches")
            .update(["score_a": scoreA, "score_b": scoreB])
            .eq("id", value: matchID)
            .execute()
    }

    @MainActor
    func endMatch(_ tournamentMatch: TournamentMatch, scoreA: Int, scoreB: Int) async {
        guard let match = activeMatches[tournamentMatch.id]?.match else { return }
        do {
            try await supabase.from("matches")
                .update([
                    "status": AnyJSON.string(MatchStatus.confirmed.rawValue),
                    "score_a": AnyJSON.integer(scoreA),
                    "score_b": AnyJSON.integer(scoreB),
                    "ended_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
                ])
                .eq("id", value: match.id)
                .execute()

            let aWon = scoreA > scoreB
            let winners = aWon ? tournamentMatch.teamAPlayerIds : tournamentMatch.teamBPlayerIds
            let losers = aWon ? tournamentMatch.teamBPlayerIds : tournamentMatch.teamAPlayerIds

            if let nextID = tournamentMatch.nextMatchId, let slot = tournamentMatch.advancesToSlot, let winners {
                try await advance(playerIDs: winners, into: nextID, slot: slot)
            }
            if let loserNextID = tournamentMatch.loserNextMatchId, let slot = tournamentMatch.loserAdvancesToSlot, let losers {
                try await advance(playerIDs: losers, into: loserNextID, slot: slot)
            }

            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func advance(playerIDs: [UUID], into tournamentMatchID: UUID, slot: String) async throws {
        let column = slot == "a" ? "team_a_player_ids" : "team_b_player_ids"
        try await supabase.from("tournament_matches")
            .update([column: playerIDs.map(\.uuidString)])
            .eq("id", value: tournamentMatchID)
            .execute()
    }
}
