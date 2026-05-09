import SwiftUI
import UIKit

/// Liquid Glass floating action button — sage-tinted glass circle.
/// Same height as the FloatingTabBar so the two read as a pair.
struct AddFAB: View {
    var systemImage: String = "plus"
    var onTap: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .glassEffect(.regular.tint(Color.bobAccent), in: Circle())
                .shadow(color: Color.bobAccent.opacity(0.25), radius: 14, x: 0, y: 6)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Add transaction")
        }
        .buttonStyle(FABPressStyle())
    }
}

private struct FABPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
