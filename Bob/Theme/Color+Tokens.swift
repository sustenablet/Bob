import SwiftUI

extension Color {
    // MARK: – Page backgrounds
    static let bobBackground   = Color.bobHex(0xF4F4F4)   // app page background (Revolut)
    static let bobSurface      = Color.bobHex(0xFFFFFF)   // cards, sheets
    static let bobSurface2     = Color.bobHex(0xF4F4F4)   // secondary surfaces, progress track
    static let bobSurface3     = Color.bobHex(0xE8E8E8)   // inputs, pressed states

    // MARK: – Text
    static let bobInk          = Color.bobHex(0x191C1F)   // primary text (Revolut)
    static let bobInk2         = Color.bobHex(0x505A63)   // secondary / muted (Revolut)
    static let bobInk3         = Color.bobHex(0x8E9AA6)   // tertiary / placeholders

    // MARK: – Borders (no shadows — elevation via surface contrast + hairline only)
    static let bobHairline     = Color.black.opacity(0.06)

    // MARK: – Accent — dark navy (primary actions, buttons)
    static let bobAccent       = Color.bobHex(0x0A0A0F)
    static let bobAccentSoft   = Color.bobHex(0x0A0A0F).opacity(0.08)

    // MARK: – Income green (Revolut)
    static let bobGreen        = Color.bobHex(0x00A87E)

    // MARK: – Negative / expense (Revolut)
    static let bobOverBudget   = Color.bobHex(0xE23B4A)
    static let bobDebit        = Color.bobHex(0xE23B4A)

    // MARK: – Chart (Revolut cobalt violet)
    static let bobChartBlue    = Color.bobHex(0x494FDF)

    // MARK: – Dark surfaces (for pill buttons, dark cards)
    static let bobDark         = Color.bobHex(0x0A0A0F)
    static let bobDarkInk      = Color.bobHex(0xFFFFFF)
    static let bobDarkInk2     = Color.bobHex(0x8E9AA6)

    // MARK: – Notification badge
    static let bobNotify       = Color.bobHex(0xE23B4A)

    // MARK: – Tab bar background
    static let bobTabBar       = Color.bobHex(0xFFFFFF)
}

extension Color {
    static func bobHex(_ value: UInt32) -> Color {
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8)  & 0xFF) / 255.0
        let b = Double(value & 0xFF)          / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
