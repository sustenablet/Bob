import SwiftUI

struct DashboardHeader: View {
    let greeting: String
    let onInbox: () -> Void
    let onProfile: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text(greeting)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.bobInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            iconButton(systemImage: "tray", action: onInbox)
                .padding(.trailing, 10)
            iconButton(systemImage: "person.crop.circle", action: onProfile)
        }
    }

    private func iconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.bobHairline, lineWidth: 1)
                    .background(Circle().fill(Color.bobSurface))
                    .frame(width: 42, height: 42)
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color.bobInk)
            }
        }
        .buttonStyle(.plain)
    }
}
