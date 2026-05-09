import SwiftUI

extension Color {
    // MARK: – Dark theme backgrounds
    static let bobBackground   = Color.bobHex(0x0D0D18)   // page background
    static let bobSurface      = Color.bobHex(0x1A1A28)   // card / elevated surface
    static let bobSurface2     = Color.bobHex(0x22222F)   // slightly more elevated
    static let bobSurface3     = Color.bobHex(0x2A2A3A)   // borders, dividers

    // MARK: – Text hierarchy
    static let bobInk          = Color.bobHex(0xFFFFFF)   // primary text
    static let bobInk2         = Color.bobHex(0xA0A0B4)   // secondary text
    static let bobInk3         = Color.bobHex(0x5A5A70)   // tertiary / placeholders

    // MARK: – Borders / hairlines
    static let bobHairline     = Color.bobHex(0x2A2A3A)

    // MARK: – Accent — bright green (income / positive)
    static let bobAccent       = Color.bobHex(0x4ADE80)
    static let bobAccentSoft   = Color.bobHex(0x4ADE80).opacity(0.15)

    // MARK: – Negative — expense / over budget
    static let bobOverBudget   = Color.bobHex(0xFF5252)
    static let bobDebit        = Color.bobHex(0xFF5252)

    // MARK: – Chart blue
    static let bobChartBlue    = Color.bobHex(0x4F7FFF)

    // MARK: – Dark UI surfaces (tab bar etc)
    static let bobDark         = Color.bobHex(0x111120)
    static let bobDarkInk      = Color.bobHex(0xFFFFFF)
    static let bobDarkInk2     = Color.bobHex(0x8888A0)

    // MARK: – Notification dot
    static let bobNotify       = Color.bobHex(0xFF5252)

    // MARK: – Tab bar
    static let bobTabBar       = Color.bobHex(0x111120)
}

extension Color {
    /// Construct a Color from a 24-bit RGB hex value (e.g. 0x4ADE80).
    static func bobHex(_ value: UInt32) -> Color {
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8)  & 0xFF) / 255.0
        let b = Double(value & 0xFF)          / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
