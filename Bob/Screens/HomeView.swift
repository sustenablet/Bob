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
    @State private var recordsFilterDays: Int = 30

    // MARK: – Derived

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
        guard let lastStart = cal.date(byAdding: .month, value: -1, to: monthBounds.start) else { return [] }
        return allExpenses.filter { $0.date >= lastStart && $0.date < monthBounds.start }
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

    private var cashFlow: Decimal {
        monthIncome - monthExpensesTotal
    }

    private var lastCashFlow: Decimal {
        let inc = lastMonthTransactions.filter { $0.kind == .income }.reduce(Decimal.zero) { $0 + $1.amount }
        let exp = lastMonthTransactions.filter { $0.kind == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
        return inc - exp
    }
    
    private var streak: Int {
        calculateStreak()
    }
    
    private func calculateStreak() -> Int {
        guard !allExpenses.isEmpty else { return 0 }
        
        let cal = Calendar.current
        var streakCount = 0
        var currentDate = Date()
        
        let sortedExpenses = allExpenses.sorted { $0.date > $1.date }
        var lastTransactionDate: Date?
        
        for expense in sortedExpenses {
            let txDate = cal.startOfDay(for: expense.date)
            
            if let last = lastTransactionDate {
                let expectedDate = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: last))!
                if txDate == expectedDate || txDate == last {
                    if txDate != last {
                        streakCount += 1
                    }
                } else if txDate != last {
                    break
                }
            } else {
                if txDate == cal.startOfDay(for: currentDate) || txDate == cal.date(byAdding: .day, value: -1, to: currentDate)! {
                    streakCount = 1
                } else {
                    streakCount = 0
                }
            }
            lastTransactionDate = txDate
        }
        
        return streakCount
    }

    private var monthOverMonthChange: (percent: Double, isUp: Bool)? {
        let last = (lastCashFlow as NSDecimalNumber).doubleValue
        let current = (cashFlow as NSDecimalNumber).doubleValue
        guard abs(last) > 0.001 else { return nil }
        let pct = ((current - last) / abs(last)) * 100
        return (abs(pct), pct >= 0)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let time: String
        switch hour {
        case 0..<12: time = "Good morning"
        case 12..<17: time = "Good afternoon"
        default: time = "Good evening"
        }
        let name = userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? time : "\(time), \(name)"
    }

    private var upcomingRecurring: [RecurringTransaction] {
        // Show overdue + upcoming (next 14 days), sorted by due date
        let cutoff = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        return recurrings
            .filter { $0.isActive && $0.nextDueDate <= cutoff }
            .sorted { $0.nextDueDate < $1.nextDueDate }
            .prefix(4)
            .map { $0 }
    }

    private var activeGoals: [Goal] {
        goals
            .filter { $0.isActive && !$0.isCompleted }
            .sorted { $0.deadline < $1.deadline }
            .prefix(2)
            .map { $0 }
    }

    private var heroColor: Color {
        if cashFlow > 0 { return .bobAccent }
        if cashFlow < 0 { return .bobOverBudget }
        return .bobInk
    }

    @ViewBuilder
    private var monthNavBar: some View {
        HStack {
            Button {
                withAnimation { selectedMonthOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
            }
            
            Spacer()
            
            Text(monthLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bobInk)
            
            Spacer()
            
            Button {
                if selectedMonthOffset < 0 {
                    withAnimation { selectedMonthOffset += 1 }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectedMonthOffset < 0 ? Color.bobInk2 : Color.bobInk3)
            }
            .disabled(selectedMonthOffset >= 0)
        }
        .padding(.horizontal, Spacing.xs)
    }

    // MARK: – Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bobBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        DashboardHeader(
                            greeting: greeting,
                            onInbox: {},
                            onProfile: { goToSettings = true }
                        )
                        .padding(.horizontal, Spacing.pageMargin)
                        .padding(.top, 8)
                        .padding(.bottom, Spacing.l)

                        balanceSection
                            .padding(.horizontal, Spacing.pageMargin)

                        budgetCard
                            .padding(.horizontal, Spacing.pageMargin)
                            .padding(.top, Spacing.l)

                        actionRow
                            .padding(.horizontal, Spacing.pageMargin)
                            .padding(.top, Spacing.xl)

                        if !activeGoals.isEmpty {
                            goalsTeaser
                                .padding(.horizontal, Spacing.pageMargin)
                                .padding(.top, Spacing.xl)
                        }

                        if !upcomingRecurring.isEmpty {
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
            .navigationDestination(isPresented: $goToHistory) {
                TransactionsListView()
            }
            .navigationDestination(isPresented: $goToSettings) {
                SettingsView()
            }
            .sheet(isPresented: $isAddingTransaction) {
                AddTransactionSheet(currencyCode: currencyCode, expenseToEdit: nil)
            }
            .sheet(item: $editingExpense) { expense in
                AddTransactionSheet(currencyCode: currencyCode, expenseToEdit: expense)
            }
        }
    }

    // MARK: – Balance section

    private var balanceSection: some View {
        VStack(spacing: 14) {
            monthNavBar
            
            BalancePill(text: "Available Balance")

            Text(formattedCashFlow)
                .font(.bobHero(38, weight: .bold))
                .foregroundStyle(heroColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())

            incomeSplitRow

            momentumIndicator

            if streak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bobInk)
                    Text("\(streak) day\(streak == 1 ? "" : "s") streak")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.bobInk)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var incomeSplitRow: some View {
        HStack(spacing: 20) {
            statPill(
                systemImage: "arrow.down",
                label: CurrencyFormatter.string(monthIncome, code: currencyCode),
                color: .bobAccent
            )
            statPill(
                systemImage: "arrow.up",
                label: CurrencyFormatter.string(monthExpensesTotal, code: currencyCode),
                color: .bobDebit
            )
        }
    }

    private func statPill(systemImage: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.bobInk2)
        }
    }

    private var formattedCashFlow: String {
        let abs = abs(cashFlow as NSDecimalNumber as Decimal)
        let formatted = CurrencyFormatter.string(abs, code: currencyCode)
        if cashFlow < 0 { return "-\(formatted)" }
        if cashFlow > 0 { return "+\(formatted)" }
        return formatted
    }

    @ViewBuilder
    private var momentumIndicator: some View {
        if let change = monthOverMonthChange {
            HStack(spacing: 6) {
                Image(systemName: change.isUp ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(change.isUp ? Color.bobAccent : Color.bobOverBudget)
                Text(String(format: "%.2f%%", change.percent))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(change.isUp ? Color.bobAccent : Color.bobOverBudget)
                Text("vs ")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.bobInk2)
                Text("Last month")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.bobInk2)
                    .underline()
            }
        } else {
            Text("Log income and expenses to track momentum")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.bobInk2)
        }
    }

    // MARK: – Monthly summary card

    private var budgetCard: some View {
        MonthlySummaryCard(
            income: monthIncome,
            expenses: monthExpensesTotal,
            budget: monthlyBudget,
            currencyCode: currencyCode,
            monthLabel: monthLabel
        )
    }
    
    // MARK: – Action row (Add lives in the FAB now)

    private var actionRow: some View {
        HStack(spacing: 0) {
            ActionButton(systemImage: "list.bullet.rectangle", label: "History") {
                goToHistory = true
            }
            .frame(maxWidth: .infinity)

            ActionButton(systemImage: "chart.pie", label: "Stats") {
                onSwitchTab?(.analytics)
            }
            .frame(maxWidth: .infinity)

            ActionButton(systemImage: "target", label: "Goals") {
                onSwitchTab?(.goals)
            }
            .frame(maxWidth: .infinity)

            ActionButton(systemImage: "gearshape", label: "More") {
                goToSettings = true
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: – Records section

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Payment Records")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                Spacer()
                Button {
                    goToHistory = true
                } label: {
                    Text("See More")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.bobInk3)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: Spacing.s) {
                FilterChip(
                    text: "Last week",
                    isSelected: recordsFilterDays == 7,
                    onTap: { withAnimation { recordsFilterDays = recordsFilterDays == 7 ? 30 : 7 } }
                )
                FilterChip(
                    text: dateRangeLabel,
                    systemImage: "calendar",
                    isSelected: recordsFilterDays == 30,
                    onTap: { withAnimation { recordsFilterDays = 30 } }
                )
            }

            if filteredRecords.isEmpty {
                emptyState
            } else {
                transactionList
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(recordsFilterDays == 7 ? "No transactions in the last week." : "No transactions yet this month.")
                .font(.bobBody)
                .foregroundStyle(Color.bobInk2)
            if monthTransactions.isEmpty {
                Button {
                    isAddingTransaction = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add your first transaction")
                            .font(.bobBodyMed)
                    }
                    .foregroundStyle(Color.bobAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.m)
    }

    private var filteredRecords: [Expense] {
        if recordsFilterDays == 30 { return monthTransactions }
        // "Last week" is relative to the end of the selected month (or today if current month)
        let anchor = selectedMonthOffset == 0 ? Date() : monthBounds.end
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: anchor) ?? anchor
        return monthTransactions.filter { $0.date >= cutoff }
    }

    private var transactionList: some View {
        VStack(spacing: Spacing.s) {
            ForEach(Array(filteredRecords.prefix(6)), id: \.id) { tx in
                Button {
                    editingExpense = tx
                } label: {
                    transactionRow(tx)
                }
                .buttonStyle(.plain)
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
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: tx.category?.sfSymbol ?? "circle.dashed")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle(for: tx))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                    .lineLimit(1)
                Text(tx.category?.name ?? (isIncome ? "Income" : "Other"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.bobInk3)
            }

            Spacer()

            Text(display)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.bobSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.bobHairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: – Goals teaser

    private var goalsTeaser: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Savings Goals")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                Spacer()
                Button { onSwitchTab?(.goals) } label: {
                    Text("See All")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bobInk3)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: Spacing.s) {
                ForEach(activeGoals) { goal in
                    goalTeaserRow(goal)
                }
            }
        }
    }

    private func goalTeaserRow(_ goal: Goal) -> some View {
        HStack(spacing: 12) {
            Text(goal.emoji)
                .font(.system(size: 26))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(goal.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bobInk)
                    Spacer()
                    Text("\(Int(goal.progress * 100))%")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bobAccent)
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
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bobInk2)
                    Text("of \(CurrencyFormatter.string(goal.targetAmount, code: currencyCode))")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bobInk3)
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

    // MARK: – Upcoming recurring

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Upcoming")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                Spacer()
                Button { onSwitchTab?(.recurring) } label: {
                    Text("See All")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bobInk3)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: Spacing.s) {
                ForEach(upcomingRecurring) { item in
                    upcomingRow(item)
                }
            }
        }
    }

    private func upcomingRow(_ item: RecurringTransaction) -> some View {
        let isIncome = item.kind == .income
        let color: Color = isIncome ? .bobAccent : .bobDebit
        let daysUntil = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: item.nextDueDate)
        ).day ?? 0
        let isOverdue = daysUntil < 0
        let dueLabel: String = {
            if isOverdue { return "Overdue by \(abs(daysUntil))d" }
            if daysUntil == 0 { return "Due today" }
            if daysUntil == 1 { return "Due tomorrow" }
            return "Due in \(daysUntil)d"
        }()
        let dueLabelColor: Color = isOverdue || daysUntil == 0 ? .bobDebit : daysUntil == 1 ? Color.bobHex(0xF59E0B) : .bobInk3

        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(isOverdue ? 0.18 : 0.12)).frame(width: 40, height: 40)
                Image(systemName: isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                Text(dueLabel)
                    .font(.system(size: 12, weight: isOverdue ? .semibold : .regular))
                    .foregroundStyle(dueLabelColor)
            }
            Spacer()
            Text((isIncome ? "+" : "") + CurrencyFormatter.string(item.amount, code: currencyCode))
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.bobHairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: – Helpers

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedMonthDate)
    }

    private var dateRangeLabel: String {
        let cal = Calendar.current
        let now = Date()
        guard let start = cal.date(byAdding: .day, value: -7, to: now) else { return "This week" }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return "\(f.string(from: start)) – \(f.string(from: now))"
    }

    private func displayTitle(for tx: Expense) -> String {
        if let m = tx.merchant, !m.isEmpty { return m }
        if let n = tx.note, !n.isEmpty { return n }
        return tx.category?.name ?? (tx.kind == .income ? "Income" : "Expense")
    }

    private func categoryColor(for category: ExpenseCategory?) -> Color {
        let palette: [Color] = [
            Color.bobHex(0xE0413B),
            Color.bobHex(0x4FC3F7),
            Color.bobHex(0xFFB74D),
            Color.bobHex(0x81C784),
            Color.bobHex(0xBA68C8),
            Color.bobHex(0xFF8A65),
            Color.bobHex(0x4DD0E1),
            Color.bobHex(0xF06292)
        ]
        guard let cat = category else { return Color.bobInk3 }
        let index = abs(cat.name.hashValue) % palette.count
        return palette[index]
    }
}
