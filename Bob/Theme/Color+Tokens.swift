import SwiftUI
import UIKit

extension Color {
    // MARK: – Page backgrounds
    static var bobBackground: Color  { .dynamic(light: 0xFFFFFF, dark: 0x1A1A1E) }
    static var bobSurface: Color     { .dynamic(light: 0xFFFFFF, dark: 0x242428) }
    static var bobSurface2: Color    { .dynamic(light: 0xF4F4F4, dark: 0x2C2C30) }
    static var bobSurface3: Color    { .dynamic(light: 0xE8E8E8, dark: 0x3A3A3E) }

    // MARK: – Text
    static var bobInk: Color         { .dynamic(light: 0x191C1F, dark: 0xF0F0F0) }
    static var bobInk2: Color        { .dynamic(light: 0x2C2C2C, dark: 0xD0D0D0) }
    static var bobInk3: Color        { .dynamic(light: 0x8E9AA6, dark: 0x888888) }

    // MARK: – Borders
    static var bobHairline: Color    { Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(white: 0, alpha: 0.06)
    }) }

    // MARK: – Accent — muted steel blue
    static var bobAccent: Color      { .dynamic(light: 0x5271A4, dark: 0x6B8FC5) }
    static var bobAccentSoft: Color  { .dynamic(light: 0x5271A4, dark: 0x6B8FC5, alpha: 0.08) }

    // MARK: – Income green
    static var bobGreen: Color       { .dynamic(light: 0x00A87E, dark: 0x00C98F) }

    // MARK: – Negative / expense
    static var bobOverBudget: Color  { .dynamic(light: 0xE23B4A, dark: 0xFF4757) }
    static var bobDebit: Color       { .dynamic(light: 0xE23B4A, dark: 0xFF4757) }

    // MARK: – Chart — same muted steel blue
    static var bobChartBlue: Color   { .dynamic(light: 0x5271A4, dark: 0x6B8FC5) }

    // MARK: – Dark surfaces (for pill buttons, dark cards)
    static var bobDark: Color        { Color.bobHex(0x0A0A0F) }
    static var bobDarkInk: Color     { Color.bobHex(0xFFFFFF) }
    static var bobDarkInk2: Color    { Color.bobHex(0x8E9AA6) }

    // MARK: – Notification badge
    static var bobNotify: Color      { .dynamic(light: 0xE23B4A, dark: 0xFF4757) }

    // MARK: – Tab bar background
    static var bobTabBar: Color      { .dynamic(light: 0xFFFFFF, dark: 0x1A1A1E) }
}

// MARK: – Dynamic color constructor
extension Color {
    static func dynamic(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let r = CGFloat((hex >> 16) & 0xFF) / 255
            let g = CGFloat((hex >> 8)  & 0xFF) / 255
            let b = CGFloat(hex & 0xFF)          / 255
            return UIColor(red: r, green: g, blue: b, alpha: alpha)
        })
    }
}

extension Color {
    static func bobHex(_ value: UInt32) -> Color {
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8)  & 0xFF) / 255.0
        let b = Double(value & 0xFF)          / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
