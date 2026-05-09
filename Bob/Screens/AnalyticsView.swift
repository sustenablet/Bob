import SwiftUI
import SwiftData

// MARK: – Main view

struct AnalyticsView: View {
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]

    @State private var selectedPeriod: AnalyticsPeriod = .currentMonth
    @State private var reportKind: TransactionKind = .expense
    @State private var selectedCategoryIndex: Int? = nil
    @State private var chartType: ChartDisplayType = .donut
    @State private var drilldownCategory: CategoryData? = nil

    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }
    private var budget: Decimal { settingsList.first?.monthlyBudget ?? 0 }

    // Previous period totals (for summary card, independent of reportKind)
    private var prevPeriodIncome: Decimal {
        allExpenses.filter { $0.kind == .income && isInPreviousPeriod($0.date) }.reduce(0) { $0 + $1.amount }
    }
    private var prevPeriodExpenses: Decimal {
        allExpenses.filter { $0.kind == .expense && isInPreviousPeriod($0.date) }.reduce(0) { $0 + $1.amount }
    }
    private var currentPeriodIncome: Decimal {
        allExpenses.filter { $0.kind == .income && isInPeriod($0.date) }.reduce(0) { $0 + $1.amount }
    }
    private var currentPeriodExpenses: Decimal {
        allExpenses.filter { $0.kind == .expense && isInPeriod($0.date) }.reduce(0) { $0 + $1.amount }
    }

    // MARK: Data

    private var filteredTransactions: [Expense] {
        allExpenses.filter { $0.kind == reportKind && isInPeriod($0.date) }
    }

    private var categoryData: [CategoryData] {
        var dict: [String: (amount: Decimal, symbol: String)] = [:]
        for expense in filteredTransactions {
            let cat = expense.category?.name ?? "Other"
            let sym = expense.category?.sfSymbol ?? "circle.dashed"
            let existing = dict[cat]
            dict[cat] = ((existing?.amount ?? 0) + expense.amount, existing?.symbol ?? sym)
        }
        return dict.map { CategoryData(category: $0.key, amount: $0.value.amount, symbol: $0.value.symbol) }
            .sorted { $0.amount > $1.amount }
    }

    private var totalAmount: Decimal { categoryData.reduce(0) { $0 + $1.amount } }

    private var previousPeriodData: [String: Decimal] {
        var dict: [String: Decimal] = [:]
        for expense in allExpenses where expense.kind == reportKind && isInPreviousPeriod(expense.date) {
            dict[expense.category?.name ?? "Other", default: 0] += expense.amount
        }
        return dict
    }

    private var dailySpending: [(date: Date, amount: Decimal)] {
        let cal = Calendar.current
        var dict: [Date: Decimal] = [:]
        for tx in filteredTransactions {
            dict[cal.startOfDay(for: tx.date), default: 0] += tx.amount
        }
        return dict.map { (date: $0.key, amount: $0.value) }.sorted { $0.date < $1.date }
    }

    private var avgDailySpend: Decimal {
        guard !dailySpending.isEmpty else { return 0 }
        return totalAmount / Decimal(dailySpending.count)
    }

    // MARK: – Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bobBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Spacing.l) {
                        periodSummaryCard.padding(.horizontal, Spacing.pageMargin)
                        kindToggle.padding(.horizontal, Spacing.pageMargin)
                        periodPicker

                        if categoryData.isEmpty {
                            emptyState.padding(.horizontal, Spacing.pageMargin)
                        } else {
                            keyMetricsRow.padding(.horizontal, Spacing.pageMargin)
                            chartSection.padding(.horizontal, Spacing.pageMargin)
                            if budget > 0 && selectedPeriod == .currentMonth && reportKind == .expense {
                                budgetVsActualSection.padding(.horizontal, Spacing.pageMargin)
                            }
                            categoryList.padding(.horizontal, Spacing.pageMargin)
                            if !insights.isEmpty {
                                insightsSection.padding(.horizontal, Spacing.pageMargin)
                            }
                            if dailySpending.count >= 2 {
                                trendSection.padding(.horizontal, Spacing.pageMargin)
                            }
                        }

                        trendsSection.padding(.horizontal, Spacing.pageMargin)
                    }
                    .padding(.top, Spacing.m)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $drilldownCategory) { cat in
                CategoryTransactionsView(
                    categoryName: cat.category,
                    symbol: cat.symbol,
                    period: selectedPeriod,
                    kind: reportKind,
                    currencyCode: currencyCode
                )
            }
        }
        .onChange(of: reportKind)     { _, _ in withAnimation { selectedCategoryIndex = nil } }
        .onChange(of: selectedPeriod) { _, _ in withAnimation { selectedCategoryIndex = nil } }
    }

    // MARK: – Kind toggle

    private var kindToggle: some View {
        HStack(spacing: 0) {
            ForEach(TransactionKind.allCases) { kind in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { reportKind = kind }
                } label: {
                    Text(kind == .expense ? "Expenses" : "Income")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(reportKind == kind ? .white : Color.bobInk2)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill(reportKind == kind
                            ? (kind == .expense ? Color.bobDebit : Color.bobAccent) : Color.clear))
                }.buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.bobSurface))
        .overlay(Capsule().stroke(Color.bobHairline, lineWidth: 1))
    }

    // MARK: – Period picker

    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { selectedPeriod = period }
                    } label: {
                        Text(period.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selectedPeriod == period ? .white : Color.bobInk2)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(selectedPeriod == period ? Color.bobInk : Color.bobSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selectedPeriod == period ? Color.clear : Color.bobHairline, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.pageMargin)
        }
    }

    // MARK: – Key metrics row

    private var keyMetricsRow: some View {
        HStack(spacing: Spacing.s) {
            metricTile(
                icon: reportKind == .expense ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                iconColor: reportKind == .expense ? .bobDebit : .bobAccent,
                value: CurrencyFormatter.string(totalAmount, code: currencyCode),
                label: reportKind == .expense ? "Total Spent" : "Total Income"
            )
            metricTile(
                icon: "calendar.badge.clock",
                iconColor: Color.bobHex(0x1A73E8),
                value: avgDailySpend > 0 ? CurrencyFormatter.compact(avgDailySpend, code: currencyCode) : "—",
                label: "Daily Avg"
            )
            if let top = categoryData.first {
                metricTile(
                    icon: top.symbol,
                    iconColor: chartPaletteColor(for: 0),
                    value: top.category,
                    label: "Top Category"
                )
            } else {
                metricTile(icon: "chart.pie", iconColor: Color.bobInk3, value: "—", label: "Top Category")
            }
        }
    }

    private func metricTile(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Color.bobInk)
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.bobInk2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: – Chart section with type switcher

    private var chartSection: some View {
        VStack(spacing: Spacing.m) {
            // Type switcher
            HStack(spacing: 8) {
                ForEach(ChartDisplayType.allCases, id: \.self) { type in
                    Button { withAnimation(.easeOut(duration: 0.2)) { chartType = type } } label: {
                        HStack(spacing: 5) {
                            Image(systemName: type.icon).font(.system(size: 12, weight: .semibold))
                            Text(type.label).font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(chartType == type ? .white : Color.bobInk2)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(chartType == type ? Color.bobInk : Color.clear)
                        .clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(3)
            .background(Color.bobSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.bobHairline, lineWidth: 1))

            // Active chart
            switch chartType {
            case .donut:
                donutSection
            case .pie:
                FilledPieChart(
                    data: categoryData,
                    currencyCode: currencyCode,
                    selectedIndex: $selectedCategoryIndex
                )
            case .bars:
                HorizontalBarsChart(data: categoryData, total: totalAmount, currencyCode: currencyCode)
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Donut section

    private var donutSection: some View {
        VStack(spacing: Spacing.s) {
            ZStack {
                Circle().stroke(Color.bobHairline, lineWidth: 30)

                ForEach(0..<categoryData.count, id: \.self) { idx in
                    let start = startFraction(for: idx)
                    let end = endFraction(for: idx)
                    Circle()
                        .trim(from: start, to: max(start, end - 0.007))
                        .stroke(chartPaletteColor(for: idx),
                                style: StrokeStyle(lineWidth: 30, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .opacity(selectedCategoryIndex == nil || selectedCategoryIndex == idx ? 1.0 : 0.25)
                        .animation(.easeOut(duration: 0.2), value: selectedCategoryIndex)
                }

                VStack(spacing: 4) {
                    if let idx = selectedCategoryIndex, idx < categoryData.count {
                        Text(categoryData[idx].category)
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bobInk2)
                            .lineLimit(1).transition(.opacity)
                        Text(CurrencyFormatter.string(categoryData[idx].amount, code: currencyCode))
                            .font(.system(size: 19, weight: .bold)).foregroundStyle(Color.bobInk)
                            .contentTransition(.numericText())
                    } else {
                        Text(reportKind == .expense ? "Total Spent" : "Total Income")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bobInk2)
                        Text(CurrencyFormatter.string(totalAmount, code: currencyCode))
                            .font(.system(size: 19, weight: .bold)).foregroundStyle(Color.bobInk)
                            .contentTransition(.numericText())
                    }
                }
                .animation(.easeOut(duration: 0.15), value: selectedCategoryIndex)
            }
            .frame(width: 220, height: 220)
            .frame(maxWidth: .infinity)
        }
    }

    private func startFraction(for idx: Int) -> Double {
        guard totalAmount > 0 else { return 0 }
        let preceding = categoryData.prefix(idx).reduce(Decimal(0)) { $0 + $1.amount }
        return Double((preceding / totalAmount) as NSDecimalNumber)
    }

    private func endFraction(for idx: Int) -> Double {
        guard totalAmount > 0 else { return 0 }
        let total = categoryData.prefix(idx + 1).reduce(Decimal(0)) { $0 + $1.amount }
        return Double((total / totalAmount) as NSDecimalNumber)
    }

    // MARK: – Category list

    private var categoryList: some View {
        VStack(spacing: Spacing.s) {
            HStack {
                Text(reportKind == .expense ? "All Expenses" : "All Income")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)
                Spacer()
                Text(CurrencyFormatter.string(totalAmount, code: currencyCode))
                    .font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk2)
            }
            .padding(.bottom, 4)

            ForEach(Array(categoryData.enumerated()), id: \.element.category) { idx, item in
                CategoryCard(
                    item: item, index: idx, total: totalAmount,
                    momChange: momChange(for: item.category),
                    isExpense: reportKind == .expense,
                    currencyCode: currencyCode,
                    isSelected: selectedCategoryIndex == idx,
                    onTap: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedCategoryIndex = selectedCategoryIndex == idx ? nil : idx
                        }
                    },
                    onDrillDown: { drilldownCategory = item }
                )
            }
        }
    }

    private func momChange(for category: String) -> Double? {
        let prev = previousPeriodData[category] ?? 0
        let curr = categoryData.first(where: { $0.category == category })?.amount ?? 0
        guard prev > 0 else { return nil }
        return Double(((curr - prev) / prev * 100) as NSDecimalNumber)
    }

    // MARK: – Spending trend (line chart)

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Spending Trend")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)
                Spacer()
                Text("\(dailySpending.count) days")
                    .font(.system(size: 12)).foregroundStyle(Color.bobInk2)
            }
            SpendingTrendChart(data: dailySpending, currencyCode: currencyCode,
                               color: reportKind == .expense ? .bobDebit : .bobAccent)
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Income vs Expenses bar chart

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Income vs Expenses")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)
            if monthlyData.isEmpty {
                Text("Not enough data yet").font(.bobBody).foregroundStyle(Color.bobInk3)
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.xl)
            } else {
                BarChartView(data: monthlyData, currencyCode: currencyCode)
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Period summary card (always shown at top)

    private var periodSummaryCard: some View {
        let incomeChange = pctChange(from: prevPeriodIncome, to: currentPeriodIncome)
        let expenseChange = pctChange(from: prevPeriodExpenses, to: currentPeriodExpenses)
        let currSavings = currentPeriodIncome - currentPeriodExpenses
        let prevSavings = prevPeriodIncome - prevPeriodExpenses
        let savingsChange = pctChange(from: prevSavings, to: currSavings)

        return VStack(spacing: 0) {
            HStack {
                Text("Period Summary")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bobInk2)
                Spacer()
                Text("vs prior period")
                    .font(.system(size: 11)).foregroundStyle(Color.bobInk3)
            }
            .padding(.bottom, Spacing.s)

            HStack(spacing: 0) {
                summaryStatCol(label: "Income", amount: currentPeriodIncome, change: incomeChange, positiveIsGood: true)
                Divider().frame(height: 40).padding(.horizontal, Spacing.m)
                summaryStatCol(label: "Expenses", amount: currentPeriodExpenses, change: expenseChange, positiveIsGood: false)
                Divider().frame(height: 40).padding(.horizontal, Spacing.m)
                summaryStatCol(label: "Savings", amount: currSavings, change: savingsChange, positiveIsGood: true)
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bobHairline, lineWidth: 1))
    }

    private func summaryStatCol(label: String, amount: Decimal, change: Double?, positiveIsGood: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11)).foregroundStyle(Color.bobInk3)
            Text(CurrencyFormatter.string(abs(amount as NSDecimalNumber as Decimal), code: currencyCode))
                .font(.system(size: 14, weight: .bold)).foregroundStyle(Color.bobInk).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            if let ch = change {
                let isGood = positiveIsGood ? ch >= 0 : ch <= 0
                HStack(spacing: 2) {
                    Image(systemName: ch >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "%.0f%%", abs(ch)))
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(isGood ? Color.bobAccent : Color.bobDebit)
            } else {
                Text("—").font(.system(size: 10)).foregroundStyle(Color.bobInk3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pctChange(from prev: Decimal, to curr: Decimal) -> Double? {
        let p = (prev as NSDecimalNumber).doubleValue
        guard abs(p) > 0.001 else { return nil }
        return ((curr as NSDecimalNumber).doubleValue - p) / abs(p) * 100
    }

    // MARK: – Budget vs actual

    private var budgetVsActualSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Budget vs Actual")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)
                Spacer()
                Text(CurrencyFormatter.string(budget, code: currencyCode) + " budget")
                    .font(.system(size: 12)).foregroundStyle(Color.bobInk3)
            }

            ForEach(Array(categoryData.enumerated()), id: \.element.category) { idx, item in
                budgetRow(item: item, index: idx)
            }

            let overallPct = budget > 0 ? min(Double((totalAmount / budget) as NSDecimalNumber) * 100, 999) : 0
            let remaining = budget - totalAmount
            HStack {
                Text("Total: \(CurrencyFormatter.string(totalAmount, code: currencyCode))")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bobInk)
                Spacer()
                Text(remaining >= 0
                     ? "\(CurrencyFormatter.string(remaining, code: currencyCode)) left"
                     : "\(CurrencyFormatter.string(abs(remaining as NSDecimalNumber as Decimal), code: currencyCode)) over")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(remaining >= 0 ? Color.bobAccent : Color.bobDebit)
            }
            .padding(.top, 4)
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func budgetRow(item: CategoryData, index: Int) -> some View {
        let share = budget > 0 ? min(Double((item.amount / budget) as NSDecimalNumber), 1.0) : 0
        let pct = Int(share * 100)
        let barColor: Color = pct >= 30 ? Color.bobDebit : pct >= 20 ? Color.bobHex(0xF59E0B) : chartPaletteColor(for: index)

        return VStack(spacing: 5) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(chartPaletteColor(for: index)).frame(width: 8, height: 8)
                    Text(item.category).font(.system(size: 13)).foregroundStyle(Color.bobInk)
                }
                Spacer()
                Text(CurrencyFormatter.string(item.amount, code: currencyCode))
                    .font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
                Text("\(pct)%").font(.system(size: 11)).foregroundStyle(Color.bobInk3)
                    .frame(width: 36, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.bobHairline).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(barColor)
                        .frame(width: geo.size.width * share, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: – Insights

    private var insights: [(icon: String, color: Color, text: String)] {
        var result: [(String, Color, String)] = []

        // Overall spending change
        if let change = pctChange(from: prevPeriodExpenses, to: currentPeriodExpenses) {
            if abs(change) > 10 {
                let isUp = change > 0
                result.append((
                    isUp ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                    isUp ? Color.bobDebit : Color.bobAccent,
                    "Overall \(reportKind == .expense ? "spending" : "income") is \(isUp ? "up" : "down") \(String(format: "%.0f%%", abs(change))) vs last period"
                ))
            }
        }

        // Biggest category increase
        if let top = categoryData.first(where: { cat in
            if let prev = previousPeriodData[cat.category], prev > 0 {
                return ((cat.amount - prev) / prev * 100 as NSDecimalNumber).doubleValue > 20
            }
            return false
        }) {
            let prev = previousPeriodData[top.category] ?? 0
            let change = (((top.amount - prev) / prev * 100) as NSDecimalNumber).doubleValue
            result.append((
                "arrow.up.right.circle.fill",
                Color.bobDebit,
                "\(top.category) is up \(String(format: "%.0f%%", change)) compared to last period"
            ))
        }

        // Biggest category decrease
        if let dropped = categoryData.first(where: { cat in
            if let prev = previousPeriodData[cat.category], prev > 0 {
                return ((prev - cat.amount) / prev * 100 as NSDecimalNumber).doubleValue > 20
            }
            return false
        }) {
            let prev = previousPeriodData[dropped.category] ?? 0
            let drop = (((prev - dropped.amount) / prev * 100) as NSDecimalNumber).doubleValue
            result.append((
                "arrow.down.right.circle.fill",
                Color.bobAccent,
                "\(dropped.category) is down \(String(format: "%.0f%%", drop)) — good progress"
            ))
        }

        return Array(result.prefix(3))
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Insights").eyebrow()

            VStack(spacing: Spacing.s) {
                ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                    HStack(spacing: 12) {
                        Image(systemName: insight.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(insight.color)
                            .frame(width: 24)
                        Text(insight.text)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.bobInk)
                        Spacer()
                    }
                    .padding(Spacing.m)
                    .background(insight.color.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: reportKind == .expense ? "chart.pie" : "arrow.down.circle")
                .font(.system(size: 52)).foregroundStyle(Color.bobInk3)
            Text("No \(reportKind == .expense ? "expenses" : "income") recorded for this period")
                .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.bobInk2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Spacing.xxl)
    }

    // MARK: – Monthly data

    private static let monthKeyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f
    }()

    private var monthlyData: [MonthlyData] {
        var dict: [String: (income: Decimal, expense: Decimal)] = [:]
        for expense in allExpenses {
            let key = Self.monthKeyFormatter.string(from: expense.date)
            let current = dict[key] ?? (0, 0)
            dict[key] = expense.kind == .income
                ? (current.0 + expense.amount, current.1)
                : (current.0, current.1 + expense.amount)
        }
        return dict.map { MonthlyData(month: $0.key, income: $0.value.0, expense: $0.value.1) }
            .sorted { $0.month < $1.month }.suffix(6).map { $0 }
    }

    // MARK: – Period helpers

    private func isInPeriod(_ date: Date) -> Bool {
        let cal = Calendar.current
        switch selectedPeriod {
        case .currentMonth:
            let b = MonthSummary.currentMonthBounds(); return date >= b.start && date <= b.end
        case .lastMonth:
            let b = MonthSummary.currentMonthBounds()
            guard let s = cal.date(byAdding: .month, value: -1, to: b.start) else { return false }
            return date >= s && date < b.start
        case .last3Months:
            guard let ago = cal.date(byAdding: .month, value: -3, to: Date()) else { return false }
            return date >= ago
        case .last6Months:
            guard let ago = cal.date(byAdding: .month, value: -6, to: Date()) else { return false }
            return date >= ago
        case .year:
            return cal.component(.year, from: date) == cal.component(.year, from: Date())
        }
    }

    private func isInPreviousPeriod(_ date: Date) -> Bool {
        let cal = Calendar.current
        switch selectedPeriod {
        case .currentMonth:
            let b = MonthSummary.currentMonthBounds()
            guard let s = cal.date(byAdding: .month, value: -1, to: b.start) else { return false }
            return date >= s && date < b.start
        case .lastMonth:
            let b = MonthSummary.currentMonthBounds()
            guard let s = cal.date(byAdding: .month, value: -2, to: b.start),
                  let e = cal.date(byAdding: .month, value: -1, to: b.start) else { return false }
            return date >= s && date < e
        case .last3Months:
            guard let s = cal.date(byAdding: .month, value: -6, to: Date()),
                  let e = cal.date(byAdding: .month, value: -3, to: Date()) else { return false }
            return date >= s && date < e
        case .last6Months:
            guard let s = cal.date(byAdding: .month, value: -12, to: Date()),
                  let e = cal.date(byAdding: .month, value: -6, to: Date()) else { return false }
            return date >= s && date < e
        case .year:
            return cal.component(.year, from: date) == cal.component(.year, from: Date()) - 1
        }
    }
}

// MARK: – Chart display type

enum ChartDisplayType: String, CaseIterable {
    case donut, pie, bars

    var label: String {
        switch self { case .donut: return "Donut"; case .pie: return "Pie"; case .bars: return "Bars" }
    }

    var icon: String {
        switch self {
        case .donut: return "circle.dashed"
        case .pie:   return "chart.pie.fill"
        case .bars:  return "chart.bar.xaxis"
        }
    }
}

// MARK: – Filled pie chart with external labels

struct FilledPieChart: View {
    let data: [CategoryData]
    let currencyCode: String
    @Binding var selectedIndex: Int?

    private var total: Decimal { data.reduce(0) { $0 + $1.amount } }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let cy = h / 2
            let radius: CGFloat = min(w, h) * 0.30

            ZStack {
                // Filled segments
                ForEach(0..<data.count, id: \.self) { idx in
                    PieSegmentShape(
                        startAngle: segmentStart(idx),
                        endAngle: segmentEnd(idx)
                    )
                    .fill(chartPaletteColor(for: idx))
                    .opacity(selectedIndex == nil || selectedIndex == idx ? 1.0 : 0.45)
                    .scaleEffect(selectedIndex == idx ? 1.06 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
                    .onTapGesture {
                        withAnimation { selectedIndex = selectedIndex == idx ? nil : idx }
                    }
                }

                // % labels inside large segments
                ForEach(0..<data.count, id: \.self) { idx in
                    let pct = pctInt(idx)
                    if pct >= 12 {
                        let mid = midAngle(idx)
                        Text("\(pct)%")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                            .position(
                                x: cx + cos(mid) * radius * 0.65,
                                y: cy + sin(mid) * radius * 0.65
                            )
                    }
                }

                // Leader lines to external labels
                ForEach(0..<data.count, id: \.self) { idx in
                    let pct = pctInt(idx)
                    if pct >= 8 {
                        let mid = midAngle(idx)
                        let innerPt = CGPoint(x: cx + cos(mid) * radius, y: cy + sin(mid) * radius)
                        let elbowPt = CGPoint(x: cx + cos(mid) * (radius + 14), y: cy + sin(mid) * (radius + 14))

                        Path { p in
                            p.move(to: innerPt)
                            p.addLine(to: elbowPt)
                        }
                        .stroke(chartPaletteColor(for: idx), lineWidth: 1.5)

                        let isRight = cos(mid) >= 0
                        let labelX = cx + cos(mid) * (radius + 46)
                        let labelY = cy + sin(mid) * (radius + 46)

                        VStack(alignment: isRight ? .leading : .trailing, spacing: 2) {
                            Text(data[idx].category)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.bobInk)
                                .lineLimit(1)
                            Text(CurrencyFormatter.string(data[idx].amount, code: currencyCode))
                                .font(.system(size: 10))
                                .foregroundStyle(Color.bobInk2)
                        }
                        .fixedSize()
                        .position(x: labelX, y: labelY)
                    }
                }
            }
        }
        .frame(height: 300)
    }

    private func segmentStart(_ idx: Int) -> Double {
        guard total > 0 else { return 0 }
        let pre = data.prefix(idx).reduce(Decimal(0)) { $0 + $1.amount }
        return -.pi / 2 + Double((pre / total) as NSDecimalNumber) * 2 * .pi
    }

    private func segmentEnd(_ idx: Int) -> Double {
        guard total > 0 else { return 0 }
        let inc = data.prefix(idx + 1).reduce(Decimal(0)) { $0 + $1.amount }
        return -.pi / 2 + Double((inc / total) as NSDecimalNumber) * 2 * .pi
    }

    private func midAngle(_ idx: Int) -> Double {
        (segmentStart(idx) + segmentEnd(idx)) / 2
    }

    private func pctInt(_ idx: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int(Double((data[idx].amount / total * 100) as NSDecimalNumber))
    }
}

// MARK: – Pie segment shape

struct PieSegmentShape: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius,
                    startAngle: .radians(startAngle), endAngle: .radians(endAngle), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: – Horizontal bars chart

struct HorizontalBarsChart: View {
    let data: [CategoryData]
    let total: Decimal
    let currencyCode: String

    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(data.enumerated()), id: \.element.category) { idx, item in
                VStack(spacing: 6) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(chartPaletteColor(for: idx)).frame(width: 8, height: 8)
                            Text(item.category)
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bobInk)
                        }
                        Spacer()
                        Text(CurrencyFormatter.string(item.amount, code: currencyCode))
                            .font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
                        Text(pctLabel(item))
                            .font(.system(size: 11)).foregroundStyle(Color.bobInk3)
                            .frame(width: 36, alignment: .trailing)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.bobHairline).frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [chartPaletteColor(for: idx).opacity(0.7), chartPaletteColor(for: idx)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * barWidth(item), height: 8)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: item.amount)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }

    private func barWidth(_ item: CategoryData) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(Double((item.amount / total) as NSDecimalNumber))
    }

    private func pctLabel(_ item: CategoryData) -> String {
        guard total > 0 else { return "0%" }
        let pct = Int(Double((item.amount / total * 100) as NSDecimalNumber))
        return "\(pct)%"
    }
}

// MARK: – Spending trend line chart

struct SpendingTrendChart: View {
    let data: [(date: Date, amount: Decimal)]
    let currencyCode: String
    let color: Color

    private var maxAmount: Decimal { data.map { $0.amount }.max() ?? 1 }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // Horizontal grid lines
                    ForEach([0.25, 0.5, 0.75], id: \.self) { pct in
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: h * (1 - pct)))
                            p.addLine(to: CGPoint(x: w, y: h * (1 - pct)))
                        }
                        .stroke(Color.bobHairline, lineWidth: 0.5)
                    }

                    // Area fill
                    areaPath(w: w, h: h)
                        .fill(LinearGradient(
                            colors: [color.opacity(0.25), color.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        ))

                    // Line
                    linePath(w: w, h: h)
                        .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    // Dots
                    ForEach(0..<data.count, id: \.self) { idx in
                        Circle()
                            .fill(color)
                            .frame(width: data.count > 14 ? 4 : 6, height: data.count > 14 ? 4 : 6)
                            .position(x: xPos(idx, w), y: yPos(data[idx].amount, h))
                    }
                }
            }
            .frame(height: 100)

            // X-axis labels (show first, mid, last)
            if data.count >= 2 {
                HStack {
                    Text(shortDate(data.first!.date)).font(.system(size: 10)).foregroundStyle(Color.bobInk3)
                    Spacer()
                    if data.count > 4 {
                        Text(shortDate(data[data.count / 2].date)).font(.system(size: 10)).foregroundStyle(Color.bobInk3)
                    }
                    Spacer()
                    Text(shortDate(data.last!.date)).font(.system(size: 10)).foregroundStyle(Color.bobInk3)
                }
            }
        }
    }

    private func xPos(_ idx: Int, _ w: CGFloat) -> CGFloat {
        guard data.count > 1 else { return w / 2 }
        return CGFloat(idx) / CGFloat(data.count - 1) * w
    }

    private func yPos(_ amount: Decimal, _ h: CGFloat) -> CGFloat {
        guard maxAmount > 0 else { return h }
        let ratio = CGFloat(Double((amount / maxAmount) as NSDecimalNumber))
        return h - ratio * h * 0.88 - h * 0.06
    }

    private func linePath(w: CGFloat, h: CGFloat) -> Path {
        var path = Path()
        for (idx, item) in data.enumerated() {
            let pt = CGPoint(x: xPos(idx, w), y: yPos(item.amount, h))
            idx == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        return path
    }

    private func areaPath(w: CGFloat, h: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h))
        for (idx, item) in data.enumerated() {
            path.addLine(to: CGPoint(x: xPos(idx, w), y: yPos(item.amount, h)))
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d MMM"; return f.string(from: date)
    }
}

// MARK: – Category card

struct CategoryCard: View {
    let item: CategoryData
    let index: Int
    let total: Decimal
    let momChange: Double?
    let isExpense: Bool
    let currencyCode: String
    let isSelected: Bool
    let onTap: () -> Void
    var onDrillDown: (() -> Void)? = nil

    private var pct: Int {
        guard total > 0 else { return 0 }
        return Int(Double((item.amount / total * 100) as NSDecimalNumber))
    }

    private var barProgress: Double {
        guard total > 0 else { return 0 }
        return Double((item.amount / total) as NSDecimalNumber)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(chartPaletteColor(for: index)).frame(width: 44, height: 44)
                        Image(systemName: item.symbol)
                            .font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.category)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bobInk).lineLimit(1)
                        Text("\(pct)% of total").font(.system(size: 12)).foregroundStyle(Color.bobInk3)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(CurrencyFormatter.string(item.amount, code: currencyCode))
                            .font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
                        momBadge
                    }
                    if let drill = onDrillDown {
                        Button(action: drill) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.bobInk3)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.bobHairline).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(chartPaletteColor(for: index))
                            .frame(width: geo.size.width * barProgress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(Spacing.m)
            .background(Color.bobSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? chartPaletteColor(for: index) : Color.bobHairline,
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var momBadge: some View {
        if let change = momChange {
            let green = isExpense ? change < 0 : change >= 0
            let label = String(format: "%@%.0f%%", change >= 0 ? "+" : "", change)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(green ? Color.bobAccent : Color.bobDebit)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(green ? Color.bobAccent.opacity(0.12) : Color.bobDebit.opacity(0.12)))
        }
    }
}

// MARK: – Bar chart (Income vs Expenses)

struct BarChartView: View {
    let data: [MonthlyData]
    let currencyCode: String

    private var maxValue: Decimal {
        max(data.map { $0.income }.max() ?? 0, data.map { $0.expense }.max() ?? 0)
    }

    var body: some View {
        VStack(spacing: Spacing.m) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<data.count, id: \.self) { idx in
                    VStack(spacing: 4) {
                        HStack(alignment: .bottom, spacing: 2) {
                            bar(height: barH(data[idx].expense), color: Color.bobOverBudget)
                            bar(height: barH(data[idx].income),  color: Color.bobAccent)
                        }
                        Text(monthLabel(for: data[idx].month)).font(.system(size: 10)).foregroundStyle(Color.bobInk3)
                    }
                }
            }
            .frame(height: 110)

            HStack(spacing: 20) {
                legendDot(color: .bobAccent,     label: "Income")
                legendDot(color: .bobOverBudget, label: "Expenses")
            }
        }
    }

    private func bar(height: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 16, height: max(height, 4))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 12)).foregroundStyle(Color.bobInk3)
        }
    }

    private func barH(for amount: Decimal) -> CGFloat {
        guard maxValue > 0 else { return 4 }
        return CGFloat(Double((amount / maxValue) as NSDecimalNumber)) * 80
    }

    private func barH(_ amount: Decimal) -> CGFloat { barH(for: amount) }

    private func monthLabel(for key: String) -> String {
        let p = DateFormatter(); p.dateFormat = "yyyy-MM"
        guard let date = p.date(from: key) else { return key }
        let f = DateFormatter(); f.dateFormat = "MMM"
        return f.string(from: date)
    }
}

// MARK: – Shared palette function

private func chartPaletteColor(for index: Int) -> Color {
    let palette: [Color] = [
        Color.bobHex(0xE0413B), Color.bobHex(0x4FC3F7), Color.bobHex(0xFFB74D),
        Color.bobHex(0x81C784), Color.bobHex(0xBA68C8), Color.bobHex(0xFF8A65),
        Color.bobHex(0x4DD0E1), Color.bobHex(0xF06292)
    ]
    return palette[index % palette.count]
}

// MARK: – Supporting types

enum AnalyticsPeriod: String, CaseIterable {
    case currentMonth = "current_month"
    case lastMonth    = "last_month"
    case last3Months  = "last_3_months"
    case last6Months  = "last_6_months"
    case year         = "year"

    var label: String {
        switch self {
        case .currentMonth: return "This Month"
        case .lastMonth:    return "Last Month"
        case .last3Months:  return "3 Months"
        case .last6Months:  return "6 Months"
        case .year:         return "Year"
        }
    }
}

struct CategoryData: Identifiable, Hashable {
    var id: String { category }
    let category: String
    let amount: Decimal
    let symbol: String
}

struct MonthlyData {
    let month: String
    let income: Decimal
    let expense: Decimal
}

#Preview {
    AnalyticsView()
        .modelContainer(for: [Expense.self, ExpenseCategory.self, BudgetSettings.self], inMemory: true)
}
