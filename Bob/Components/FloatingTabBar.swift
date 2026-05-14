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
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .glassEffect(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 20, x: 0, y: 10)
    }

    private func tabButton(_ tab: BobTab, icon: String, label: String) -> some View {
        Button {
            HapticManager.selection()
            withAnimation(.easeOut(duration: 0.18)) { selected = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: selected == tab ? .semibold : .regular))
                    .foregroundStyle(selected == tab ? Color.bobInk : Color.bobInk2)
                Text(label)
                    .font(.system(size: 10, weight: selected == tab ? .semibold : .regular))
                    .foregroundStyle(selected == tab ? Color.bobInk : Color.bobInk2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selected == tab ? Color.bobSurface.opacity(0.45) : Color.clear)
            )
            .contentShape(Rectangle())
            .accessibilityLabel(label)
            .accessibilityAddTraits(selected == tab ? .isSelected : [])
        }
        .buttonStyle(.plain)
    }
}
