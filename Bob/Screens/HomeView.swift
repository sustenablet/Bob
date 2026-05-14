import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    var onSwitchTab: ((BobTab) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse),
                  SortDescriptor(\Expense.createdAt, order: .reverse)])
    private var allExpenses: [Expense]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: \RecurringTransaction.nextDueDate) private var recurrings: [RecurringTransaction]

    @AppStorage("userName") private var userName: String = ""
    @AppStorage("petName") private var petName: String = "Buddy"
    @State private var editingExpense: Expense?
    @State private var isAddingTransaction = false
    @State private var showingPetDetail = false
    @State private var showAllTransactions = false

    // MARK: – Core data

    private var settings: BudgetSettings? { settingsList.first }
    private var currencyCode: String { settings?.currencyCode ?? "USD" }
    private var monthlyBudget: Decimal { settings?.monthlyBudget ?? 0 }

    private var monthBounds: (start: Date, end: Date) { MonthSummary.currentMonthBounds() }

    private var monthTransactions: [Expense] {
        allExpenses.filter { $0.date >= monthBounds.start && $0.date <= monthBounds.end }
    }

    private var monthExpensesTotal: Decimal {
        monthTransactions.filter { $0.kind == .expense }.reduce(.zero) { $0 + $1.amount }
    }

    private var monthIncome: Decimal {
        monthTransactions.filter { $0.kind == .income }.reduce(.zero) { $0 + $1.amount }
    }

    private var lastMonthExpensesTotal: Decimal {
        let cal = Calendar.current
        guard let lastStart = cal.date(byAdding: .month, value: -1, to: monthBounds.start) else { return 0 }
        return allExpenses
            .filter { $0.kind == .expense && $0.date >= lastStart && $0.date < monthBounds.start }
            .reduce(.zero) { $0 + $1.amount }
    }

    private var momDiff: Decimal { lastMonthExpensesTotal - monthExpensesTotal }
    private var momIsPositive: Bool { momDiff >= 0 }

    // Cumulative daily spend for chart
    private var cumulativeSpend: [(day: Int, amount: Decimal)] {
        let cal = Calendar.current
        var dict: [Int: Decimal] = [:]
        for tx in monthTransactions where tx.kind == .expense {
            let d = cal.component(.day, from: tx.date)
            dict[d, default: 0] += tx.amount
        }
        let days = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        var cum: Decimal = 0
        return (1...days).map { day in
            cum += dict[day] ?? 0
            return (day: day, amount: cum)
        }
    }

    // Next upcoming recurring
    private var nextRecurring: RecurringTransaction? {
        recurrings.filter { $0.isActive }.sorted { $0.nextDueDate < $1.nextDueDate }.first
    }

    private var daysToNextRecurring: Int {
        guard let r = nextRecurring else { return 0 }
        return max(Calendar.current.dateComponents([.day], from: Date(), to: r.nextDueDate).day ?? 0, 0)
    }

    // Upcoming (next 30 days)
    private var upcomingItems: [RecurringTransaction] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return recurrings.filter { $0.isActive && $0.nextDueDate <= cutoff }
            .sorted { $0.nextDueDate < $1.nextDueDate }
            .prefix(6).map { $0 }
    }

    private var todaySpend: Decimal {
        allExpenses.filter { $0.kind == .expense && Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.amount }
    }

    private var weekSpend: Decimal {
        let cal = Calendar.current
        let wday = cal.component(.weekday, from: Date())
        let startOfWeek = cal.date(byAdding: .day, value: -(wday - 1), to: cal.startOfDay(for: Date())) ?? Date()
        return allExpenses.filter { $0.kind == .expense && $0.date >= startOfWeek }.reduce(0) { $0 + $1.amount }
    }

    private var savingsRate: Double {
        let inc = (monthIncome as NSDecimalNumber).doubleValue
        guard inc > 0 else { return 0 }
        let exp = (monthExpensesTotal as NSDecimalNumber).doubleValue
        return max(((inc - exp) / inc) * 100, 0)
    }

    private var topMonthCategories: [(name: String, symbol: String, amount: Decimal)] {
        var dict: [String: (symbol: String, amount: Decimal)] = [:]
        for tx in monthTransactions where tx.kind == .expense {
            let cat = tx.category?.name ?? "Other"
            let sym = tx.category?.sfSymbol ?? "circle.dashed"
            let ex = dict[cat]
            dict[cat] = (ex?.symbol ?? sym, (ex?.amount ?? 0) + tx.amount)
        }
        return dict.map { (name: $0.key, symbol: $0.value.symbol, amount: $0.value.amount) }
            .sorted { $0.amount > $1.amount }.prefix(5).map { $0 }
    }

    private var last6MonthsData: [(label: String, income: Decimal, expenses: Decimal)] {
        let cal = Calendar.current
        let df = DateFormatter(); df.dateFormat = "MMM"
        return (0..<6).reversed().map { offset -> (String, Decimal, Decimal) in
            guard let date = cal.date(byAdding: .month, value: -offset, to: Date()),
                  let start = cal.date(from: cal.dateComponents([.year, .month], from: date)),
                  let end   = cal.date(byAdding: .month, value: 1, to: start) else { return ("", 0, 0) }
            let txns = allExpenses.filter { $0.date >= start && $0.date < end }
            let inc  = txns.filter { $0.kind == .income }.reduce(Decimal(0)) { $0 + $1.amount }
            let exp  = txns.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
            return (df.string(from: date), inc, exp)
        }
    }

    // MARK: – Body

    var body: some View {
        ZStack {
            dashboardBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    dashboardHero
                    dashboardPromoCard
                        .padding(.top, 22)
                    recentTransactionsSection
                        .padding(.top, 20)
                    monthlySpendCard
                        .padding(.top, 20)
                    Spacer().frame(height: 120)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $isAddingTransaction) {
            AddTransactionSheet(currencyCode: currencyCode, expenseToEdit: nil)
        }
        .sheet(item: $editingExpense) { expense in
            AddTransactionSheet(currencyCode: currencyCode, expenseToEdit: expense)
        }
        .sheet(isPresented: $showingPetDetail) {
            PetDetailView(
                score: petScore,
                petName: petName
            )
        }
        .sheet(isPresented: $showAllTransactions) {
            NavigationStack {
                TransactionsListView()
            }
        }
    }

    // MARK: – Dashboard layout

    private var dashboardBackground: some View {
        ZStack {
            Color.bobBackground
            LinearGradient(
                colors: [
                    Color.bobAccent.opacity(0.18),
                    Color.bobAccent.opacity(0.08),
                    Color.bobBackground
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.58)
            )
            .blur(radius: 8)

            RadialGradient(
                colors: [
                    Color.bobAccent.opacity(0.12),
                    Color.clear
                ],
                center: UnitPoint(x: 0.15, y: 0.16),
                startRadius: 20,
                endRadius: 420
            )
        }
    }

    private var dashboardHero: some View {
        VStack(spacing: 0) {
            topControlRow
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.top, 12)

            VStack(spacing: 10) {
                Text(heroTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.bobInk2)
                    .padding(.top, 22)

                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(CurrencyFormatter.string(heroAmount, code: currencyCode))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.bobInk)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                    if heroSecondaryText != nil {
                        Text(heroSecondaryText ?? "")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bobInk2)
                            .padding(.leading, 8)
                    }
                }
                .contentTransition(.numericText())

                Button {
                    showAllTransactions = true
                } label: {
                    Text(heroButtonTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.bobInk)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(
                            Capsule()
                                .fill(Color.bobSurface.opacity(0.9))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.bobHairline, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 10)

                HStack(spacing: 10) {
                    pageDot(active: true)
                    pageDot(active: heroCardContext == .budget)
                    pageDot(active: heroCardContext == .goals)
                }
                .padding(.top, 24)
            }

            shortcutRow
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.top, 22)
        }
    }

    private var topControlRow: some View {
        HStack(spacing: 12) {
            Button { showingPetDetail = true } label: {
                ZStack(alignment: .topTrailing) {
                    MascotCharacterView(
                        state: petScore.state,
                        size: 34
                    )
                    .frame(width: 46, height: 46)
                }
                .glassEffect(in: Circle())
            }
            .buttonStyle(.plain)

            Button { showAllTransactions = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.bobInk2)
                    Text("Search")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.bobInk2)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(height: 46)
                .glassEffect(in: Capsule())
            }
            .buttonStyle(.plain)

            compactHeroIcon(systemName: "chart.bar.fill", action: { onSwitchTab?(.spending) })
            compactHeroIcon(systemName: "list.bullet.rectangle.fill", action: { showAllTransactions = true })
        }
    }

    private func compactHeroIcon(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.bobInk2)
            }
            .frame(width: 46, height: 46)
            .glassEffect(in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func pageDot(active: Bool) -> some View {
        Circle()
            .fill(active ? Color.bobInk.opacity(0.7) : Color.bobInk.opacity(0.2))
            .frame(width: 7, height: 7)
    }

    private var shortcutRow: some View {
        HStack(alignment: .top, spacing: 12) {
            dashboardShortcut(
                icon: "plus",
                label: "Add transaction",
                action: { isAddingTransaction = true }
            )
            dashboardShortcut(
                icon: "dollarsign.circle",
                label: "Transactions",
                action: { showAllTransactions = true }
            )
            dashboardShortcut(
                icon: "sparkles",
                label: "Companion",
                action: { showingPetDetail = true }
            )
            dashboardShortcut(
                icon: "target",
                label: "Goals",
                action: { onSwitchTab?(.more) }
            )
        }
    }

    private func dashboardShortcut(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.bobSurface.opacity(0.9))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.bobInk)
                }
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .lineLimit(2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var dashboardPromoCard: some View {
        Button { showingPetDetail = true } label: {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(petName) is watching your money")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.bobInk)
                        .multilineTextAlignment(.leading)
                    Text(companionStatusLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bobInk2)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                Spacer(minLength: 8)

                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.bobSurface2.opacity(0.75))
                        .frame(width: 96, height: 96)
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.bobHairline, lineWidth: 1)
                        )
                    MascotCharacterView(
                        state: petScore.state,
                        size: 84
                    )
                    .frame(width: 96, height: 96)

                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.bobInk3)
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.bobSurface.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.bobHairline, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.pageMargin)
    }

    private var budgetLeftText: String {
        guard monthlyBudget > 0 else { return "—" }
        return CurrencyFormatter.compact(monthlyBudget - monthExpensesTotal, code: currencyCode)
    }

    private var promoTitle: String {
        switch petScore.state {
        case .thriving, .celebrating:
            return "Everything is in rhythm"
        case .content:
            return "You’re tracking well"
        case .neutral:
            return "Keep the pace steady"
        case .worried:
            return "A few things need attention"
        case .struggling:
            return "Reset the month with one move"
        case .sleeping:
            return "Your companion is waiting"
        }
    }

    private enum DashboardHeroContext {
        case cashflow
        case budget
        case goals
    }

    private var heroCardContext: DashboardHeroContext {
        let activeGoals = goals.filter { $0.isActive && !$0.isCompleted }
        if !activeGoals.isEmpty { return .goals }
        if monthlyBudget > 0 { return .budget }
        return .cashflow
    }

    private var heroAmount: Decimal {
        switch heroCardContext {
        case .cashflow:
            return monthIncome > 0 ? (monthIncome - monthExpensesTotal) : monthExpensesTotal
        case .budget:
            return monthlyBudget - monthExpensesTotal
        case .goals:
            return goals.filter { $0.isActive && !$0.isCompleted }.reduce(.zero) { $0 + $1.totalSaved }
        }
    }

    private var heroTitle: String {
        switch heroCardContext {
        case .cashflow:
            return monthIncome > 0 ? "Available this month" : "Spent this month"
        case .budget:
            return "Budget remaining"
        case .goals:
            return "Saved toward goals"
        }
    }

    private var heroSecondaryText: String? {
        switch heroCardContext {
        case .cashflow:
            if monthIncome > 0, lastMonthExpensesTotal > 0 {
                return momIsPositive ? "ahead" : "tight"
            }
            return nil
        case .budget:
            return monthlyBudget > 0 ? "left" : nil
        case .goals:
            let count = goals.filter { $0.isActive && !$0.isCompleted }.count
            return count > 0 ? "\(count)" : nil
        }
    }

    private var heroButtonTitle: String {
        switch heroCardContext {
        case .cashflow: return "Transactions"
        case .budget: return "Budget"
        case .goals: return "Goals"
        }
    }

    // MARK: – Pet card

    private var petScore: PetHealthScore {
        let budgetUsage: Double
        let hasBudget = monthlyBudget > 0
        if hasBudget {
            budgetUsage = Double((monthExpensesTotal / monthlyBudget) as NSDecimalNumber)
        } else {
            budgetUsage = 0
        }

        let activeGoals = goals.filter { $0.isActive && !$0.isCompleted }
        let hasGoals = !activeGoals.isEmpty
        let totalTarget = activeGoals.reduce(Decimal(0)) { $0 + $1.targetAmount }
        let totalSaved  = activeGoals.reduce(Decimal(0)) { $0 + $1.totalSaved }
        let savingsProgress: Double = totalTarget > 0
            ? Double((totalSaved / totalTarget) as NSDecimalNumber)
            : 0

        return PetHealthScore.compute(
            budgetUsage: budgetUsage,
            hasBudget: hasBudget,
            savingsProgress: savingsProgress,
            hasGoals: hasGoals
        )
    }

    private var petCardSection: some View {
        PetCard(
            score: petScore,
            petName: petName,
            statusLine: companionStatusLine,
            onTap: { showingPetDetail = true }
        )
    }

    private var companionStatusLine: String {
        if monthlyBudget > 0 {
            let remaining = monthlyBudget - monthExpensesTotal
            if remaining < 0 {
                return "You are over budget this month."
            }
            if remaining <= monthlyBudget * Decimal(string: "0.2")! {
                return "Only \(CurrencyFormatter.string(remaining, code: currencyCode)) left in this month's budget."
            }
        }

        let activeGoals = goals.filter { $0.isActive && !$0.isCompleted }
        if let nearestGoal = activeGoals.sorted(by: { $0.daysLeft < $1.daysLeft }).first {
            let remaining = max(nearestGoal.targetAmount - nearestGoal.totalSaved, 0)
            return "\(CurrencyFormatter.string(remaining, code: currencyCode)) left for \(nearestGoal.name)."
        }

        return "Keep logging to grow your companion."
    }

    // MARK: – Legacy sections
    private var quickStatsStrip: some View {
        HStack(spacing: 10) {
            statTile(
                label: "Today",
                value: todaySpend > 0 ? CurrencyFormatter.string(todaySpend, code: currencyCode) : "—",
                icon: "sun.max.fill",
                iconColor: .bobHex(0xFFB74D)
            )
            statTile(
                label: "This Week",
                value: weekSpend > 0 ? CurrencyFormatter.compact(weekSpend, code: currencyCode) : "—",
                icon: "calendar.badge.clock",
                iconColor: Color.bobChartBlue
            )
            statTile(
                label: "Savings Rate",
                value: monthIncome > 0 ? String(format: "%.0f%%", savingsRate) : "—",
                icon: savingsRate >= 20 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                iconColor: savingsRate >= 20 ? Color.bobGreen : Color.bobDebit
            )
        }
        .padding(.horizontal, Spacing.pageMargin)
    }

    private func statTile(label: String, value: String, icon: String, iconColor: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.bobInk)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.bobInk2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bobSurface.opacity(0.8))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }
        }
    }

    // MARK: – Top categories section
    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionHeader("TOP CATEGORIES")

            if topMonthCategories.isEmpty {
                Text("No expenses this month yet")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bobInk2)
                    .padding(.horizontal, Spacing.pageMargin)
            } else {
                let catTotal = topMonthCategories.reduce(Decimal(0)) { $0 + $1.amount }
                VStack(spacing: 0) {
                    ForEach(Array(topMonthCategories.enumerated()), id: \.element.name) { idx, cat in
                        categorySnapshotRow(cat: cat, idx: idx, total: catTotal)
                        if idx < topMonthCategories.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 1)
                                .padding(.leading, 58)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.bobSurface.opacity(0.8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, Spacing.pageMargin)
            }
        }
    }

    private let homePalette: [Color] = [
        Color.bobHex(0xE0413B), Color.bobHex(0x4FC3F7), Color.bobHex(0xFFB74D),
        Color.bobHex(0x81C784), Color.bobHex(0xBA68C8)
    ]

    private func categorySnapshotRow(cat: (name: String, symbol: String, amount: Decimal), idx: Int, total: Decimal) -> some View {
        let color = homePalette[idx % homePalette.count]
        let pct = total > 0 ? Double((cat.amount / total) as NSDecimalNumber) : 0

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: cat.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(cat.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bobInk)
                    Spacer()
                    Text(CurrencyFormatter.string(cat.amount, code: currencyCode))
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.bobInk)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.bobSurface2)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geo.size.width * pct, height: 4)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pct)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, 13)
    }

    // MARK: – Cash flow snapshot (6-month mini bars)
    private var cashFlowSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionHeader("6-MONTH CASH FLOW")

            VStack(alignment: .leading, spacing: Spacing.m) {
                let maxVal = max(
                    last6MonthsData.map { ($0.income as NSDecimalNumber).doubleValue }.max() ?? 1,
                    last6MonthsData.map { ($0.expenses as NSDecimalNumber).doubleValue }.max() ?? 1,
                    1
                )

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(last6MonthsData.enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 4) {
                            HStack(alignment: .bottom, spacing: 2) {
                                let incH = max(CGFloat((item.income as NSDecimalNumber).doubleValue / maxVal) * 72, 4)
                                let expH = max(CGFloat((item.expenses as NSDecimalNumber).doubleValue / maxVal) * 72, 4)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.bobGreen.opacity(0.75))
                                    .frame(width: 12, height: incH)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.bobDebit.opacity(0.75))
                                    .frame(width: 12, height: expH)
                            }
                            Text(item.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.bobInk3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 90)

                HStack(spacing: 16) {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.bobGreen.opacity(0.75)).frame(width: 12, height: 4)
                        Text("Income").font(.system(size: 11)).foregroundStyle(Color.bobInk2)
                    }
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.bobDebit.opacity(0.75)).frame(width: 12, height: 4)
                        Text("Expenses").font(.system(size: 11)).foregroundStyle(Color.bobInk2)
                    }
                    Spacer()
                }
            }
            .padding(Spacing.m)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.bobSurface.opacity(0.8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
            }
            .padding(.horizontal, Spacing.pageMargin)
        }
    }

    // MARK: – Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { onSwitchTab?(.more) } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.bobInk2)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(todayLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bobInk)

            Spacer()

            // Add transaction button
            Button { isAddingTransaction = true } label: {
                ZStack {
                    Circle()
                        .fill(Color.bobAccent)
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: Date())
    }

    // MARK: – Hero carousel (swipeable cards)

    @State private var heroPage: Int = 0

    private var heroCarousel: some View {
        VStack(spacing: 8) {
            TabView(selection: $heroPage) {
                heroCard
                    .padding(.horizontal, Spacing.pageMargin)
                    .tag(0)
                budgetCard
                    .padding(.horizontal, Spacing.pageMargin)
                    .tag(1)
                savingsCard
                    .padding(.horizontal, Spacing.pageMargin)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 220)

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { idx in
                    Capsule()
                        .fill(heroPage == idx ? Color.bobAccent : Color.bobSurface2)
                        .frame(width: heroPage == idx ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: heroPage)
                }
            }
        }
    }

    // Card 2: Budget status
    private var budgetCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Budget Status").font(.system(size: 13)).foregroundStyle(Color.bobInk2)
                    Spacer()
                    if monthlyBudget > 0 {
                        let remaining = monthlyBudget - monthExpensesTotal
                        Text(remaining >= 0 ? "\(CurrencyFormatter.string(remaining, code: currencyCode)) left" : "Over budget")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(remaining >= 0 ? Color.bobGreen : Color.bobDebit)
                    }
                }
                if monthlyBudget > 0 {
                    let prog = min(Double((monthExpensesTotal / monthlyBudget) as NSDecimalNumber), 1.0)
                    let color: Color = prog >= 1.0 ? .bobDebit : prog >= 0.8 ? .orange : .bobGreen
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6).fill(Color.bobSurface2).frame(height: 10)
                            RoundedRectangle(cornerRadius: 6).fill(color)
                                .frame(width: geo.size.width * prog, height: 10)
                                .animation(.spring(response: 0.5), value: prog)
                        }
                    }.frame(height: 10)
                    HStack {
                        Text("\(Int(prog * 100))% spent").font(.system(size: 11)).foregroundStyle(Color.bobInk2)
                        Spacer()
                        Text(CurrencyFormatter.string(monthlyBudget, code: currencyCode) + " budget")
                            .font(.system(size: 11)).foregroundStyle(Color.bobInk2)
                    }
                } else {
                    Text("No budget set — go to Settings to set one")
                        .font(.system(size: 13)).foregroundStyle(Color.bobInk2)
                }
                Spacer()
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spent").font(.system(size: 11)).foregroundStyle(Color.bobInk2)
                        Text(CurrencyFormatter.string(monthExpensesTotal, code: currencyCode))
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(Color.bobDebit).monospacedDigit()
                    }
                    Divider().frame(height: 30).background(Color.bobHairline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Income").font(.system(size: 11)).foregroundStyle(Color.bobInk2)
                        Text(CurrencyFormatter.string(monthIncome, code: currencyCode))
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(Color.bobGreen).monospacedDigit()
                    }
                    Spacer()
                }
            }
            .padding(Spacing.m)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // Card 3: Savings snapshot
    private var savingsCard: some View {
        let activeGoals = goals.filter { $0.isActive && !$0.isCompleted }
        let totalSaved  = activeGoals.reduce(Decimal(0)) { $0 + $1.totalSaved }
        let totalTarget = activeGoals.reduce(Decimal(0)) { $0 + $1.targetAmount }
        let progress    = totalTarget > 0 ? min(Double((totalSaved / totalTarget) as NSDecimalNumber), 1.0) : 0.0

        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Savings Goals").font(.system(size: 13)).foregroundStyle(Color.bobInk2)
                    Spacer()
                    Text("\(activeGoals.count) active").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bobAccent)
                }
                Text(CurrencyFormatter.string(totalSaved, code: currencyCode))
                    .font(.system(size: 28, weight: .bold)).foregroundStyle(Color.bobInk)
                Text("of \(CurrencyFormatter.string(totalTarget, code: currencyCode)) target")
                    .font(.system(size: 13)).foregroundStyle(Color.bobInk2)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(Color.bobSurface2).frame(height: 8)
                        RoundedRectangle(cornerRadius: 6).fill(Color.bobAccent)
                            .frame(width: geo.size.width * progress, height: 8)
                            .animation(.spring(response: 0.5), value: progress)
                    }
                }.frame(height: 8)

                HStack {
                    Text("\(Int(progress * 100))% overall").font(.system(size: 11)).foregroundStyle(Color.bobInk2)
                    Spacer()
                    if activeGoals.isEmpty {
                        Text("No goals yet").font(.system(size: 11)).foregroundStyle(Color.bobInk2)
                    } else if let nearest = activeGoals.sorted(by: { $0.deadline < $1.deadline }).first {
                        Text("Next: \(nearest.name) in \(nearest.daysLeft)d")
                            .font(.system(size: 11)).foregroundStyle(Color.bobInk2).lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(Spacing.m)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: – Hero card

    private var heroCard: some View {
        VStack(spacing: 0) {
            // Top section
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current spend this month")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.bobInk2)
                        Text(CurrencyFormatter.string(monthExpensesTotal, code: currencyCode))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(Color.bobInk)
                            .contentTransition(.numericText())
                    }

                    Spacer()

                    if lastMonthExpensesTotal > 0 {
                        HStack(spacing: 5) {
                            Image(systemName: momIsPositive ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(momIsPositive ? Color.bobAccent : Color.bobDebit)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(CurrencyFormatter.string(abs(momDiff as NSDecimalNumber as Decimal), code: currencyCode))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(momIsPositive ? Color.bobAccent : Color.bobDebit)
                                Text(momIsPositive ? "below last month" : "above last month")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.bobInk2)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color.bobSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.top, Spacing.m)

            // Spend chart
            spendChart
                .padding(.top, Spacing.s)
                .padding(.horizontal, Spacing.m)

            // Footer row
            HStack(spacing: 8) {
                Image(systemName: "banknote")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bobAccent)
                if let next = nextRecurring {
                    Text("\(next.name) in \(daysToNextRecurring) day\(daysToNextRecurring == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.bobInk)
                } else if monthlyBudget > 0 {
                    let remaining = monthlyBudget - monthExpensesTotal
                    Text(remaining >= 0
                         ? "\(CurrencyFormatter.string(remaining, code: currencyCode)) budget remaining"
                         : "Over budget by \(CurrencyFormatter.string(abs(remaining as NSDecimalNumber as Decimal), code: currencyCode))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(remaining >= 0 ? Color.bobInk : Color.bobDebit)
                } else {
                    Text("Tap + to log a transaction")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.bobInk2)
                }
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bobInk2)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 14)
            .background(Color.bobSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, Spacing.m)
            .padding(.bottom, Spacing.m)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: – Spend chart

    private var spendChart: some View {
        let data = cumulativeSpend.filter { $0.amount > 0 }
        let maxAmt = max(cumulativeSpend.map { ($0.amount as NSDecimalNumber).doubleValue }.max() ?? 1, 1)
        let budget = (monthlyBudget as NSDecimalNumber).doubleValue
        let showBudget = monthlyBudget > 0

        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let days = cumulativeSpend.count

            ZStack {
                // Budget line
                if showBudget {
                    let by = h - CGFloat(budget / max(maxAmt, budget) * 0.9) * h - h * 0.05
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: by))
                        p.addLine(to: CGPoint(x: w, y: by))
                    }
                    .stroke(Color.bobHairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }

                // Area fill
                if data.count > 1 {
                    areaPath(data: data, w: w, h: h, days: days, maxAmt: maxAmt)
                        .fill(LinearGradient(
                            colors: [Color.bobChartBlue.opacity(0.4), Color.bobChartBlue.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        ))

                    // Line
                    linePath(data: data, w: w, h: h, days: days, maxAmt: maxAmt)
                        .stroke(Color.bobChartBlue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // End dot
                    if let last = data.last {
                        let x = CGFloat(last.day - 1) / CGFloat(days - 1) * w
                        let y = h - CGFloat((last.amount as NSDecimalNumber).doubleValue / maxAmt) * h * 0.9 - h * 0.05
                        Circle()
                            .fill(Color.bobChartBlue)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                } else {
                    // No data placeholder
                    Text("No spending data yet")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bobInk2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(height: 90)
    }

    private func linePath(data: [(day: Int, amount: Decimal)], w: CGFloat, h: CGFloat, days: Int, maxAmt: Double) -> Path {
        var path = Path()
        for (i, pt) in data.enumerated() {
            let x = CGFloat(pt.day - 1) / CGFloat(days - 1) * w
            let y = h - CGFloat((pt.amount as NSDecimalNumber).doubleValue / maxAmt) * h * 0.9 - h * 0.05
            i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }

    private func areaPath(data: [(day: Int, amount: Decimal)], w: CGFloat, h: CGFloat, days: Int, maxAmt: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h))
        for pt in data {
            let x = CGFloat(pt.day - 1) / CGFloat(days - 1) * w
            let y = h - CGFloat((pt.amount as NSDecimalNumber).doubleValue / maxAmt) * h * 0.9 - h * 0.05
            path.addLine(to: CGPoint(x: x, y: y))
        }
        if let last = data.last {
            let x = CGFloat(last.day - 1) / CGFloat(days - 1) * w
            path.addLine(to: CGPoint(x: x, y: h))
        }
        path.closeSubpath()
        return path
    }

    // MARK: – Upcoming section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionHeader("UPCOMING")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(upcomingItems) { item in
                        upcomingCard(item)
                    }
                }
                .padding(.horizontal, Spacing.pageMargin)
            }
        }
    }

    private func upcomingCard(_ item: RecurringTransaction) -> some View {
        let isIncome = item.kind == .income
        let color: Color = isIncome ? Color.bobAccent : Color.bobDebit
        let cal = Calendar.current
        let days = max(cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
            to: cal.startOfDay(for: item.nextDueDate)).day ?? 0, 0)

        return VStack(spacing: 10) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }

            VStack(spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                    .lineLimit(1)
                Text((isIncome ? "+" : "") + CurrencyFormatter.string(item.amount, code: currencyCode))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
            }

            Text(days == 0 ? "TODAY" : "IN \(days) DAYS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(days == 0 ? Color.bobDebit : Color.bobInk2)
                .tracking(0.5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(width: 110)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: – Recent transactions

    private var recentTransactionsSection: some View {
        Button { onSwitchTab?(.spending) } label: {
            if !recentExpenses.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(recentExpenses.enumerated()), id: \.element.id) { idx, tx in
                        transactionRow(tx)
                        if idx < recentExpenses.count - 1 {
                            Spacer().frame(height: 28)
                        }
                    }

                    Text("See all")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.bobInk)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                }
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.bobSurface.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.bobHairline, lineWidth: 1)
                        )
                )
                .padding(.horizontal, Spacing.pageMargin)
            } else {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.bobSurface2.opacity(0.9))
                            .frame(width: 44, height: 44)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.bobInk)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No recent transactions")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.bobInk)
                        Text("Open analytics to review your spending once activity appears.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.bobInk2)
                    }
                    Spacer()
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.bobSurface.opacity(0.9))
                )
                .padding(.horizontal, Spacing.pageMargin)
            }
        }
        .buttonStyle(.plain)
    }

    private var recentExpenses: [Expense] {
        Array(allExpenses.prefix(2))
    }

    private func transactionRow(_ tx: Expense) -> some View {
        let isIncome = tx.kind == .income
        let amount = CurrencyFormatter.string(tx.amount, code: currencyCode)
        let display = isIncome ? "+\(amount)" : "-\(amount)"
        let amountColor: Color = isIncome ? .bobGreen : .bobInk

        return HStack(alignment: .top, spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(isIncome ? Color.bobGreen : Color.bobHex(0x7AD744))
                    .frame(width: 44, height: 44)
                Image(systemName: tx.category?.sfSymbol ?? "circle.dashed")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle(for: tx))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                    .lineLimit(2)
                Text(relativeDate(tx.date))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.bobInk2)
            }

            Spacer()

            Text(display)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(amountColor)
        }
        .contentShape(Rectangle())
    }

    // MARK: – Monthly spend card

    private var monthlySpendCard: some View {
        Button { onSwitchTab?(.spending) } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("Spent this month")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)

                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    Text(CurrencyFormatter.string(monthExpensesTotal, code: currencyCode))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.bobInk)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if lastMonthExpensesTotal > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: momIsPositive ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(CurrencyFormatter.string(abs(momDiff as NSDecimalNumber as Decimal), code: currencyCode))
                                .font(.system(size: 15, weight: .bold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(momIsPositive ? Color.bobGreen.opacity(0.9) : Color.bobDebit.opacity(0.95))
                    }

                    Spacer(minLength: 4)

                    Text(CurrencyFormatter.compact(projectedMonthSpend, code: currencyCode))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.bobInk2)
                        .monospacedDigit()
                }
                .padding(.top, 4)

                monthlySpendGraph
                    .padding(.top, 14)
            }
            .padding(Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.bobSurface.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.bobHairline, lineWidth: 1)
                    )
            )
            .padding(.horizontal, Spacing.pageMargin)
        }
        .buttonStyle(.plain)
    }

    private var projectedMonthSpend: Decimal {
        let cal = Calendar.current
        let day = max(cal.component(.day, from: Date()), 1)
        let days = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        guard monthExpensesTotal > 0 else { return monthlyBudget > 0 ? monthlyBudget : 0 }
        return monthExpensesTotal / Decimal(day) * Decimal(days)
    }

    private var monthlySpendGraph: some View {
        let days = max(cumulativeSpend.count, 2)
        let today = min(max(Calendar.current.component(.day, from: Date()), 1), days)
        let actual = cumulativeSpend.prefix(today).map { $0 }
        let projected = monthlySpendProjection(days: days, today: today)
        let maxAmount = max(
            projected.map { ($0.amount as NSDecimalNumber).doubleValue }.max() ?? 1,
            (monthlyBudget as NSDecimalNumber).doubleValue,
            1
        )

        return VStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    LinearGradient(
                        colors: [Color.bobInk.opacity(0.08), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(monthlyAreaShape(data: projected, w: w, h: h, days: days, maxAmount: maxAmount))

                    if projected.count > 1 {
                        monthlyLinePath(data: projected, w: w, h: h, days: days, maxAmount: maxAmount)
                            .stroke(Color.bobInk.opacity(0.18), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round, dash: [5, 7]))
                    }

                    if actual.count > 1 {
                        monthlyAreaShape(data: actual, w: w, h: h, days: days, maxAmount: maxAmount)
                            .fill(
                                LinearGradient(
                                    colors: [Color.bobGreen.opacity(0.34), Color.bobGreen.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        monthlyLinePath(data: actual, w: w, h: h, days: days, maxAmount: maxAmount)
                            .stroke(Color.bobGreen.opacity(0.92), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                    } else if monthExpensesTotal <= 0 {
                        Text("No spending data yet")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.bobInk2)
                    }
                }
            }
            .frame(height: 96)

            HStack {
                ForEach(monthAxisDays(days: days), id: \.self) { day in
                    Text("\(day)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bobInk2)
                        .frame(maxWidth: .infinity, alignment: day == 1 ? .leading : day == days ? .trailing : .center)
                }
            }
        }
    }

    private func monthlySpendProjection(days: Int, today: Int) -> [(day: Int, amount: Decimal)] {
        let current = cumulativeSpend[max(today - 1, 0)].amount
        let target = max(projectedMonthSpend, current)
        guard days > today else { return cumulativeSpend }

        return (1...days).map { day in
            if day <= today {
                return cumulativeSpend[day - 1]
            }
            let remainingDays = Decimal(days - today)
            let progress = Decimal(day - today) / remainingDays
            return (day: day, amount: current + ((target - current) * progress))
        }
    }

    private func monthAxisDays(days: Int) -> [Int] {
        let proposed = [1, 6, 11, 16, 21, 26, days]
        return proposed.reduce(into: [Int]()) { result, day in
            let clamped = min(max(day, 1), days)
            if result.last != clamped { result.append(clamped) }
        }
    }

    private func monthlyLinePath(data: [(day: Int, amount: Decimal)], w: CGFloat, h: CGFloat, days: Int, maxAmount: Double) -> Path {
        var path = Path()
        guard days > 1 else { return path }
        for (index, point) in data.enumerated() {
            let position = monthlyPoint(point, w: w, h: h, days: days, maxAmount: maxAmount)
            index == 0 ? path.move(to: position) : path.addLine(to: position)
        }
        return path
    }

    private func monthlyAreaShape(data: [(day: Int, amount: Decimal)], w: CGFloat, h: CGFloat, days: Int, maxAmount: Double) -> Path {
        var path = Path()
        guard days > 1, let first = data.first else { return path }
        let firstPoint = monthlyPoint(first, w: w, h: h, days: days, maxAmount: maxAmount)
        path.move(to: CGPoint(x: firstPoint.x, y: h))
        path.addLine(to: firstPoint)
        for point in data.dropFirst() {
            path.addLine(to: monthlyPoint(point, w: w, h: h, days: days, maxAmount: maxAmount))
        }
        if let last = data.last {
            path.addLine(to: CGPoint(x: monthlyPoint(last, w: w, h: h, days: days, maxAmount: maxAmount).x, y: h))
        }
        path.closeSubpath()
        return path
    }

    private func monthlyPoint(_ point: (day: Int, amount: Decimal), w: CGFloat, h: CGFloat, days: Int, maxAmount: Double) -> CGPoint {
        let x = CGFloat(point.day - 1) / CGFloat(max(days - 1, 1)) * w
        let value = (point.amount as NSDecimalNumber).doubleValue
        let normalized = min(max(value / max(maxAmount, 1), 0), 1)
        let y = h - CGFloat(normalized) * h * 0.76 - h * 0.12
        return CGPoint(x: x, y: y)
    }

    // MARK: – Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.58))
            .tracking(0.8)
            .padding(.horizontal, Spacing.pageMargin)
    }

    private func displayTitle(for tx: Expense) -> String {
        if let m = tx.merchant, !m.isEmpty { return m }
        if let n = tx.note, !n.isEmpty { return n }
        return tx.category?.name ?? (tx.kind == .income ? "Income" : "Expense")
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
