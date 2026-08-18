//
//  AppBackground.swift
//  Qourt
//
//  The app's surface palette, defined once and adaptive to light/dark.
//
//  These were previously fixed light values. Because the text drawn on top
//  mostly used SwiftUI's `.primary`, which flips to white in dark mode, any
//  unlabelled text vanished against the still-light background — "Settings",
//  "Profile" and "Skill level" all disappeared on a dark-mode phone. Making
//  the surfaces adapt fixes every one of those sites at once, and keeps the
//  brief's requirement that the app work courtside in either mode.
//

import SwiftUI
import UIKit

extension UIColor {
    private static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
    }

    /// The page behind everything.
    static let appBackground = adaptive(
        light: UIColor(red: 0xF9 / 255, green: 0xF8 / 255, blue: 0xF4 / 255, alpha: 1),
        // Warm near-black rather than pure black, so the off-white brand
        // still reads as the same family at night.
        dark: UIColor(red: 0x15 / 255, green: 0x17 / 255, blue: 0x13 / 255, alpha: 1)
    )

    /// Cards and fields that sit on `appBackground`.
    static let appSurface = adaptive(
        light: .white,
        dark: UIColor(red: 0x22 / 255, green: 0x25 / 255, blue: 0x20 / 255, alpha: 1)
    )

    /// The muted olive used for secondary/caption text. The light value is
    /// near-black olive, which is unreadable on a dark surface, so the dark
    /// variant lifts it to a warm sand at the same hue.
    static let appSecondaryText = adaptive(
        light: UIColor(red: 0x4D / 255, green: 0x3E / 255, blue: 0x00 / 255, alpha: 1),
        dark: UIColor(red: 0xCB / 255, green: 0xBE / 255, blue: 0x8A / 255, alpha: 1)
    )

    /// Inverted fill (a dark pill on a light page) — must flip, or it turns
    /// invisible against a dark page.
    static let appInverseSurface = adaptive(
        light: .black,
        dark: UIColor(red: 0xEC / 255, green: 0xEA / 255, blue: 0xE2 / 255, alpha: 1)
    )

    /// Text drawn on `appInverseSurface`.
    static let appOnInverseSurface = adaptive(
        light: .white,
        dark: UIColor(red: 0x15 / 255, green: 0x17 / 255, blue: 0x13 / 255, alpha: 1)
    )
}

extension Color {
    static let appBackground = Color(UIColor.appBackground)
    static let appSurface = Color(UIColor.appSurface)
    static let appSecondaryText = Color(UIColor.appSecondaryText)
    static let appInverseSurface = Color(UIColor.appInverseSurface)
    static let appOnInverseSurface = Color(UIColor.appOnInverseSurface)
}
