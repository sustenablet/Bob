import SwiftUI

extension Font {
    // Big hero numerals — bold sans-serif (dashboard balance)
    static func bobHero(_ size: CGFloat = 38, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }

    // Optional serif (for any editorial headings)
    static func bobSerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    // Body
    static let bobBody       = Font.system(size: 16, weight: .regular)
    static let bobBodyMed    = Font.system(size: 16, weight: .medium)
    static let bobCallout    = Font.system(size: 15, weight: .regular)
    static let bobCaption    = Font.system(size: 13, weight: .regular)

    // Section eyebrows
    static let bobLabel      = Font.system(size: 11, weight: .semibold)

    // Mono for amounts
    static func bobMono(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct EyebrowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.bobLabel)
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.bobInk2)
    }
}

extension View {
    func eyebrow() -> some View { modifier(EyebrowStyle()) }
}
