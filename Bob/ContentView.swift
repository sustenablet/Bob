import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: BobTab = .home

    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]
    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            ZStack {
                tabView(for: .home)     .opacity(selectedTab == .home      ? 1 : 0)
                tabView(for: .recurring).opacity(selectedTab == .recurring  ? 1 : 0)
                tabView(for: .spending) .opacity(selectedTab == .spending   ? 1 : 0)
                tabView(for: .more)     .opacity(selectedTab == .more       ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.18), value: selectedTab)
            .ignoresSafeArea(.container, edges: .bottom)

            // Floating tab bar (no FAB — add transaction lives in HomeView)
            FloatingTabBar(
                selected: Binding(get: { selectedTab }, set: { switchTab(to: $0) })
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color.bobBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func tabView(for tab: BobTab) -> some View {
        switch tab {
        case .home:
            HomeView(onSwitchTab: { switchTab(to: $0) })
        case .recurring:
            RecurringTransactionsView()
        case .spending:
            SpendingContainerView()
        case .more:
            MoreView()
        }
    }

    private func switchTab(to tab: BobTab) {
        guard tab != selectedTab else { return }
        HapticManager.selection()
        withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
    }
}
