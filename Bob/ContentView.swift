import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: BobTab = .home
    @State private var previousTab: BobTab = .home
    @State private var isAddingTransaction = false

    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]
    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content with crossfade transition
            ZStack {
                tabView(for: .home)     .opacity(selectedTab == .home      ? 1 : 0)
                tabView(for: .goals)    .opacity(selectedTab == .goals     ? 1 : 0)
                tabView(for: .recurring).opacity(selectedTab == .recurring  ? 1 : 0)
                tabView(for: .analytics).opacity(selectedTab == .analytics  ? 1 : 0)
                tabView(for: .activity) .opacity(selectedTab == .activity   ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.18), value: selectedTab)
            .ignoresSafeArea(.container, edges: .bottom)

            bottomBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .background(Color.bobBackground.ignoresSafeArea())
        .sheet(isPresented: $isAddingTransaction) {
            AddTransactionSheet(currencyCode: currencyCode, expenseToEdit: nil)
        }
    }

    // Keep all tab views alive (no state loss on switch)
    @ViewBuilder
    private func tabView(for tab: BobTab) -> some View {
        switch tab {
        case .home:
            HomeView(onSwitchTab: { switchTab(to: $0) })
        case .goals:
            GoalsView()
        case .recurring:
            RecurringTransactionsView()
        case .analytics:
            AnalyticsView()
        case .activity:
            NavigationStack { TransactionsListView() }
        }
    }

    private func switchTab(to tab: BobTab) {
        guard tab != selectedTab else { return }
        HapticManager.selection()
        withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
    }

    private var bottomBar: some View {
        HStack(alignment: .center) {
            FloatingTabBar(selected: Binding(
                get: { selectedTab },
                set: { switchTab(to: $0) }
            ))
            Spacer(minLength: 12)
            AddFAB { isAddingTransaction = true }
        }
    }
}
