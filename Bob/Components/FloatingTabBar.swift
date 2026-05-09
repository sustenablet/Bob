import SwiftUI

enum BobTab: Int, CaseIterable {
    case home = 0
    case recurring
    case spending
    case more       // still exists for gear-icon navigation; not shown in tab bar
}

/// Full-width flat dark tab bar — 3 tabs + center "+" action button.
struct FloatingTabBar: View {
    @Binding var selected: BobTab
    var onAdd: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.home,      icon: "square.grid.2x2.fill", label: "Dashboard")
            tabItem(.recurring, icon: "arrow.clockwise",       label: "Recurring")
            addButton
            tabItem(.spending,  icon: "chart.bar.fill",        label: "Spending")
            // "More" is intentionally omitted from the visible tab bar
            // It remains navigable via gear icons on each screen
            Color.clear.frame(maxWidth: .infinity) // balance right side
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(Color.bobDark)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.bobHairline).frame(height: 0.5)
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

    private var addButton: some View {
        Button(action: {
            HapticManager.medium()
            onAdd()
        }) {
            ZStack {
                Circle()
                    .fill(Color.bobAccent)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.bobAccent.opacity(0.35), radius: 8, x: 0, y: 4)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))
            }
        }
        .buttonStyle(AddButtonPressStyle())
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Add transaction")
    }
}

private struct AddButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
