import SwiftUI

extension Color {
    // Backgrounds
    static let bobBackground = Color.bobHex(0xF7F5F0)
    static let bobSurface = Color.bobHex(0xFFFFFF)

    // Text hierarchy
    static let bobInk = Color.bobHex(0x111110)
    static let bobInk2 = Color.bobHex(0x4A4A47)
    static let bobInk3 = Color.bobHex(0x9A9893)

    // Borders
    static let bobHairline = Color.bobHex(0xDDDBD5)

    // Accent — sage green
    static let bobAccent = Color.bobHex(0x588157)
    static let bobAccentSoft = Color.bobHex(0x588157).opacity(0.12)

    // Negative — debit / over-budget
    static let bobOverBudget = Color.bobHex(0xE0413B)
    static let bobDebit = Color.bobHex(0xE0413B)

    // Dark UI surfaces — action buttons, floating tab bar
    static let bobDark = Color.bobHex(0x0F0F0F)
    static let bobDarkInk = Color.bobHex(0xFFFFFF)
    static let bobDarkInk2 = Color.bobHex(0xB8B8B5)

    // Notification dot
    static let bobNotify = Color.bobHex(0xFF6B35)

    // Tab bar background
    static let bobTabBar = Color.bobHex(0xF7F5F0)
}

extension Color {
    /// Construct a Color from a 24-bit RGB hex value (e.g. 0xFBFBFA).
    static func bobHex(_ value: UInt32) -> Color {
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// Color scheme-aware colors for dark mode support
extension Color {
    static var bobBackgroundAdaptive: Color {
        Color("bobBackground", bundle: nil) ?? Color.bobHex(0xF7F5F0)
    }
    
    static var bobSurfaceAdaptive: Color {
        Color("bobSurface", bundle: nil) ?? Color.bobHex(0xFFFFFF)
    }
    
    static var bobInkAdaptive: Color {
        Color("bobInk", bundle: nil) ?? Color.bobHex(0x111110)
    }
    
    static var bobInk2Adaptive: Color {
        Color("bobInk2", bundle: nil) ?? Color.bobHex(0x4A4A47)
    }
    
    static var bobInk3Adaptive: Color {
        Color("bobInk3", bundle: nil) ?? Color.bobHex(0x9A9893)
    }
    
    static var bobHairlineAdaptive: Color {
        Color("bobHairline", bundle: nil) ?? Color.bobHex(0xDDDBD5)
    }
}