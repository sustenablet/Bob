import SwiftUI

/// Dark circular action button with a label underneath.
/// Used in the dashboard action row.
struct ActionButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.bobDark)
                        .frame(width: 56, height: 56)
                    Image(systemName: systemImage)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white)
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.bobInk)
            }
        }
        .buttonStyle(ScalePressStyle())
    }
}

private struct ScalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
