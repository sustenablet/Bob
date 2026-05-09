import SwiftUI

enum BobTab: Int, CaseIterable {
    case home = 0
    case goals
    case recurring
    case analytics
}

/// Floating Liquid Glass pill tab bar — four icon-only tabs.
struct FloatingTabBar: View {
    @Binding var selected: BobTab

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.home,      systemImage: "house.fill")
            tabButton(.goals,     systemImage: "target")
            tabButton(.recurring, systemImage: "arrow.repeat")
            tabButton(.analytics, systemImage: "chart.bar.fill")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .glassEffect(in: Capsule())
        .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 6)
    }

    private func tabButton(_ tab: BobTab, systemImage: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { selected = tab }
        } label: {
            ZStack {
                if selected == tab {
                    Circle()
                        .fill(Color.bobInk.opacity(0.10))
                        .frame(width: 44, height: 44)
                }
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selected == tab ? Color.bobInk : Color.bobInk2)
            }
            .frame(width: 54, height: 46)
            .accessibilityLabel(tabLabel(for: tab))
            .accessibilityAddTraits(selected == tab ? .isSelected : [])
        }
        .buttonStyle(.plain)
    }

    private func tabLabel(for tab: BobTab) -> String {
        switch tab {
        case .home:      return "Home"
        case .goals:     return "Savings Goals"
        case .recurring: return "Recurring"
        case .analytics: return "Analytics"
        }
    }
}
