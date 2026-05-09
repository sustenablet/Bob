import SwiftUI

/// White pill chip with a hairline border, used as a category label
/// above a hero number on the dashboard.
struct BalancePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.bobInk)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.bobSurface)
            )
            .overlay(
                Capsule().stroke(Color.bobHairline, lineWidth: 1)
            )
    }
}
