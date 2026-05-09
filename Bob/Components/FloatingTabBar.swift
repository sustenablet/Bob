import SwiftUI

enum BobTab: Int, CaseIterable {
    case home = 0
    case recurring
    case spending
    case more
}

/// Full-width flat dark tab bar — matches the reference design.
struct FloatingTabBar: View {
    @Binding var selected: BobTab

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.home,      icon: "square.grid.2x2.fill",  label: "Dashboard")
            tabItem(.recurring, icon: "arrow.clockwise",        label: "Recurring")
            tabItem(.spending,  icon: "chart.bar.fill",         label: "Spending")
            tabItem(.more,      icon: "line.3.horizontal",      label: "More")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(Color.bobDark)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.bobHairline)
                .frame(height: 0.5)
        }
    }

    private func tabItem(_ tab: BobTab, icon: String, label: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { selected = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: selected == tab ? .semibold : .regular))
                    .foregroundStyle(selected == tab ? Color.bobAccent : Color.bobDarkInk2)
                Text(label)
                    .font(.system(size: 10, weight: selected == tab ? .semibold : .regular))
                    .foregroundStyle(selected == tab ? Color.bobAccent : Color.bobDarkInk2)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(label)
            .accessibilityAddTraits(selected == tab ? .isSelected : [])
        }
        .buttonStyle(.plain)
    }
}
