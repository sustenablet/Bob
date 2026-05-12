import SwiftUI

enum BobTab: Int, CaseIterable {
    case home = 0
    case recurring
    case spending
    case more
}

/// Floating capsule tab bar with icon + label, light theme, no FAB.
struct FloatingTabBar: View {
    @Binding var selected: BobTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home,      icon: "house.fill",      label: "Home")
            tabButton(.recurring, icon: "arrow.clockwise", label: "Bills")
            tabButton(.spending,  icon: "chart.bar.fill",  label: "Spending")
            tabButton(.more,      icon: "ellipsis",        label: "More")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.bobSurface)
                .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 8)
                .overlay(
                    Capsule()
                        .stroke(Color.bobHairline, lineWidth: 1)
                )
        )
    }

    private func tabButton(_ tab: BobTab, icon: String, label: String) -> some View {
        Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.18)) { selected = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: selected == tab ? .semibold : .regular))
                    .foregroundStyle(selected == tab ? Color.bobAccent : Color.bobInk3)
                Text(label)
                    .font(.system(size: 10, weight: selected == tab ? .semibold : .regular))
                    .foregroundStyle(selected == tab ? Color.bobAccent : Color.bobInk3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .accessibilityLabel(label)
            .accessibilityAddTraits(selected == tab ? .isSelected : [])
        }
        .buttonStyle(.plain)
    }
}
