//
//  FormatSettings.swift
//  Qourt
//

import Foundation
import Supabase

struct FormatSettings {
    var roundMinutes: Int = 8
    var autoRotate: Bool = true
    var pickerPoolSize: Int = 10
    var pointTarget: Int = 21
    var winCap: Int = 3
    var kingmintonPointTarget: Int = 5

    /// When true, the admin builds each match by hand from the queue instead of
    /// the app auto-pairing players. Applies on top of any format's own rules.
    var manualMatching: Bool = false

    init() {}

    /// Reconstructs settings from a stored `format_settings` blob — used
    /// when starting a new game from a saved Template, so every field
    /// round-trips through the same keys `asJSONObject` writes.
    init(from json: JSONObject) {
        if case let .integer(value)? = json["round_minutes"] { roundMinutes = value }
        if case let .bool(value)? = json["auto_rotate"] { autoRotate = value }
        if case let .integer(value)? = json["picker_pool_size"] { pickerPoolSize = value }
        if case let .integer(value)? = json["point_target"] {
            pointTarget = value
            kingmintonPointTarget = value
        }
        if case let .integer(value)? = json["win_cap"] { winCap = value }
        if case let .bool(value)? = json["manual_matching"] { manualMatching = value }
    }

    func asJSONObject(for format: RotationFormat) -> JSONObject {
        var settings: JSONObject
        switch format {
        case .kingOfTheCourt:
            settings = [
                "round_minutes": .integer(roundMinutes),
                "auto_rotate": .bool(autoRotate)
            ]
        case .pegBoard:
            settings = [
                "picker_pool_size": .integer(pickerPoolSize)
            ]
        case .fourOffFourOn:
            settings = [
                "point_target": .integer(pointTarget)
            ]
        case .challengeCourt:
            settings = [
                "win_cap": .integer(winCap)
            ]
        case .halfCourtKingminton:
            settings = [
                "point_target": .integer(kingmintonPointTarget)
            ]
        case .tournamentSingleElim, .tournamentDoubleElim:
            settings = [
                "point_target": .integer(pointTarget)
            ]
        }
        settings["manual_matching"] = .bool(manualMatching)
        return settings
    }
}
