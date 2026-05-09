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

    @State private var isAddingTransaction = false
    @State private var editingExpense: Expense?
    @State private var goToHistory = false
    @State private var goToSettings = false
    @State private var selectedMonthOffset: Int = 0
    @State private var recordsFilter: RecordsFilter = .thisMonth

    enum RecordsFilter { case recent, thisMonth }

    // MARK: – Core data

    private var settings: BudgetSettings? { settingsList.first }
    private var currencyCode: String { settings?.currencyCode ?? "USD" }
    private var monthlyBudget: Decimal { settings?.monthlyBudget ?? 0 }

    private var selectedMonthDate: Date {
        Calendar.current.date(byAdding: .month, value: selectedMonthOffset, to: Date()) ?? Date()
    }

    private var monthBounds: (start: Date, end: Date) {
        MonthSummary.bounds(for: selectedMonthDate)
    }

    private var monthTransactions: [Expense] {
        allExpenses.filter { $0.date >= monthBounds.start && $0.date <= monthBounds.end }
    }

    private var lastMonthTransactions: [Expense] {
        let cal = Calendar.current
        guard let s = cal.date(byAdding: .month, value: -1, to: monthBounds.start) else { return [] }
        return allExpenses.filter { $0.date >= s && $0.date < monthBounds.start }
    }

    private var monthIncome: Decimal {
        monthTransactions.filter { $0.kind == .income }.reduce(.zero) { $0 + $1.amount }
    }

    private var monthExpenses: [Expense] {
        monthTransactions.filter { $0.kind == .expense }
    }

    private var monthExpensesTotal: Decimal {
        monthExpenses.reduce(.zero) { $0 + $1.amount }
    }

    private var lastMonthIncome: Decimal {
        lastMonthTransactions.filter { $0.kind == .income }.reduce(.zero) { $0 + $1.amount }
    }

    private var lastMonthExpensesTotal: Decimal {
        lastMonthTransactions.filter { $0.kind == .expense }.reduce(.zero) { $0 + $1.amount }
    }

    private var budgetProgress: Double {
        guard monthlyBudget > 0 else { return 0 }
        return min(Double((monthExpensesTotal / monthlyBudget) as NSDecimalNumber), 1.0)
    }

    private var budgetRemaining: Decimal { monthlyBudget - monthExpensesTotal }

    private var streak: Int { calculateStreak() }

    private var monthOverMonthExpenseChange: Double? {
        let last = (lastMonthExpensesTotal as NSDecimalNumber).doubleValue
        let curr = (monthExpensesTotal as NSDecimalNumber).doubleValue
        guard last > 0.001 else { return nil }
        return ((curr - last) / last) * 100
    }

    // Spending forecast: only meaningful after 15th of current month
    private var spendingForecast: Decimal? {
        guard selectedMonthOffset == 0 else { return nil }
        let cal = Calendar.current
        let dayOfMonth = cal.component(.day, from: Date())
        let daysInMonth = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        guard dayOfMonth > 15, monthExpensesTotal > 0 else { return nil }
        let dailyRate = (monthExpensesTotal as NSDecimalNumber).doubleValue / Double(dayOfMonth)
        return Decimal(dailyRate * Double(daysInMonth))
    }

    // Top spending categories this month
    private var topCategories: [(name: String, symbol: String, amount: Decimal)] {
        var dict: [String: (symbol: String, amount: Decimal)] = [:]
        for expense in monthExpenses {
            let cat = expense.category?.name ?? "Other"
            let sym = expense.category?.sfSymbol ?? "circle.dashed"
            let existing = dict[cat]
            dict[cat] = (existing?.symbol ?? sym, (existing?.amount ?? 0) + expense.amount)
        }
        return dict.map { (name: $0.key, symbol: $0.value.symbol, amount: $0.value.amount) }
            .sorted { $0.amount > $1.amount }
            .prefix(5).map { $0 }
    }

    // Upcoming recurring grouped by proximity
    private var upcomingGrouped: [(label: String, items: [RecurringTransaction])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let twoWeeks = cal.date(byAdding: .day, value: 14, to: today) else { return [] }

        let active = recurrings.filter { $0.isActive && $0.nextDueDate <= twoWeeks }
            .sorted { $0.nextDueDate < $1.nextDueDate }

        var dueToday:  [RecurringTransaction] = []
        var thisWeek:  [RecurringTransaction] = []
        var nextWeek:  [RecurringTransaction] = []

        for r in active {
            let days = cal.dateComponents([.day], from: today,
                to: cal.startOfDay(for: r.nextDueDate)).day ?? 0
            if days <= 0      { dueToday.append(r) }
            else if days <= 7 { thisWeek.append(r) }
            else              { nextWeek.append(r) }
        }

        var groups: [(String, [RecurringTransaction])] = []
        if !dueToday.isEmpty { groups.append(("Due Today", dueToday)) }
        if !thisWeek.isEmpty { groups.append(("This Week", thisWeek)) }
        if !nextWeek.isEmpty { groups.append(("Next Week", nextWeek)) }
        return groups
    }

    private var activeGoals: [Goal] {
        goals.filter { $0.isActive && !$0.isCompleted }
            .sorted { $0.deadline < $1.deadline }
            .prefix(2).map { $0 }
    }

    // Today's transactions
    private var todaysTransactions: [Expense] {
        allExpenses.filter { Calendar.current.isDateInToday($0.date) }
    }
    private var todayIncome: Decimal { todaysTransactions.filter { $0.kind == .income }.reduce(.zero) { $0 + $1.amount } }
    private var todayExpenses: Decimal { todaysTransactions.filter { $0.kind == .expense }.reduce(.zero) { $0 + $1.amount } }

    // Quick stats
    private var dayOfMonth: Int { Calendar.current.component(.day, from: Date()) }
    private var dailyAvg: Decimal {
        guard dayOfMonth > 0, monthExpensesTotal > 0 else { return 0 }
        return monthExpensesTotal / Decimal(dayOfMonth)
    }
    private var savingsRate: Double {
        let inc = (monthIncome as NSDecimalNumber).doubleValue
        let exp = (monthExpensesTotal as NSDecimalNumber).doubleValue
        guard inc > 0 else { return 0 }
        return ((inc - exp) / inc) * 100
    }

    // Cumulative daily spend this month for mini chart
    private var cumulativeDailySpend: [(day: Int, amount: Decimal)] {
        let cal = Calendar.current
        var dict: [Int: Decimal] = [:]
        for tx in monthExpenses {
            let d = cal.component(.day, from: tx.date)
            dict[d, default: 0] += tx.amount
        }
        var cum: Decimal = 0
        let days = cal.range(of: .day, in: .month, for: selectedMonthDate)?.count ?? 30
        return (1...days).map { day in
            cum += dict[day] ?? 0
            return (day: day, amount: cum)
        }
    }

    // Auto-generated insight
    private var homeInsight: (icon: String, text: String, color: Color)? {
        if monthlyBudget > 0 && monthExpensesTotal > monthlyBudget {
            let over = monthExpensesTotal - monthlyBudget
            return ("exclamationmark.circle.fill",
                    "Over budget by \(CurrencyFormatter.string(over, code: currencyCode)) this month",
                    Color.bobDebit)
        }
        if let change = monthOverMonthExpenseChange, change > 20 {
            return ("arrow.up.right.circle.fill",
                    String(format: "Spending up %.0f%% vs last month", change),
                    Color.bobHex(0xF59E0B))
        }
        if monthlyBudget > 0 && budgetRemaining > 0 {
            return ("checkmark.circle.fill",
                    "\(CurrencyFormatter.string(budgetRemaining, code: currencyCode)) left in your budget",
                    Color.bobAccent)
        }
        if streak >= 5 {
            return ("flame.fill", "\(streak)-day logging streak — keep it up!", Color.bobHex(0xFF6B35))
        }
        return nil
    }

    private var filteredRecords: [Expense] {
        switch recordsFilter {
        case .thisMonth: return monthTransactions
        case .recent:
            let anchor = selectedMonthOffset == 0 ? Date() : monthBounds.end
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: anchor) ?? anchor
            return monthTransactions.filter { $0.date >= cutoff }
        }
    }

    // MARK: – Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bobBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.horizontal, Spacing.pageMargin)
                            .padding(.top, 8)
                            .padding(.bottom, Spacing.m)

                        overviewCard
                            .padding(.horizontal, Spacing.pageMargin)

                        todayCard
                            .padding(.horizontal, Spacing.pageMargin)
                            .padding(.top, Spacing.m)

                        quickStatsRow
                            .padding(.horizontal, Spacing.pageMargin)
                            .padding(.top, Spacing.m)

                        if selectedMonthOffset == 0 && monthlyBudget > 0 && !cumulativeDailySpend.isEmpty {
                            miniSpendingChart
                                .padding(.horizontal, Spacing.pageMargin)
                                .padding(.top, Spacing.m)
                        }

                        if !topCategories.isEmpty {
                            topCategoriesStrip
                                .padding(.top, Spacing.m)
                        }

                        actionRow
                            .padding(.horizontal, Spacing.pageMargin)
                            .padding(.top, Spacing.xl)

                        if !activeGoals.isEmpty {
                            goalsTeaser
                                .padding(.horizontal, Spacing.pageMargin)
                                .padding(.top, Spacing.xl)
                        }

                        if !upcomingGrouped.isEmpty {
                            upcomingSection
                                .padding(.horizontal, Spacing.pageMargin)
                                .padding(.top, Spacing.xl)
                        }

                        recordsSection
                            .padding(.horizontal, Spacing.pageMargin)
                            .padding(.top, Spacing.xl)

                        Spacer().frame(height: 140)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $goToHistory) { TransactionsListView() }
            .navigationDestination(isPresented: $goToSettings) { SettingsView() }
            .sheet(isPresented: $isAddingTransaction) {
                AddTransactionSheet(currencyCode: currencyCode, expenseToEdit: nil)
            }
            .sheet(item: $editingExpense) { expense in
                AddTransactionSheet(currencyCode: currencyCode, expenseToEdit: expense)
            }
        }
    }

    // MARK: – Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.bobInk)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(monthLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bobInk2)
            }
            Spacer()
            monthNavButtons
            iconButton(systemImage: "tray", action: {})
                .padding(.leading, 6)
            iconButton(systemImage: "person.crop.circle", action: { goToSettings = true })
                .padding(.leading, 6)
        }
    }

    private var monthNavButtons: some View {
        HStack(spacing: 2) {
            Button {
                withAnimation { selectedMonthOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Button {
                if selectedMonthOffset < 0 { withAnimation { selectedMonthOffset += 1 } }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selectedMonthOffset < 0 ? Color.bobInk2 : Color.bobInk3)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(selectedMonthOffset >= 0)
        }
    }

    private func iconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(Color.bobHairline, lineWidth: 1)
                    .background(Circle().fill(Color.bobSurface)).frame(width: 38, height: 38)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.bobInk)
            }
        }.buttonStyle(.plain)
    }

    // MARK: – Overview card

    private var overviewCard: some View {
        VStack(spacing: Spacing.s) {
            // Income / Spent row
            HStack(spacing: 0) {
                statColumn(
                    icon: "arrow.down.circle.fill",
                    iconColor: .bobAccent,
                    label: "Income",
                    value: CurrencyFormatter.string(monthIncome, code: currencyCode)
                )
                Divider().frame(height: 44).padding(.horizontal, Spacing.m)
                statColumn(
                    icon: "arrow.up.circle.fill",
                    iconColor: .bobDebit,
                    label: "Spent",
                    value: CurrencyFormatter.string(monthExpensesTotal, code: currencyCode)
                )
                if monthlyBudget > 0 {
                    Divider().frame(height: 44).padding(.horizontal, Spacing.m)
                    let remaining = budgetRemaining
                    statColumn(
                        icon: remaining >= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                        iconColor: remaining >= 0 ? .bobAccent : .bobDebit,
                        label: remaining >= 0 ? "Remaining" : "Over",
                        value: CurrencyFormatter.string(abs(remaining as NSDecimalNumber as Decimal), code: currencyCode)
                    )
                }
            }

            // Budget bar
            if monthlyBudget > 0 {
                budgetBar
            }

            // MoM change + streak
            HStack {
                if let change = monthOverMonthExpenseChange {
                    let isUp = change > 0
                    HStack(spacing: 4) {
                        Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(String(format: "%.0f%% spending vs last month", abs(change)))
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(isUp ? Color.bobDebit : Color.bobAccent)
                } else {
                    Text("Add transactions to track momentum")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bobInk2)
                }
                Spacer()
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 11))
                        Text("\(streak)d streak").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.bobInk2)
                }
            }

            // Forecast
            if let projected = spendingForecast {
                forecastRow(projected: projected)
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bobHairline, lineWidth: 1))
    }

    private func statColumn(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(iconColor)
                Text(label).font(.system(size: 11)).foregroundStyle(Color.bobInk3)
            }
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.bobInk)
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var budgetBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.bobHairline).frame(height: 8)
                    let color: Color = budgetProgress >= 1.0 ? .bobDebit : budgetProgress >= 0.8 ? Color.bobHex(0xF59E0B) : .bobAccent
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geo.size.width * budgetProgress, height: 8)
                        .animation(.spring(response: 0.5), value: budgetProgress)
                }
            }
            .frame(height: 8)
            HStack {
                Text("\(Int(budgetProgress * 100))% of \(CurrencyFormatter.string(monthlyBudget, code: currencyCode))")
                    .font(.system(size: 11)).foregroundStyle(Color.bobInk3)
                Spacer()
                let remaining = budgetRemaining
                Text(remaining >= 0
                     ? "\(CurrencyFormatter.string(remaining, code: currencyCode)) remaining"
                     : "\(CurrencyFormatter.string(abs(remaining as NSDecimalNumber as Decimal), code: currencyCode)) over")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(remaining >= 0 ? Color.bobInk2 : Color.bobDebit)
            }
        }
    }

    private func forecastRow(projected: Decimal) -> some View {
        let isOverBudget = monthlyBudget > 0 && projected > monthlyBudget
        let diff = monthlyBudget > 0 ? projected - monthlyBudget : 0

        return HStack(spacing: 8) {
            Image(systemName: isOverBudget ? "exclamationmark.triangle.fill" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 12))
                .foregroundStyle(isOverBudget ? Color.bobDebit : Color.bobAccent)
            Text(isOverBudget
                 ? "On pace to overspend by \(CurrencyFormatter.string(diff, code: currencyCode)) this month"
                 : "On pace to spend \(CurrencyFormatter.string(projected, code: currencyCode)) this month")
                .font(.system(size: 12))
                .foregroundStyle(Color.bobInk2)
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, 7)
        .background(isOverBudget ? Color.bobDebit.opacity(0.07) : Color.bobAccent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: – Top categories strip

    private var topCategoriesStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Top Spending")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .padding(.horizontal, Spacing.pageMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(topCategories, id: \.name) { cat in
                        Button { onSwitchTab?(.analytics) } label: {
                            HStack(spacing: 7) {
                                Image(systemName: cat.symbol)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.bobInk2)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(cat.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.bobInk)
                                    Text(CurrencyFormatter.string(cat.amount, code: currencyCode))
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.bobInk3)
                                        .monospacedDigit()
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Color.bobSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bobHairline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    Button { onSwitchTab?(.analytics) } label: {
                        Text("See all →")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.bobAccent)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Color.bobAccent.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.pageMargin)
            }
        }
    }

    // MARK: – Action row

    private var actionRow: some View {
        HStack(spacing: 0) {
            ActionButton(systemImage: "list.bullet.rectangle", label: "History") { goToHistory = true }
                .frame(maxWidth: .infinity)
            ActionButton(systemImage: "chart.pie", label: "Stats") { onSwitchTab?(.analytics) }
                .frame(maxWidth: .infinity)
            ActionButton(systemImage: "target", label: "Goals") { onSwitchTab?(.goals) }
                .frame(maxWidth: .infinity)
            ActionButton(systemImage: "gearshape", label: "More") { goToSettings = true }
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: – Goals teaser

    private var goalsTeaser: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Savings Goals")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.bobInk)
                Spacer()
                Button { onSwitchTab?(.goals) } label: {
                    Text("See All").font(.system(size: 14)).foregroundStyle(Color.bobInk3)
                }.buttonStyle(.plain)
            }
            VStack(spacing: Spacing.s) {
                ForEach(activeGoals) { goal in goalTeaserRow(goal) }
            }
        }
    }

    private func goalTeaserRow(_ goal: Goal) -> some View {
        HStack(spacing: 12) {
            Text(goal.emoji).font(.system(size: 26))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(goal.name)
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bobInk)
                    Spacer()
                    Text("\(Int(goal.progress * 100))%")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bobAccent)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.bobHairline).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3).fill(Color.bobAccent)
                            .frame(width: geo.size.width * min(goal.progress, 1.0), height: 5)
                    }
                }
                .frame(height: 5)
                HStack {
                    Text(CurrencyFormatter.string(goal.totalSaved, code: currencyCode))
                        .font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                    Text("of \(CurrencyFormatter.string(goal.targetAmount, code: currencyCode))")
                        .font(.system(size: 12)).foregroundStyle(Color.bobInk3)
                    Spacer()
                    let isOverdue = !goal.isCompleted && Date() > goal.deadline
                    Text(isOverdue ? "Overdue" : "\(goal.daysLeft)d left")
                        .font(.system(size: 11, weight: isOverdue ? .semibold : .regular))
                        .foregroundStyle(isOverdue ? Color.bobDebit : Color.bobInk3)
                }
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.bobHairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: – Upcoming recurring (date-grouped)

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Upcoming")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.bobInk)
                Spacer()
                Button { onSwitchTab?(.recurring) } label: {
                    Text("See All").font(.system(size: 14)).foregroundStyle(Color.bobInk3)
                }.buttonStyle(.plain)
            }

            ForEach(upcomingGrouped, id: \.label) { group in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(group.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(group.label == "Due Today" ? Color.bobDebit : Color.bobInk2)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    ForEach(group.items) { item in
                        upcomingRow(item)
                    }
                }
            }
        }
    }

    private func upcomingRow(_ item: RecurringTransaction) -> some View {
        let isIncome = item.kind == .income
        let color: Color = isIncome ? .bobAccent : .bobDebit
        let cal = Calendar.current
        let daysUntil = cal.dateComponents([.day],
            from: cal.startOfDay(for: Date()),
            to: cal.startOfDay(for: item.nextDueDate)).day ?? 0
        let isOverdue = daysUntil < 0

        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 18)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bobInk)
                let dueSub = isOverdue ? "Overdue by \(abs(daysUntil))d" : daysUntil == 0 ? "Due today" : item.frequency == .monthly ? "Monthly" : item.frequency == .yearly ? "Yearly" : item.frequency == .weekly ? "Weekly" : "Biweekly"
                Text(dueSub)
                    .font(.system(size: 12))
                    .foregroundStyle(isOverdue || daysUntil == 0 ? Color.bobDebit : Color.bobInk3)
            }
            Spacer()
            Text((isIncome ? "+" : "") + CurrencyFormatter.string(item.amount, code: currencyCode))
                .font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(color)
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.bobHairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: – Records section

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Transactions")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.bobInk)
                Spacer()
                Button { goToHistory = true } label: {
                    Text("See All").font(.system(size: 14)).foregroundStyle(Color.bobInk3)
                }.buttonStyle(.plain)
            }

            // Contextual insight chip
            if let insight = homeInsight {
                HStack(spacing: 8) {
                    Image(systemName: insight.icon).font(.system(size: 13)).foregroundStyle(insight.color)
                    Text(insight.text).font(.system(size: 13)).foregroundStyle(Color.bobInk).lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, Spacing.s).padding(.vertical, 10)
                .background(insight.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Segmented tabs
            HStack(spacing: 0) {
                segmentTab("This Month", selected: recordsFilter == .thisMonth) {
                    withAnimation { recordsFilter = .thisMonth }
                }
                segmentTab("Last 7 Days", selected: recordsFilter == .recent) {
                    withAnimation { recordsFilter = .recent }
                }
            }
            .background(Color.bobSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.bobHairline, lineWidth: 1))

            if filteredRecords.isEmpty {
                emptyState
            } else {
                transactionList
            }
        }
    }

    private func segmentTab(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.bobInk : Color.bobInk2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selected ? Color.bobInk.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(recordsFilter == .recent ? "No transactions in the last week." : "No transactions yet this month.")
                .font(.bobBody).foregroundStyle(Color.bobInk2)
            if monthTransactions.isEmpty {
                Button { isAddingTransaction = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                        Text("Add your first transaction").font(.bobBodyMed)
                    }
                    .foregroundStyle(Color.bobAccent)
                }.buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.m)
    }

    private var transactionList: some View {
        VStack(spacing: Spacing.s) {
            ForEach(Array(filteredRecords.prefix(8)), id: \.id) { tx in
                Button { editingExpense = tx } label: {
                    transactionRow(tx)
                }.buttonStyle(.plain)
            }
        }
    }

    private func transactionRow(_ tx: Expense) -> some View {
        let isIncome = tx.kind == .income
        let amountColor: Color = isIncome ? .bobAccent : .bobDebit
        let formatted = CurrencyFormatter.string(tx.amount, code: currencyCode)
        let display = isIncome ? "+\(formatted)" : formatted
        let iconColor = isIncome ? Color.bobAccent : categoryColor(for: tx.category)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.15)).frame(width: 46, height: 46)
                Image(systemName: tx.category?.sfSymbol ?? "circle.dashed")
                    .font(.system(size: 18, weight: .medium)).foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle(for: tx))
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bobInk).lineLimit(1)
                HStack(spacing: 4) {
                    Text(tx.category?.name ?? (isIncome ? "Income" : "Other"))
                        .font(.system(size: 12)).foregroundStyle(Color.bobInk3)
                    if let note = tx.note, !note.isEmpty {
                        Text("· \(note)").font(.system(size: 12)).foregroundStyle(Color.bobInk3).lineLimit(1)
                    }
                }
            }
            Spacer()
            Text(display)
                .font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(amountColor)
        }
        .padding(.vertical, 11).padding(.horizontal, 14)
        .background(Color.bobSurface)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.bobHairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: – Today card

    private var todayCard: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let hasTodayData = !todaysTransactions.isEmpty
        let showCard = hasTodayData || hour >= 12

        return Group {
            if showCard {
                VStack(spacing: 10) {
                    HStack {
                        Text("Today")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bobInk)
                        Spacer()
                        Text(hasTodayData ? "\(todaysTransactions.count) items" : "No activity yet")
                            .font(.system(size: 12)).foregroundStyle(Color.bobInk3)
                    }
                    if hasTodayData {
                        HStack(spacing: 0) {
                            statColumn(icon: "arrow.down.circle.fill", iconColor: .bobAccent,
                                       label: "In", value: CurrencyFormatter.string(todayIncome, code: currencyCode))
                            Divider().frame(height: 36).padding(.horizontal, Spacing.m)
                            statColumn(icon: "arrow.up.circle.fill", iconColor: .bobDebit,
                                       label: "Out", value: CurrencyFormatter.string(todayExpenses, code: currencyCode))
                            Spacer()
                        }
                        if let last = todaysTransactions.first {
                            HStack(spacing: 8) {
                                Image(systemName: last.category?.sfSymbol ?? "circle.dashed")
                                    .font(.system(size: 12)).foregroundStyle(Color.bobInk3)
                                Text(displayTitle(for: last))
                                    .font(.system(size: 12)).foregroundStyle(Color.bobInk2).lineLimit(1)
                                Spacer()
                                Text(CurrencyFormatter.string(last.amount, code: currencyCode))
                                    .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                                    .foregroundStyle(last.kind == .income ? Color.bobAccent : Color.bobDebit)
                            }
                        }
                    } else {
                        Text("Tap + to log a transaction")
                            .font(.system(size: 13)).foregroundStyle(Color.bobInk3)
                    }
                }
                .padding(Spacing.m)
                .background(Color.bobSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bobHairline, lineWidth: 1))
            }
        }
    }

    // MARK: – Quick stats row

    private var quickStatsRow: some View {
        HStack(spacing: Spacing.s) {
            quickStatTile(
                label: "Daily avg",
                value: dailyAvg > 0 ? CurrencyFormatter.compact(dailyAvg, code: currencyCode) : "—",
                icon: "calendar",
                color: .bobInk2
            )
            quickStatTile(
                label: "Savings rate",
                value: monthIncome > 0 ? String(format: "%.0f%%", savingsRate) : "—",
                icon: savingsRate >= 0 ? "arrow.up.right" : "arrow.down.right",
                color: savingsRate >= 0 ? .bobAccent : .bobDebit
            )
            quickStatTile(
                label: "Streak",
                value: streak > 0 ? "\(streak)d" : "—",
                icon: "flame.fill",
                color: streak >= 5 ? Color.bobHex(0xFF6B35) : .bobInk3
            )
        }
    }

    private func quickStatTile(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color)
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(Color.bobInk).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.bobInk2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bobHairline, lineWidth: 1))
    }

    // MARK: – Mini spending chart

    private var miniSpendingChart: some View {
        let cal = Calendar.current
        let daysInMonth = cal.range(of: .day, in: .month, for: selectedMonthDate)?.count ?? 30
        let data = cumulativeDailySpend
        let maxY = max((monthlyBudget as NSDecimalNumber).doubleValue * 1.1,
                       data.map { ($0.amount as NSDecimalNumber).doubleValue }.max() ?? 100)
        let budgetY = (monthlyBudget as NSDecimalNumber).doubleValue

        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Spending this month")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bobInk)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack(alignment: .topLeading) {
                    // Budget dashed line
                    let budgetFrac = budgetY / maxY
                    Path { p in
                        let y = h - CGFloat(budgetFrac) * h
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(Color.bobDebit.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    // Spending area fill
                    spendingAreaPath(data: data, w: w, h: h, maxY: maxY, daysInMonth: daysInMonth)
                        .fill(LinearGradient(colors: [Color.bobAccent.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))

                    // Spending line
                    spendingLinePath(data: data, w: w, h: h, maxY: maxY, daysInMonth: daysInMonth)
                        .stroke(Color.bobAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 70)

            HStack {
                Text("1").font(.system(size: 10)).foregroundStyle(Color.bobInk3)
                Spacer()
                Text("\(daysInMonth / 2)").font(.system(size: 10)).foregroundStyle(Color.bobInk3)
                Spacer()
                Text("\(daysInMonth)").font(.system(size: 10)).foregroundStyle(Color.bobInk3)
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bobHairline, lineWidth: 1))
    }

    private func spendingLinePath(data: [(day: Int, amount: Decimal)], w: CGFloat, h: CGFloat, maxY: Double, daysInMonth: Int) -> Path {
        var path = Path()
        for (i, point) in data.enumerated() {
            let x = CGFloat(point.day - 1) / CGFloat(daysInMonth - 1) * w
            let y = h - CGFloat((point.amount as NSDecimalNumber).doubleValue / maxY) * h
            i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }

    private func spendingAreaPath(data: [(day: Int, amount: Decimal)], w: CGFloat, h: CGFloat, maxY: Double, daysInMonth: Int) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h))
        for point in data {
            let x = CGFloat(point.day - 1) / CGFloat(daysInMonth - 1) * w
            let y = h - CGFloat((point.amount as NSDecimalNumber).doubleValue / maxY) * h
            path.addLine(to: CGPoint(x: x, y: y))
        }
        if let last = data.last {
            let x = CGFloat(last.day - 1) / CGFloat(daysInMonth - 1) * w
            path.addLine(to: CGPoint(x: x, y: h))
        }
        path.closeSubpath()
        return path
    }

    // MARK: – Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let time = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        let name = userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? time : "\(time), \(name)"
    }

    private var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedMonthDate)
    }

    private func displayTitle(for tx: Expense) -> String {
        if let m = tx.merchant, !m.isEmpty { return m }
        if let n = tx.note, !n.isEmpty { return n }
        return tx.category?.name ?? (tx.kind == .income ? "Income" : "Expense")
    }

    private func categoryColor(for category: ExpenseCategory?) -> Color {
        let palette: [Color] = [
            Color.bobHex(0xE0413B), Color.bobHex(0x4FC3F7), Color.bobHex(0xFFB74D),
            Color.bobHex(0x81C784), Color.bobHex(0xBA68C8), Color.bobHex(0xFF8A65),
            Color.bobHex(0x4DD0E1), Color.bobHex(0xF06292)
        ]
        guard let cat = category else { return Color.bobInk3 }
        return palette[abs(cat.name.hashValue) % palette.count]
    }

    private func calculateStreak() -> Int {
        guard !allExpenses.isEmpty else { return 0 }
        let cal = Calendar.current
        var streakCount = 0
        let sortedExpenses = allExpenses.sorted { $0.date > $1.date }
        var lastDate: Date?
        for expense in sortedExpenses {
            let txDate = cal.startOfDay(for: expense.date)
            if let last = lastDate {
                let expected = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: last))!
                if txDate == expected || txDate == last {
                    if txDate != last { streakCount += 1 }
                } else if txDate != last { break }
            } else {
                let today = cal.startOfDay(for: Date())
                let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
                if txDate == today || txDate == yesterday { streakCount = 1 } else { streakCount = 0 }
            }
            lastDate = txDate
        }
        return streakCount
    }
}
