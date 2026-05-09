import SwiftUI

extension Color {
    // MARK: – Notion dark palette backgrounds
    static let bobBackground   = Color.bobHex(0x191919)   // Notion page background
    static let bobSurface      = Color.bobHex(0x2F2F2F)   // Notion card / block
    static let bobSurface2     = Color.bobHex(0x373737)   // Notion elevated / hover
    static let bobSurface3     = Color.bobHex(0x3F3F3F)   // Notion input / pressed

    // MARK: – Text
    static let bobInk          = Color.bobHex(0xFFFFFF)   // primary text
    static let bobInk2         = Color.bobHex(0x999999)   // secondary (Notion muted)
    static let bobInk3         = Color.bobHex(0x555555)   // tertiary / placeholders

    // MARK: – Borders
    static let bobHairline     = Color.bobHex(0x3F3F3F)   // Notion border

    // MARK: – Accent — green
    static let bobAccent       = Color.bobHex(0x4ADE80)
    static let bobAccentSoft   = Color.bobHex(0x4ADE80).opacity(0.15)

    // MARK: – Negative
    static let bobOverBudget   = Color.bobHex(0xFF5252)
    static let bobDebit        = Color.bobHex(0xFF5252)

    // MARK: – Chart blue
    static let bobChartBlue    = Color.bobHex(0x4F7FFF)

    // MARK: – Tab bar / dark surfaces
    static let bobDark         = Color.bobHex(0x111111)   // Notion sidebar tone
    static let bobDarkInk      = Color.bobHex(0xFFFFFF)
    static let bobDarkInk2     = Color.bobHex(0x888888)

    // MARK: – Notification
    static let bobNotify       = Color.bobHex(0xFF5252)

    // MARK: – Tab bar background
    static let bobTabBar       = Color.bobHex(0x111111)
}

extension Color {
    static func bobHex(_ value: UInt32) -> Color {
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8)  & 0xFF) / 255.0
        let b = Double(value & 0xFF)          / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
