import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    var onSwitchTab: ((BobTab) -> Void)? = nil
    var onAddTransaction: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse),
                  SortDescriptor(\Expense.createdAt, order: .reverse)])
    private var allExpenses: [Expense]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: \RecurringTransaction.nextDueDate) private var recurrings: [RecurringTransaction]

    @AppStorage("userName") private var userName: String = ""
    @State private var editingExpense: Expense?
    @State private var isAddingTransaction = false

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

    // MARK: – Body

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, Spacing.pageMargin)
                        .padding(.top, 12)

                    heroCard
                        .padding(.horizontal, Spacing.pageMargin)
                        .padding(.top, Spacing.m)

                    if !upcomingItems.isEmpty {
                        upcomingSection
                            .padding(.top, Spacing.xl)
                    }

                    recentTransactionsSection
                        .padding(.top, Spacing.xl)

                    Spacer().frame(height: 100)
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
    }

    // MARK: – Top bar

    private var topBar: some View {
        HStack {
            Button { onSwitchTab?(.more) } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.bobInk2)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(todayLabel)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bobInk)

            Spacer()

            Button { } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color.bobInk2)
                        .frame(width: 36, height: 36)
                    Circle()
                        .fill(Color.bobNotify)
                        .frame(width: 8, height: 8)
                        .offset(x: -2, y: 2)
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
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.bobHairline, lineWidth: 0.5))
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
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bobHairline, lineWidth: 0.5))
    }

    // MARK: – Recent transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                sectionHeader("RECENT TRANSACTIONS")
                Spacer()
                Button { onSwitchTab?(.more) } label: {
                    Text("See All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bobAccent)
                }
                .buttonStyle(.plain)
                .padding(.trailing, Spacing.pageMargin)
            }

            // Add transaction CTA card
            Button { isAddingTransaction = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.bobAccent.opacity(0.15)).frame(width: 42, height: 42)
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20)).foregroundStyle(Color.bobAccent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Log a transaction")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bobInk)
                        Text("Tap to add income or expense")
                            .font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bobInk2)
                }
                .padding(Spacing.m)
                .background(Color.bobSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.bobAccent.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.pageMargin)

            // Recent transaction rows
            if !recentExpenses.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(recentExpenses.enumerated()), id: \.element.id) { idx, tx in
                        Button { editingExpense = tx } label: {
                            transactionRow(tx)
                        }
                        .buttonStyle(.plain)
                        if idx < recentExpenses.count - 1 {
                            Divider()
                                .background(Color.bobHairline)
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(Color.bobSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bobHairline, lineWidth: 0.5))
                .padding(.horizontal, Spacing.pageMargin)
            }
        }
    }

    private var recentExpenses: [Expense] {
        Array(allExpenses.prefix(8))
    }

    private func transactionRow(_ tx: Expense) -> some View {
        let isIncome = tx.kind == .income
        let amount = CurrencyFormatter.string(tx.amount, code: currencyCode)
        let display = isIncome ? "+\(amount)" : amount
        let amountColor: Color = isIncome ? .bobAccent : .bobInk

        return HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.bobSurface2)
                    .frame(width: 42, height: 42)
                Image(systemName: tx.category?.sfSymbol ?? "circle.dashed")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.bobInk2)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle(for: tx))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.bobInk)
                    .lineLimit(1)
                Text(relativeDate(tx.date))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bobInk2)
            }

            Spacer()

            Text(display)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(amountColor)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    // MARK: – Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.bobInk2)
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
