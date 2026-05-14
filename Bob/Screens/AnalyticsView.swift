import SwiftUI
import SwiftData

// MARK: – Main view

struct AnalyticsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]

    @State private var selectedPeriod: AnalyticsPeriod = .currentMonth
    @State private var reportKind: TransactionKind = .expense
    @State private var selectedCategoryIndex: Int? = nil
    @State private var chartType: ChartDisplayType = .donut
    @State private var drilldownCategory: CategoryData? = nil
    @State private var editingTransaction: Expense? = nil
    @State private var selectedCarouselPage: Int = 0

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

    private var spendingStreak: Int {
        guard avgDailySpend > 0 else { return 0 }
        let cal = Calendar.current
        let sorted = dailySpending.sorted { $0.date > $1.date }
        var streak = 0
        for day in sorted {
            if day.amount <= avgDailySpend { streak += 1 } else { break }
        }
        return streak
    }

    private var incomeSourceBreakdown: [(name: String, amount: Decimal, pct: Double)] {
        guard reportKind == .income, totalAmount > 0 else { return [] }
        return categoryData.map { cat in
            let pct = Double((cat.amount / totalAmount) as NSDecimalNumber) * 100
            return (name: cat.category, amount: cat.amount, pct: pct)
        }
    }

    private var monthOverMonthTrend: [(month: String, amount: Decimal)] {
        let df = DateFormatter(); df.dateFormat = "MMM"
        let cal = Calendar.current
        return (0..<6).reversed().compactMap { offset -> (String, Decimal)? in
            guard let date = cal.date(byAdding: .month, value: -offset, to: Date()),
                  let start = cal.date(from: cal.dateComponents([.year, .month], from: date)),
                  let end   = cal.date(byAdding: .month, value: 1, to: start) else { return nil }
            let total = allExpenses.filter { $0.kind == reportKind && $0.date >= start && $0.date < end }
                                   .reduce(Decimal(0)) { $0 + $1.amount }
            return (df.string(from: date), total)
        }
    }

    // MARK: – Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        analyticsTopBar
                            .padding(.horizontal, 20)
                            .padding(.top, 18)

                        Text("Analytics")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 34)

                        analyticsFilterRow
                            .padding(.horizontal, 20)
                            .padding(.top, 54)

                        analyticsCarousel
                            .padding(.top, 24)

                        carouselDots
                            .padding(.top, 18)
                            .frame(maxWidth: .infinity)

                        overviewSection
                            .padding(.horizontal, 20)
                            .padding(.top, 50)

                        if !categoryData.isEmpty {
                            darkCategorySection
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                        }

                        Spacer().frame(height: 120)
                    }
                }
            }
            .navigationBarHidden(true)
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
        .sheet(item: $editingTransaction) { tx in
            AddTransactionSheet(currencyCode: currencyCode, expenseToEdit: tx)
        }
        .onChange(of: reportKind)     { _, _ in withAnimation { selectedCategoryIndex = nil } }
        .onChange(of: selectedPeriod) { _, _ in withAnimation { selectedCategoryIndex = nil } }
    }

    // MARK: – Redesigned analytics

    private var analyticsTopBar: some View {
        Button { dismiss() } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private var analyticsFilterRow: some View {
        HStack(alignment: .center) {
            Menu {
                Button("Savings") { reportKind = .expense }
                Button("Income") { reportKind = .income }
            } label: {
                HStack(spacing: 12) {
                    Text(reportKind == .expense ? "SAVINGS" : "INCOME")
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                    Button(period.label) { selectedPeriod = period }
                }
            } label: {
                Text(selectedPeriod.label)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.bobHex(0x7EA2FF))
            }
            .buttonStyle(.plain)
        }
    }

    private var analyticsCarousel: some View {
        TabView(selection: $selectedCarouselPage) {
            analyticsSlide(
                large: .spent,
                firstSmall: .income,
                secondSmall: .netCashFlow
            )
            .tag(0)

            analyticsSlide(
                large: .income,
                firstSmall: .spent,
                secondSmall: .savingsRate
            )
            .tag(1)

            analyticsSlide(
                large: .netCashFlow,
                firstSmall: .assets,
                secondSmall: .spent
            )
            .tag(2)

            analyticsSlide(
                large: .savingsRate,
                firstSmall: .income,
                secondSmall: .netCashFlow
            )
            .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 438)
    }

    private func analyticsSlide(large: AnalyticsCardKind, firstSmall: AnalyticsCardKind, secondSmall: AnalyticsCardKind) -> some View {
        VStack(spacing: 20) {
            analyticsMetricCard(kind: large, isLarge: true)
                .frame(height: 208)

            HStack(spacing: 20) {
                analyticsMetricCard(kind: firstSmall, isLarge: false)
                analyticsMetricCard(kind: secondSmall, isLarge: false)
            }
            .frame(height: 190)
        }
        .padding(.horizontal, 20)
    }

    private func analyticsMetricCard(kind: AnalyticsCardKind, isLarge: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kind.title)
                .font(.system(size: isLarge ? 20 : 19, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.58))

            Text(primaryValue(for: kind))
                .font(.system(size: isLarge ? 38 : 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .padding(.top, 2)

            metricDelta(for: kind)
                .padding(.top, isLarge ? 2 : 8)

            Spacer(minLength: 10)

            metricVisualization(for: kind, isLarge: isLarge)
                .frame(height: isLarge ? 76 : 70)
        }
        .padding(.horizontal, isLarge ? 20 : 18)
        .padding(.top, isLarge ? 18 : 18)
        .padding(.bottom, isLarge ? 18 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.bobHex(0x18181B))
        )
    }

    @ViewBuilder
    private func metricDelta(for kind: AnalyticsCardKind) -> some View {
        switch kind {
        case .spent:
            let change = currentPeriodExpenses - prevPeriodExpenses
            let isDown = change <= 0
            if prevPeriodExpenses > 0 {
                HStack(spacing: 6) {
                    Image(systemName: isDown ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(CurrencyFormatter.string(abs(change as NSDecimalNumber as Decimal), code: currencyCode))
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                }
                .foregroundStyle(isDown ? Color.bobGreen.opacity(0.88) : Color.bobDebit.opacity(0.95))
            }
        case .income:
            let change = currentPeriodIncome - prevPeriodIncome
            if prevPeriodIncome > 0 {
                HStack(spacing: 6) {
                    Image(systemName: change >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(CurrencyFormatter.string(abs(change as NSDecimalNumber as Decimal), code: currencyCode))
                        .font(.system(size: 18, weight: .bold))
                        .monospacedDigit()
                }
                .foregroundStyle(change >= 0 ? Color.bobGreen.opacity(0.88) : Color.bobDebit.opacity(0.95))
            }
        case .netCashFlow:
            HStack(spacing: 7) {
                Image(systemName: netCashFlow >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                Text(netCashFlow >= 0 ? "Positive" : "Negative")
                    .font(.system(size: 19, weight: .bold))
            }
            .foregroundStyle(netCashFlow >= 0 ? Color.bobGreen.opacity(0.88) : Color.bobDebit.opacity(0.95))
        case .assets:
            EmptyView()
        case .savingsRate:
            HStack(spacing: 7) {
                Image(systemName: savingsRatePct >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                Text(savingsRatePct >= 0 ? "Positive" : "Tight")
                    .font(.system(size: 19, weight: .bold))
            }
            .foregroundStyle(savingsRatePct >= 0 ? Color.bobGreen.opacity(0.88) : Color.bobDebit.opacity(0.95))
        }
    }

    @ViewBuilder
    private func metricVisualization(for kind: AnalyticsCardKind, isLarge: Bool) -> some View {
        switch kind {
        case .spent:
            darkLineChart(data: cumulativeSeries(kind: .expense), color: Color.bobGreen.opacity(0.92), dashedAfterCurrentDay: true)
        case .income:
            miniVerticalBars(values: incomeBarValues)
        case .netCashFlow:
            cashFlowBars
        case .assets:
            singleProgressBar(color: Color.bobHex(0x66D9E8), progress: assetProgress)
        case .savingsRate:
            singleProgressBar(color: savingsRatePct >= 0 ? Color.bobGreen : Color.bobDebit, progress: min(max(abs(savingsRatePct) / 100, 0.08), 1))
        }
    }

    private var carouselDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { idx in
                Circle()
                    .fill(idx == selectedCarouselPage ? Color.white.opacity(0.56) : Color.white.opacity(0.22))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Overview")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 0) {
                Text("Total assets")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.58))
                Text(CurrencyFormatter.string(totalAssets, code: currencyCode))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.top, 4)

                Spacer()

                singleProgressBar(color: Color.bobHex(0x66D9E8), progress: assetProgress)
                    .frame(height: 38)

                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.bobHex(0x66D9E8))
                        .frame(width: 12, height: 12)
                    Text("Linked")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .padding(22)
            .frame(height: 230)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.bobHex(0x18181B)))
        }
    }

    private var darkCategorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top categories")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                ForEach(Array(categoryData.prefix(5).enumerated()), id: \.element.category) { idx, item in
                    HStack(spacing: 14) {
                        Circle()
                            .fill(chartPaletteColor(for: idx))
                            .frame(width: 12, height: 12)
                        Text(item.category)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(CurrencyFormatter.string(item.amount, code: currencyCode))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.76))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 18)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.bobHex(0x18181B)))
        }
    }

    private var netCashFlow: Decimal {
        currentPeriodIncome - currentPeriodExpenses
    }

    private var totalAssets: Decimal {
        max(netCashFlow, 0)
    }

    private var assetProgress: Double {
        let income = (currentPeriodIncome as NSDecimalNumber).doubleValue
        guard income > 0 else { return totalAssets > 0 ? 1 : 0.08 }
        return min(max((totalAssets as NSDecimalNumber).doubleValue / income, 0.08), 1)
    }

    private var incomeBarValues: [Decimal] {
        let series = cumulativeSeries(kind: .income)
        guard !series.isEmpty else { return [0, 0, 0, 0, 0] }
        let count = min(series.count, 5)
        return (0..<count).map { idx in
            let sourceIndex = Int((Double(idx) / Double(max(count - 1, 1))) * Double(series.count - 1))
            return series[sourceIndex].amount
        }
    }

    private func primaryValue(for kind: AnalyticsCardKind) -> String {
        switch kind {
        case .spent:
            return CurrencyFormatter.string(currentPeriodExpenses, code: currencyCode)
        case .income:
            return CurrencyFormatter.string(currentPeriodIncome, code: currencyCode)
        case .netCashFlow:
            return CurrencyFormatter.string(abs(netCashFlow as NSDecimalNumber as Decimal), code: currencyCode)
        case .assets:
            return CurrencyFormatter.string(totalAssets, code: currencyCode)
        case .savingsRate:
            return currentPeriodIncome > 0 ? String(format: "%.0f%%", savingsRatePct) : "0%"
        }
    }

    private func cumulativeSeries(kind: TransactionKind) -> [(day: Int, amount: Decimal)] {
        let cal = Calendar.current
        let bounds = boundsForSelectedPeriod
        let transactions = allExpenses.filter { $0.kind == kind && $0.date >= bounds.start && $0.date < bounds.end }
        let dayCount = max(cal.dateComponents([.day], from: bounds.start, to: bounds.end).day ?? 1, 1)
        var dailyTotals: [Int: Decimal] = [:]

        for tx in transactions {
            let day = min(max((cal.dateComponents([.day], from: bounds.start, to: tx.date).day ?? 0) + 1, 1), dayCount)
            dailyTotals[day, default: 0] += tx.amount
        }

        var cumulative: Decimal = 0
        return (1...dayCount).map { day in
            cumulative += dailyTotals[day] ?? 0
            return (day: day, amount: cumulative)
        }
    }

    private var boundsForSelectedPeriod: (start: Date, end: Date) {
        let cal = Calendar.current
        let month = MonthSummary.currentMonthBounds()
        switch selectedPeriod {
        case .currentMonth:
            return month
        case .lastMonth:
            let start = cal.date(byAdding: .month, value: -1, to: month.start) ?? month.start
            return (start, month.start)
        case .last3Months:
            let start = cal.date(byAdding: .month, value: -3, to: Date()) ?? month.start
            return (cal.startOfDay(for: start), Date())
        case .last6Months:
            let start = cal.date(byAdding: .month, value: -6, to: Date()) ?? month.start
            return (cal.startOfDay(for: start), Date())
        case .year:
            let comps = cal.dateComponents([.year], from: Date())
            let start = cal.date(from: comps) ?? month.start
            let end = cal.date(byAdding: .year, value: 1, to: start) ?? Date()
            return (start, end)
        }
    }

    private var currentDayInSelectedPeriod: Int {
        let cal = Calendar.current
        let bounds = boundsForSelectedPeriod
        let totalDays = max(cal.dateComponents([.day], from: bounds.start, to: bounds.end).day ?? 1, 1)
        guard Date() >= bounds.start && Date() < bounds.end else { return totalDays }
        return min(max((cal.dateComponents([.day], from: bounds.start, to: Date()).day ?? 0) + 1, 1), totalDays)
    }

    private func darkLineChart(data: [(day: Int, amount: Decimal)], color: Color, dashedAfterCurrentDay: Bool) -> some View {
        let maxAmount = max(((data.map(\.amount).max() ?? Decimal(1)) as NSDecimalNumber).doubleValue, 1)
        let currentDay = dashedAfterCurrentDay ? currentDayInSelectedPeriod : data.count
        let actual = data.filter { $0.day <= currentDay }
        let projected = projectedSeries(from: data, currentDay: currentDay)

        return VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height

                ZStack {
                    if projected.count > 1 {
                        analyticsLinePath(data: projected, width: width, height: height, maxAmount: maxAmount)
                            .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [5, 7]))
                    }

                    if actual.count > 1 {
                        analyticsLinePath(data: actual, width: width, height: height, maxAmount: maxAmount)
                            .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

                        if let last = actual.last {
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                                .position(analyticsPoint(last, width: width, height: height, maxAmount: maxAmount, count: max(data.count, 2)))
                        }
                    }
                }
            }

            HStack {
                ForEach(axisLabels(for: max(data.count, 2)), id: \.self) { day in
                    Text("\(day)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.54))
                        .frame(maxWidth: .infinity, alignment: day == 1 ? .leading : day == max(data.count, 2) ? .trailing : .center)
                }
            }
        }
    }

    private func projectedSeries(from data: [(day: Int, amount: Decimal)], currentDay: Int) -> [(day: Int, amount: Decimal)] {
        guard !data.isEmpty else { return [] }
        let totalDays = data.count
        let currentIndex = min(max(currentDay - 1, 0), totalDays - 1)
        let currentAmount = data[currentIndex].amount
        guard currentDay < totalDays else { return data }

        let projectedTotal = currentAmount / Decimal(max(currentDay, 1)) * Decimal(totalDays)
        return (1...totalDays).map { day in
            if day <= currentDay { return data[day - 1] }
            let progress = Decimal(day - currentDay) / Decimal(max(totalDays - currentDay, 1))
            return (day: day, amount: currentAmount + ((projectedTotal - currentAmount) * progress))
        }
    }

    private func analyticsLinePath(data: [(day: Int, amount: Decimal)], width: CGFloat, height: CGFloat, maxAmount: Double) -> Path {
        var path = Path()
        let count = max(cumulativeSeries(kind: .expense).count, data.count, 2)
        for (index, item) in data.enumerated() {
            let point = analyticsPoint(item, width: width, height: height, maxAmount: maxAmount, count: count)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }

    private func analyticsPoint(_ item: (day: Int, amount: Decimal), width: CGFloat, height: CGFloat, maxAmount: Double, count: Int) -> CGPoint {
        let x = CGFloat(item.day - 1) / CGFloat(max(count - 1, 1)) * width
        let value = (item.amount as NSDecimalNumber).doubleValue
        let normalized = min(max(value / max(maxAmount, 1), 0), 1)
        let y = height - CGFloat(normalized) * height * 0.72 - height * 0.14
        return CGPoint(x: x, y: y)
    }

    private func axisLabels(for days: Int) -> [Int] {
        let labels = [1, 6, 11, 16, 21, 26, days]
        return labels.reduce(into: [Int]()) { result, day in
            let clamped = min(max(day, 1), days)
            if result.last != clamped { result.append(clamped) }
        }
    }

    private func miniVerticalBars(values: [Decimal]) -> some View {
        let maxValue = max(((values.max() ?? Decimal(1)) as NSDecimalNumber).doubleValue, 1)
        return HStack(alignment: .bottom, spacing: 26) {
            ForEach(Array(values.enumerated()), id: \.offset) { idx, value in
                let ratio = (value as NSDecimalNumber).doubleValue / maxValue
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(idx == 0 ? Color.white.opacity(0.42) : Color.white.opacity(0.07))
                    .frame(width: 10, height: max(CGFloat(ratio) * 62, 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cashFlowBars: some View {
        let income = max((currentPeriodIncome as NSDecimalNumber).doubleValue, 1)
        let expenseRatio = min((currentPeriodExpenses as NSDecimalNumber).doubleValue / income, 1)
        return VStack(spacing: 20) {
            singleProgressBar(color: Color.bobGreen.opacity(0.92), progress: min(max((netCashFlow as NSDecimalNumber).doubleValue / income, 0.08), 1))
                .frame(height: 12)
            singleProgressBar(color: Color.bobDebit.opacity(0.95), progress: max(expenseRatio, 0.08))
                .frame(height: 12)
        }
    }

    private func singleProgressBar(color: Color, progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
    }

    // MARK: – Spending streak + 6-month trend card
    private var streakAndTrendSection: some View {
        VStack(spacing: Spacing.m) {
            // Streak row
            if spendingStreak > 0 {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.bobGreen.opacity(0.18)).frame(width: 44, height: 44)
                        Image(systemName: "flame.fill").font(.system(size: 20)).foregroundStyle(Color.bobGreen)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(spendingStreak)-day streak")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bobInk)
                        Text("Consecutive days at or under daily average")
                            .font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                    }
                    Spacer()
                }
                .padding(Spacing.m)
                .background(Color.bobGreen.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 6-month trend mini bars
            VStack(alignment: .leading, spacing: 10) {
                Text("6-Month Trend")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bobInk)

                let trend = monthOverMonthTrend
                let peak = trend.map { ($0.amount as NSDecimalNumber).doubleValue }.max() ?? 1

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(trend.enumerated()), id: \.offset) { idx, item in
                        VStack(spacing: 4) {
                            let h = max(CGFloat((item.amount as NSDecimalNumber).doubleValue / peak) * 64, 4)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: idx == trend.count - 1
                                            ? [reportKind == .expense ? Color.bobDebit : Color.bobGreen,
                                               (reportKind == .expense ? Color.bobDebit : Color.bobGreen).opacity(0.6)]
                                            : [Color.bobSurface2, Color.bobSurface2],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(width: 26, height: h)
                            Text(item.month)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(idx == trend.count - 1 ? Color.bobInk : Color.bobInk3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 80)
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Page header (consistent across tabs)

    private func pageHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.bobInk)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bobInk2)
            }
            Spacer()
        }
        .padding(.top, 8)
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

    private var savingsRatePct: Double {
        let inc = (currentPeriodIncome as NSDecimalNumber).doubleValue
        guard inc > 0 else { return 0 }
        let exp = (currentPeriodExpenses as NSDecimalNumber).doubleValue
        return ((inc - exp) / inc) * 100
    }

    private var keyMetricsRow: some View {
        HStack(spacing: Spacing.s) {
            metricTile(
                icon: reportKind == .expense ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                iconColor: reportKind == .expense ? .bobDebit : .bobAccent,
                value: CurrencyFormatter.compact(totalAmount, code: currencyCode),
                label: reportKind == .expense ? "Total Spent" : "Total Earned"
            )
            metricTile(
                icon: "calendar.badge.clock",
                iconColor: Color.bobHex(0x1A73E8),
                value: avgDailySpend > 0 ? CurrencyFormatter.compact(avgDailySpend, code: currencyCode) : "—",
                label: "Daily Avg"
            )
            let rate = savingsRatePct
            metricTile(
                icon: rate >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill",
                iconColor: rate >= 0 ? .bobAccent : .bobDebit,
                value: currentPeriodIncome > 0 ? String(format: "%.0f%%", rate) : "—",
                label: "Savings Rate"
            )
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
                Text("Not enough data yet").font(.bobBody).foregroundStyle(Color.bobInk2)
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
                    .font(.system(size: 11)).foregroundStyle(Color.bobInk2)
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
            Text(label).font(.system(size: 11)).foregroundStyle(Color.bobInk2)
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
                Text("—").font(.system(size: 10)).foregroundStyle(Color.bobInk2)
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
                    .font(.system(size: 12)).foregroundStyle(Color.bobInk2)
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
                Text("\(pct)%").font(.system(size: 11)).foregroundStyle(Color.bobInk2)
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

    // MARK: – Weekly breakdown (current/last month only)

    private var weeklyBreakdown: [(label: String, range: String, amount: Decimal)] {
        let cal = Calendar.current
        // Determine the month bounds
        let bounds: (start: Date, end: Date)
        if selectedPeriod == .currentMonth {
            bounds = MonthSummary.currentMonthBounds()
        } else { // lastMonth
            let b = MonthSummary.currentMonthBounds()
            let s = cal.date(byAdding: .month, value: -1, to: b.start) ?? b.start
            bounds = (s, b.start)
        }

        let txns = allExpenses.filter { $0.kind == reportKind && $0.date >= bounds.start && $0.date < bounds.end }
        var weeks: [(String, String, Decimal)] = []
        var weekStart = bounds.start
        var weekNum = 1
        let df = DateFormatter(); df.dateFormat = "MMM d"
        while weekStart < bounds.end {
            let weekEnd = min(cal.date(byAdding: .day, value: 7, to: weekStart) ?? bounds.end, bounds.end)
            let total = txns.filter { $0.date >= weekStart && $0.date < weekEnd }.reduce(0) { $0 + $1.amount }
            let label = "Week \(weekNum)"
            let range = "\(df.string(from: weekStart))–\(df.string(from: cal.date(byAdding: .day, value: -1, to: weekEnd) ?? weekEnd))"
            weeks.append((label, range, total))
            weekStart = weekEnd
            weekNum += 1
        }
        return weeks.filter { $0.2 > 0 }
    }

    private var weeklyBreakdownSection: some View {
        let weeks = weeklyBreakdown
        let peak = weeks.map { $0.2 }.max() ?? 1
        return VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Weekly Breakdown").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)
            if weeks.isEmpty {
                Text("No data").font(.bobBody).foregroundStyle(Color.bobInk2)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(week.0).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bobInk)
                                Text(week.1).font(.system(size: 10)).foregroundStyle(Color.bobInk2)
                            }
                            .frame(width: 80, alignment: .leading)
                            GeometryReader { geo in
                                let w = geo.size.width * CGFloat(Double((week.2 / peak) as NSDecimalNumber))
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.bobHairline).frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(reportKind == .expense ? Color.bobDebit : Color.bobAccent)
                                        .frame(width: w, height: 8)
                                }
                            }.frame(height: 8)
                            Text(CurrencyFormatter.compact(week.2, code: currencyCode))
                                .font(.system(size: 12, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
                                .frame(width: 56, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Recurring vs One-time

    @Query(sort: \RecurringTransaction.nextDueDate) private var allRecurrings: [RecurringTransaction]

    private var recurringVsOneTimeSplit: (recurring: Decimal, oneTime: Decimal)? {
        guard !filteredTransactions.isEmpty else { return nil }
        let recurringNames = Set(allRecurrings.map { $0.name.lowercased() })
        var rec: Decimal = 0; var oneTime: Decimal = 0
        for tx in filteredTransactions {
            let name = (tx.merchant ?? tx.category?.name ?? "").lowercased()
            if recurringNames.contains(name) { rec += tx.amount } else { oneTime += tx.amount }
        }
        return (rec, oneTime)
    }

    private var recurringVsOneTimeSection: some View {
        let split = recurringVsOneTimeSplit!
        let total = split.recurring + split.oneTime
        let recFrac = total > 0 ? CGFloat(Double((split.recurring / total) as NSDecimalNumber)) : 0

        return VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Recurring vs One-time").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if recFrac > 0 {
                        RoundedRectangle(cornerRadius: 4).fill(Color.bobHex(0xBA68C8))
                            .frame(width: geo.size.width * recFrac, height: 12)
                    }
                    if recFrac < 1 {
                        RoundedRectangle(cornerRadius: 4).fill(Color.bobAccent.opacity(0.6))
                            .frame(width: geo.size.width * (1 - recFrac), height: 12)
                    }
                }
            }
            .frame(height: 12)
            HStack(spacing: 20) {
                legendRow(color: Color.bobHex(0xBA68C8), label: "Recurring", amount: split.recurring)
                legendRow(color: Color.bobAccent.opacity(0.6), label: "One-time", amount: split.oneTime)
                Spacer()
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func legendRow(color: Color, label: String, amount: Decimal) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                Text(CurrencyFormatter.string(amount, code: currencyCode))
                    .font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
            }
        }
    }

    // MARK: – Top Merchants

    private var topMerchants: [(name: String, amount: Decimal, count: Int)] {
        var dict: [String: (Decimal, Int)] = [:]
        for tx in filteredTransactions {
            let key = tx.merchant?.isEmpty == false ? tx.merchant! : tx.category?.name ?? "Other"
            let current = dict[key] ?? (0, 0)
            dict[key] = (current.0 + tx.amount, current.1 + 1)
        }
        return dict.map { (name: $0.key, amount: $0.value.0, count: $0.value.1) }
            .sorted { $0.amount > $1.amount }
            .prefix(5).map { $0 }
    }

    private var topMerchantsSection: some View {
        let maxAmount = topMerchants.first?.amount ?? 1
        return VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Top Merchants").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)
            VStack(spacing: 12) {
                ForEach(Array(topMerchants.enumerated()), id: \.element.name) { idx, m in
                    VStack(spacing: 5) {
                        HStack {
                            Text(m.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bobInk).lineLimit(1)
                            Spacer()
                            Text(CurrencyFormatter.string(m.amount, code: currencyCode))
                                .font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
                            Text("·  \(m.count)x").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.bobHairline).frame(height: 5)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(chartPaletteColor(for: idx))
                                    .frame(width: geo.size.width * CGFloat(Double((m.amount / maxAmount) as NSDecimalNumber)), height: 5)
                            }
                        }.frame(height: 5)
                    }
                }
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Day of Week

    private var weekdayData: [(label: String, amount: Decimal)] {
        let symbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var totals = [Int: Decimal]()
        let cal = Calendar.current
        for tx in filteredTransactions {
            // weekday: 1=Sunday, 2=Monday … 7=Saturday → convert to 0=Mon…6=Sun
            let raw = cal.component(.weekday, from: tx.date)
            let idx = (raw + 5) % 7
            totals[idx, default: 0] += tx.amount
        }
        return (0..<7).map { (label: symbols[$0], amount: totals[$0] ?? 0) }
    }

    private var dayOfWeekSection: some View {
        let peak = weekdayData.map { $0.amount }.max() ?? 1
        let maxIdx = weekdayData.firstIndex(where: { $0.amount == peak }) ?? 0
        return VStack(alignment: .leading, spacing: Spacing.m) {
            Text("When do you spend most?")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(weekdayData.enumerated()), id: \.offset) { idx, day in
                    VStack(spacing: 4) {
                        let barH = peak > 0 ? CGFloat(Double((day.amount / peak) as NSDecimalNumber)) * 72 : 4
                        RoundedRectangle(cornerRadius: 4)
                            .fill(idx == maxIdx ? Color.bobDebit : Color.bobAccent.opacity(0.5))
                            .frame(height: Swift.max(barH, 4))
                        Text(day.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(idx == maxIdx ? Color.bobDebit : Color.bobInk3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 90)
            HStack {
                Text("Highest: \(weekdayData[maxIdx].label) · \(CurrencyFormatter.string(weekdayData[maxIdx].amount, code: currencyCode))")
                    .font(.system(size: 12)).foregroundStyle(Color.bobDebit)
                Spacer()
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Biggest Transactions

    private var biggestTransactions: [Expense] {
        filteredTransactions.sorted { $0.amount > $1.amount }.prefix(5).map { $0 }
    }

    private var biggestTransactionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Biggest Expenses")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)
            VStack(spacing: 0) {
                ForEach(Array(biggestTransactions.enumerated()), id: \.element.id) { idx, tx in
                    Button { editingTransaction = tx } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.bobDebit.opacity(0.1)).frame(width: 36, height: 36)
                                Image(systemName: tx.category?.sfSymbol ?? "circle.dashed")
                                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Color.bobDebit)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.merchant?.isEmpty == false ? tx.merchant! : tx.category?.name ?? "Expense")
                                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bobInk).lineLimit(1)
                                Text(shortDate(tx.date))
                                    .font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                            }
                            Spacer()
                            Text(CurrencyFormatter.string(tx.amount, code: currencyCode))
                                .font(.system(size: 15, weight: .bold)).monospacedDigit().foregroundStyle(Color.bobDebit)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < biggestTransactions.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: date)
    }

    // MARK: – Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: reportKind == .expense ? "chart.pie" : "arrow.down.circle")
                .font(.system(size: 52)).foregroundStyle(Color.bobInk2)
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

private enum AnalyticsCardKind {
    case spent
    case income
    case netCashFlow
    case assets
    case savingsRate

    var title: String {
        switch self {
        case .spent: return "Spent"
        case .income: return "Income"
        case .netCashFlow: return "Net cash flow"
        case .assets: return "Total assets"
        case .savingsRate: return "Savings rate"
        }
    }
}

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
                            .font(.system(size: 11)).foregroundStyle(Color.bobInk2)
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
                    Text(shortDate(data.first!.date)).font(.system(size: 10)).foregroundStyle(Color.bobInk2)
                    Spacer()
                    if data.count > 4 {
                        Text(shortDate(data[data.count / 2].date)).font(.system(size: 10)).foregroundStyle(Color.bobInk2)
                    }
                    Spacer()
                    Text(shortDate(data.last!.date)).font(.system(size: 10)).foregroundStyle(Color.bobInk2)
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
                        Text("\(pct)% of total").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
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
                                .foregroundStyle(Color.bobInk2)
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
                        Text(monthLabel(for: data[idx].month)).font(.system(size: 10)).foregroundStyle(Color.bobInk2)
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
            Text(label).font(.system(size: 12)).foregroundStyle(Color.bobInk2)
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
