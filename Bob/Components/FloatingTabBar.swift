import SwiftUI

enum BobTab: Int, CaseIterable {
    case home = 0
    case recurring
    case spending
    case more       // navigable via gear icons; not shown in tab bar
}

/// Liquid glass floating capsule tab bar + separate green "+" action button.
struct FloatingTabBar: View {
    @Binding var selected: BobTab
    var onAdd: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            // Glass capsule — 3 navigation tabs
            HStack(spacing: 2) {
                tabButton(.home,      icon: "house.fill",     label: "Dashboard")
                tabButton(.recurring, icon: "arrow.clockwise", label: "Recurring")
                tabButton(.spending,  icon: "chart.bar.fill",  label: "Spending")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .glassEffect(in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)

            // Green "+" action button
            Button {
                HapticManager.medium()
                onAdd()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.bobAccent)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.bobAccent.opacity(0.4), radius: 12, x: 0, y: 6)
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                }
            }
            .buttonStyle(GreenAddStyle())
        }
    }

    private func tabButton(_ tab: BobTab, icon: String, label: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { selected = tab }
        } label: {
            ZStack {
                if selected == tab {
                    Circle()
                        .fill(.black.opacity(0.45))
                        .frame(width: 44, height: 44)
                }
                Image(systemName: icon)
                    .font(.system(size: 19, weight: selected == tab ? .semibold : .regular))
                    .foregroundStyle(selected == tab ? Color.white : Color.white.opacity(0.5))
            }
            .frame(width: 54, height: 48)
            .accessibilityLabel(label)
            .accessibilityAddTraits(selected == tab ? .isSelected : [])
        }
        .buttonStyle(.plain)
    }
}

private struct GreenAddStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
