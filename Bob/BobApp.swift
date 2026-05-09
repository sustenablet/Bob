import SwiftUI
import SwiftData

@main
struct BobApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("showOnboarding") private var showOnboarding = true
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Expense.self,
            ExpenseCategory.self,
            BudgetSettings.self,
            Goal.self,
            GoalContribution.self,
            RecurringTransaction.self,
            QuickAddTemplate.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            BobApp.seedIfNeeded(container: container)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding || !showOnboarding {
                ContentView()
                    .onAppear {
                        RecurringProcessor.shared.processDueRecurrings(
                            context: sharedModelContainer.mainContext
                        )
                    }
            } else {
                OnboardingView(isPresented: $showOnboarding)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private static func seedIfNeeded(container: ModelContainer) {
        let context = container.mainContext

        seedCategories(context: context, kind: .expense, defaults: ExpenseCategory.defaultsExpense)
        seedCategories(context: context, kind: .income,  defaults: ExpenseCategory.defaultsIncome)

        let settingsCount = (try? context.fetchCount(FetchDescriptor<BudgetSettings>())) ?? 0
        if settingsCount == 0 {
            context.insert(BudgetSettings())
        }

        try? context.save()
    }

    @MainActor
    private static func seedCategories(
        context: ModelContext,
        kind: TransactionKind,
        defaults: [(name: String, symbol: String)]
    ) {
        let kindRaw = kind.rawValue
        let descriptor = FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate { $0.kindRaw == kindRaw }
        )
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        for (index, entry) in defaults.enumerated() {
            context.insert(
                ExpenseCategory(
                    name: entry.name,
                    sfSymbol: entry.symbol,
                    sortOrder: index,
                    kind: kind
                )
            )
        }
    }
}
