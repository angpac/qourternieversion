//
//  BracketGenerator.swift
//  Qourt
//

import Foundation

/// Pure, deterministic bracket construction — given a seeded player order
/// (strongest first) it produces every match the whole tournament will
/// ever need, fully wired via `nextMatchId`/`advancesToSlot` (and
/// `loserNextMatchId`/`loserAdvancesToSlot` for double elimination), with
/// client-generated UUIDs so the routing pointers can be set in the same
/// insert batch. Byes (an odd bracket size vs. real entrant count) resolve
/// immediately at generation time — no match row is created for them, the
/// bye'd player is written directly into whatever match they'd have
/// advanced to.
enum BracketGenerator {
    struct GeneratedMatch {
        let id = UUID()
        var round: Int
        var slot: Int
        var bracket: String
        var teamA: [UUID]?
        var teamB: [UUID]?
        var nextMatchId: UUID?
        var advancesToSlot: String?
        var loserNextMatchId: UUID?
        var loserAdvancesToSlot: String?
    }

    private struct Slot {
        var decided: UUID?
        var producerMatchIndex: Int?
        var producerIsLoser: Bool = false
        var isEmpty: Bool { decided == nil && producerMatchIndex == nil }
    }

    static func nextPowerOfTwo(atLeast n: Int) -> Int {
        var size = 2
        while size < n { size *= 2 }
        return size
    }

    /// Standard "avoid early rematches" seed placement, e.g. size 8 →
    /// [1, 8, 4, 5, 2, 7, 3, 6] — top seeds are spread as far apart as
    /// possible so 1 and 2 can't meet before the final.
    static func seedOrder(size: Int) -> [Int] {
        var seeds = [1]
        while seeds.count < size {
            let n = seeds.count * 2
            var next: [Int] = []
            for seed in seeds {
                next.append(seed)
                next.append(n + 1 - seed)
            }
            seeds = next
        }
        return seeds
    }

    private static func wire(_ slot: Slot, toMatchId: UUID, side: String, matches: inout [GeneratedMatch]) {
        guard let idx = slot.producerMatchIndex else { return }
        if slot.producerIsLoser {
            matches[idx].loserNextMatchId = toMatchId
            matches[idx].loserAdvancesToSlot = side
        } else {
            matches[idx].nextMatchId = toMatchId
            matches[idx].advancesToSlot = side
        }
    }

    /// Combines two bracket slots into one. When both sides have someone —
    /// either already decided (a seeded player) or still to-be-determined
    /// (a producer, i.e. "the winner/loser of an earlier match") — this
    /// creates the match connecting them. When only one side has someone,
    /// that's a bye: the lone side passes straight through untouched
    /// instead of becoming a match nobody can ever start.
    ///
    /// This has to treat "decided" and "producer" identically as "someone
    /// is here" — a losers-bracket slot fed by a real match (a producer,
    /// not decided until that match concludes) is just as much "someone"
    /// as an already-seeded player. Handling only the decided case (as an
    /// earlier version of this did) let a winners-bracket bye's empty
    /// "loser" slot get paired against a real producer slot in the losers
    /// bracket, creating a match whose other team could never be filled
    /// in — and everything downstream of it stayed stuck at "TBD" forever.
    /// Returns the winner-advancing slot; `loser` is set only when a real
    /// match was created (nil for a bye, since nobody lost).
    private static func pair(
        _ left: Slot,
        _ right: Slot,
        round: Int,
        slot: Int,
        bracket: String,
        matches: inout [GeneratedMatch]
    ) -> (winner: Slot, loser: Slot?) {
        if left.isEmpty && right.isEmpty {
            return (Slot(), nil)
        }
        if left.isEmpty {
            return (right, nil)
        }
        if right.isEmpty {
            return (left, nil)
        }

        let newMatch = GeneratedMatch(
            round: round, slot: slot, bracket: bracket,
            teamA: left.decided.map { [$0] }, teamB: right.decided.map { [$0] }
        )
        let idx = matches.count
        matches.append(newMatch)
        wire(left, toMatchId: newMatch.id, side: "a", matches: &matches)
        wire(right, toMatchId: newMatch.id, side: "b", matches: &matches)
        return (Slot(producerMatchIndex: idx), Slot(producerMatchIndex: idx, producerIsLoser: true))
    }

    /// Builds the winners bracket. Returns the per-round loser slots
    /// (one array per WB round) so double-elimination can route them into
    /// the losers bracket; single-elimination just ignores that return.
    @discardableResult
    private static func generateWinnersBracket(
        players: [UUID],
        size: Int,
        matches: inout [GeneratedMatch]
    ) -> [[Slot]] {
        let order = seedOrder(size: size)
        var slots: [Slot] = order.map { seed in
            Slot(decided: seed <= players.count ? players[seed - 1] : nil)
        }
        var round = 1
        var loserSlotsByRound: [[Slot]] = []

        while slots.count > 1 {
            var nextSlots: [Slot] = []
            var losers: [Slot] = []
            for i in stride(from: 0, to: slots.count, by: 2) {
                let (winner, loser) = pair(slots[i], slots[i + 1], round: round, slot: i / 2, bracket: "winners", matches: &matches)
                nextSlots.append(winner)
                losers.append(loser ?? Slot())
            }
            loserSlotsByRound.append(losers)
            slots = nextSlots
            round += 1
        }
        return loserSlotsByRound
    }

    static func generateSingleElimination(players: [UUID]) -> [GeneratedMatch] {
        guard players.count >= 2 else { return [] }
        var matches: [GeneratedMatch] = []
        generateWinnersBracket(players: players, size: nextPowerOfTwo(atLeast: players.count), matches: &matches)
        return matches
    }

    /// Standard double-elimination shape: a losers bracket alternates
    /// "losers vs. losers" rounds with "dropdown" rounds (losers-bracket
    /// survivors vs. the next winners-bracket round's fresh losers), until
    /// one losers-bracket champion remains to face the winners-bracket
    /// champion in a single Grand Final.
    ///
    /// Two known simplifications, chosen to keep this correct and
    /// shippable rather than risk a subtly-wrong "optimal" version:
    /// dropdown-round pairing is index-aligned rather than seeded to
    /// avoid immediate rematches, and the Grand Final is a single match
    /// (no "bracket reset" if the losers-bracket finalist wins it).
    static func generateDoubleElimination(players: [UUID]) -> [GeneratedMatch] {
        guard players.count >= 4 else { return generateSingleElimination(players: players) }

        var matches: [GeneratedMatch] = []
        let size = nextPowerOfTwo(atLeast: players.count)
        let wbLoserSlotsByRound = generateWinnersBracket(players: players, size: size, matches: &matches)
        let wbFinalIndex = matches.count - 1
        let wbRounds = wbLoserSlotsByRound.count

        var lbRound = 1
        var currentLB = wbLoserSlotsByRound[0]

        for k in 1..<wbRounds {
            var afterLosersRound: [Slot] = currentLB
            if currentLB.count > 1 {
                afterLosersRound = []
                for i in stride(from: 0, to: currentLB.count, by: 2) {
                    let (winner, _) = pair(currentLB[i], currentLB[i + 1], round: lbRound, slot: i / 2, bracket: "losers", matches: &matches)
                    afterLosersRound.append(winner)
                }
                lbRound += 1
            }

            let wbLosersThisDrop = wbLoserSlotsByRound[k]
            var afterDropdown: [Slot] = []
            for i in 0..<afterLosersRound.count {
                let (winner, _) = pair(afterLosersRound[i], wbLosersThisDrop[i], round: lbRound, slot: i, bracket: "losers", matches: &matches)
                afterDropdown.append(winner)
            }
            lbRound += 1
            currentLB = afterDropdown
        }

        let wbChampion = Slot(producerMatchIndex: wbFinalIndex)
        let lbChampion = currentLB[0]
        let final = GeneratedMatch(
            round: max(wbRounds, lbRound), slot: 0, bracket: "final",
            teamA: wbChampion.decided.map { [$0] }, teamB: lbChampion.decided.map { [$0] }
        )
        matches.append(final)
        wire(wbChampion, toMatchId: final.id, side: "a", matches: &matches)
        wire(lbChampion, toMatchId: final.id, side: "b", matches: &matches)

        return matches
    }
}
