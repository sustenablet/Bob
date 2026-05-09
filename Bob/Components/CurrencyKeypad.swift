import SwiftUI
import UIKit

struct CurrencyKeypad: View {
    @Binding var amount: Decimal
    var onSubmit: (() -> Void)? = nil

    @State private var rawCents: Int = 0

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<keys.count, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(keys[row], id: \.self) { key in
                        keyButton(key)
                    }
                }
                if row < keys.count - 1 {
                    HairlineDivider()
                }
            }
        }
        .background(Color.bobBackground)
        .onAppear { syncFromAmount() }
        .onChange(of: amount) { _, newValue in
            let cents = NSDecimalNumber(decimal: newValue * 100).intValue
            if cents != rawCents {
                rawCents = max(cents, 0)
            }
        }
    }

    private func keyButton(_ key: String) -> some View {
        Button(action: { handleTap(key) }) {
            ZStack {
                Color.clear
                Text(key)
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(Color.bobInk)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(KeypadButtonStyle())
    }

    private func handleTap(_ key: String) {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        switch key {
        case "⌫":
            rawCents = rawCents / 10
        case ".":
            // Decimal point is implicit in cent-based entry; ignore.
            return
        default:
            guard let digit = Int(key) else { return }
            let next = rawCents * 10 + digit
            if next > 99_999_999 { return }
            rawCents = next
        }

        amount = Decimal(rawCents) / 100
    }

    private func syncFromAmount() {
        rawCents = max(NSDecimalNumber(decimal: amount * 100).intValue, 0)
    }
}

private struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.bobAccentSoft : Color.clear)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
