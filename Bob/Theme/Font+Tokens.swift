import SwiftUI

extension Font {
    // Big hero numerals — bold sans-serif (dashboard balance)
    static func bobHero(_ size: CGFloat = 44, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }

    // Screen / section titles
    static let bobTitle        = Font.system(size: 22, weight: .bold)

    // Body
    static let bobBody         = Font.system(size: 17, weight: .regular)
    static let bobBodyMed      = Font.system(size: 17, weight: .medium)
    static let bobCallout      = Font.system(size: 16, weight: .regular)
    static let bobCaption      = Font.system(size: 13, weight: .regular)

    // Section eyebrows
    static let bobLabel        = Font.system(size: 11, weight: .semibold)

    // Serif display for large amounts
    static func bobSerif(_ size: CGFloat = 68) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    // Mono for amounts
    static func bobMono(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct EyebrowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.bobLabel)
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.bobInk2)
    }
}

extension View {
    func eyebrow() -> some View { modifier(EyebrowStyle()) }
}
