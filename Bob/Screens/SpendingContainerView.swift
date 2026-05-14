import SwiftUI

struct SpendingContainerView: View {
    @State private var selectedTab: SpendingPageTab = .spending

    var body: some View {
        ZStack(alignment: .top) {
            Color.bobBackground.ignoresSafeArea()

            Group {
                if selectedTab == .spending {
                    SpendingView()
                        .transition(.opacity)
                } else {
                    AnalyticsView()
                        .transition(.opacity)
                }
            }
            .padding(.top, 52)

            spendingTabPicker
                .padding(.top, 8)
                .padding(.horizontal, Spacing.pageMargin)
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }

    private var spendingTabPicker: some View {
        HStack(spacing: 8) {
            tabButton(.spending, title: "Spending")
            tabButton(.analytics, title: "Analytics")
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bobSurface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func tabButton(_ tab: SpendingPageTab, title: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.bobInk : Color.bobInk2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.92) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

private enum SpendingPageTab {
    case spending
    case analytics
}

