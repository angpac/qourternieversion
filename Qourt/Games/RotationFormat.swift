//
//  RotationFormat.swift
//  Qourt
//

import Foundation

enum RotationFormat: String, CaseIterable, Codable, Identifiable {
    case manual = "manual"
    case kingOfTheCourt = "king_of_the_court"
    case pegBoard = "peg_board"
    case fourOffFourOn = "four_off_four_on"
    case challengeCourt = "challenge_court"
    case halfCourtKingminton = "half_court_kingminton"
    case tournamentSingleElim = "tournament_single_elim"
    case tournamentDoubleElim = "tournament_double_elim"

    var id: String { rawValue }

    var isTournament: Bool { self == .tournamentSingleElim || self == .tournamentDoubleElim }

    var title: String {
        switch self {
        case .manual: "Manual"
        case .kingOfTheCourt: "King of the Court"
        case .pegBoard: "Peg Board / Racket Staking"
        case .fourOffFourOn: "Four Off, Four On"
        case .challengeCourt: "Challenge Court"
        case .halfCourtKingminton: "Half-Court Kingminton"
        case .tournamentSingleElim: "Tournament: Single Elimination"
        case .tournamentDoubleElim: "Tournament: Double Elimination"
        }
    }

    var subtitle: String {
        switch self {
        case .manual: "You build every match by hand, no automatic pairing or rotation."
        case .kingOfTheCourt: "A ladder where players climb toward a top court."
        case .pegBoard: "A single fair line where a rotating Picker builds balanced matches."
        case .fourOffFourOn: "Everyone swaps out roughly every 15 minutes."
        case .challengeCourt: "One high-energy court where winners defend, but can't dominate forever."
        case .halfCourtKingminton: "Keeps a big crowd moving on a small number of courts."
        case .tournamentSingleElim: "One loss and you're out, a single bracket to a champion."
        case .tournamentDoubleElim: "Lose once and you drop to a second bracket for one more shot."
        }
    }

    var systemImage: String {
        switch self {
        case .manual: "hand.raised.fill"
        case .kingOfTheCourt: "crown.fill"
        case .pegBoard: "list.number"
        case .fourOffFourOn: "arrow.triangle.2.circlepath"
        case .challengeCourt: "flame.fill"
        case .halfCourtKingminton: "rectangle.split.2x1"
        case .tournamentSingleElim, .tournamentDoubleElim: "trophy.fill"
        }
    }
}
