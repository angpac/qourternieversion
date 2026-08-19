//
//  ClipTheme.swift
//  QourtClip
//
//  The App Clip is the native twin of the web guest client, so it borrows
//  that page's palette rather than the iPhone app's. These are the exact
//  Tailwind values used in web/app/status/page.tsx and web/components/
//  JoinForm.tsx — someone who scans a QR on Android and someone who scans
//  it on iPhone should feel like they landed in the same product.
//

import SwiftUI

enum ClipTheme {
    // Tailwind emerald
    static let emerald900 = Color(red: 0x06 / 255, green: 0x4E / 255, blue: 0x3B / 255)
    static let emerald800 = Color(red: 0x06 / 255, green: 0x5F / 255, blue: 0x46 / 255)
    static let emerald700 = Color(red: 0x04 / 255, green: 0x78 / 255, blue: 0x57 / 255)
    static let emerald600 = Color(red: 0x05 / 255, green: 0x96 / 255, blue: 0x69 / 255)
    static let emerald100 = Color(red: 0xD1 / 255, green: 0xFA / 255, blue: 0xE5 / 255)
    static let emerald50 = Color(red: 0xEC / 255, green: 0xFD / 255, blue: 0xF5 / 255)

    // Tailwind zinc
    static let zinc900 = Color(red: 0x18 / 255, green: 0x18 / 255, blue: 0x1B / 255)
    static let zinc800 = Color(red: 0x27 / 255, green: 0x27 / 255, blue: 0x2A / 255)
    static let zinc700 = Color(red: 0x3F / 255, green: 0x3F / 255, blue: 0x46 / 255)
    static let zinc600 = Color(red: 0x52 / 255, green: 0x52 / 255, blue: 0x5B / 255)
    static let zinc500 = Color(red: 0x71 / 255, green: 0x71 / 255, blue: 0x7A / 255)
    static let zinc400 = Color(red: 0xA1 / 255, green: 0xA1 / 255, blue: 0xAA / 255)
    static let zinc300 = Color(red: 0xD4 / 255, green: 0xD4 / 255, blue: 0xD8 / 255)
    static let zinc100 = Color(red: 0xF4 / 255, green: 0xF4 / 255, blue: 0xF5 / 255)

    // Accents
    static let amber600 = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x06 / 255)
    static let amber500 = Color(red: 0xF5 / 255, green: 0x9E / 255, blue: 0x0B / 255)
    static let amber100 = Color(red: 0xFE / 255, green: 0xF3 / 255, blue: 0xC7 / 255)
    static let amber50 = Color(red: 0xFF / 255, green: 0xFB / 255, blue: 0xEB / 255)
    static let red600 = Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)
    static let red700 = Color(red: 0xB9 / 255, green: 0x1C / 255, blue: 0x1C / 255)
    static let red300 = Color(red: 0xFC / 255, green: 0xA5 / 255, blue: 0xA5 / 255)
    static let red50 = Color(red: 0xFE / 255, green: 0xF2 / 255, blue: 0xF2 / 255)

    /// The page background on the web: a vertical emerald gradient.
    static var background: LinearGradient {
        LinearGradient(
            colors: [emerald900, emerald700],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// The white rounded card the web client puts its content in.
struct ClipCard<Content: View>: View {
    var padding: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}
