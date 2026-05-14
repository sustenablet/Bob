import SwiftUI
import SwiftData

struct SpendingView: View {
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]
    @Query(sort: \RecurringTransaction.nextDueDate) private var recurrings: [RecurringTransaction]

    @State private var selectedPeriod: SpendPeriod = .week
    @State private var selectedIndex: Int = 0
    @State private var includeBills: Bool = true
    @State private var breakdownTab: BreakdownTab = .categories

    enum SpendPeriod: String, CaseIterable { case week = "Week"; case month = "Month"; case quarter = "Quarter"; case year = "Year" }
    enum BreakdownTab: String, CaseIterable { case categories = "Categories"; case tags = "Tags" }

    private let cal = Calendar.current
    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }

    // MARK: – Period segments

    private var segments: [PeriodSegment] {
        let chartPeriod: ChartPeriod
        let count: Int
        switch selectedPeriod {
        case .week:
            chartPeriod = .week
            count = 6
        case .month:
            chartPeriod = .month
            count = 6
        case .quarter:
            chartPeriod = .quarter
            count = 4
        case .year:
            chartPeriod = .year
            count = 3
        }
        return ChartDataService.segments(for: chartPeriod, count: count).map {
            PeriodSegment(label: $0.label, start: $0.start, end: $0.end)
        }
    }

    private var currentSegment: PeriodSegment? {
        guard selectedIndex < segments.count else { return nil }
        return segments[selectedIndex]
    }

    // MARK: – Filtered data for selected period

    private func expenses(in seg: PeriodSegment) -> [Expense] {
        allExpenses.filter { $0.kind == .expense && $0.date >= seg.start && $0.date <= seg.end }
    }
    private func income(in seg: PeriodSegment) -> [Expense] {
        allExpenses.filter { $0.kind == .income && $0.date >= seg.start && $0.date <= seg.end }
    }

    private var currentExpenses: Decimal {
        guard let seg = currentSegment else { return 0 }
        return expenses(in: seg).reduce(0) { $0 + $1.amount }
    }
    private var currentIncome: Decimal {
        guard let seg = currentSegment else { return 0 }
        return income(in: seg).reduce(0) { $0 + $1.amount }
    }

    private var netCashFlow: Decimal { currentIncome - currentExpenses }

    private var avgDailySpend: Decimal {
        guard let seg = currentSegment else { return 0 }
        let cal = Calendar.current
        let days = max(cal.dateComponents([.day], from: seg.start, to: seg.end).day ?? 1, 1)
        guard currentExpenses > 0 else { return 0 }
        return currentExpenses / Decimal(days)
    }

    private var periodTransactions: [Expense] {
        guard let seg = currentSegment else { return [] }
        return allExpenses.filter { $0.date >= seg.start && $0.date <= seg.end }
            .sorted { $0.date > $1.date }
    }

    private var biggestSingleExpense: Expense? {
        guard let seg = currentSegment else { return nil }
        return expenses(in: seg).sorted { $0.amount > $1.amount }.first
    }

    private var dailyBreakdown: [(label: String, amount: Decimal)] {
        guard let seg = currentSegment else { return [] }
        return ChartDataService.dailyExpenseBreakdown(
            transactions: allExpenses,
            from: seg.start,
            to: seg.end,
            calendar: Calendar.current
        )
    }

    private var maxBarValue: Decimal {
        segments.map { seg in
            max(expenses(in: seg).reduce(0) { $0 + $1.amount },
                income(in: seg).reduce(0) { $0 + $1.amount })
        }.max() ?? 1
    }

    // Category breakdown
    private var categoryBreakdown: [(name: String, symbol: String, amount: Decimal)] {
        guard let seg = currentSegment else { return [] }
        var dict: [String: (symbol: String, amount: Decimal)] = [:]
        for tx in expenses(in: seg) {
            let cat = tx.category?.name ?? "Other"
            let sym = tx.iconSymbol ?? tx.category?.sfSymbol ?? "circle.dashed"
            let ex = dict[cat]
            dict[cat] = (ex?.symbol ?? sym, (ex?.amount ?? 0) + tx.amount)
        }
        return dict.map { (name: $0.key, symbol: $0.value.symbol, amount: $0.value.amount) }
            .sorted { $0.amount > $1.amount }
    }


    // MARK: – Body

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar

                    periodPicker
                        .padding(.horizontal, Spacing.pageMargin)
                        .padding(.top, Spacing.m)

                    periodCards
                        .padding(.top, Spacing.m)

                    legend
                        .padding(.top, Spacing.xs)
                        .padding(.horizontal, Spacing.pageMargin)

                    netCashFlowCard
                        .padding(.top, Spacing.m)

                    dailySpendChart
                        .padding(.top, Spacing.m)

                    breakdownSection
                        .padding(.top, Spacing.l)

                    periodTransactionList
                        .padding(.top, Spacing.l)

                    Spacer().frame(height: 100)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { selectedIndex = max(segments.count - 1, 0) }
        .onChange(of: selectedPeriod) { _, _ in selectedIndex = max(segments.count - 1, 0) }
    }

    // MARK: – Top bar

    private var topBar: some View {
        HStack {
            Color.clear.frame(width: 36, height: 36)
            Spacer()
            Text("Spending").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.bobInk)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Spacing.pageMargin).padding(.vertical, 14)
    }

    // MARK: – Period picker

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(SpendPeriod.allCases, id: \.self) { period in
                Button { withAnimation(.easeOut(duration: 0.2)) { selectedPeriod = period } } label: {
                    Text(period.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selectedPeriod == period ? Color.black : Color.bobInk2)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(selectedPeriod == period ? Color.white : Color.bobSurface2)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: – Scrollable period cards

    private var periodCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.offset) { idx, seg in
                    periodCard(seg: seg, idx: idx)
                }
            }
            .padding(.horizontal, Spacing.pageMargin)
        }
    }

    private func periodCard(seg: PeriodSegment, idx: Int) -> some View {
        let isSelected = idx == selectedIndex
        let spend  = expenses(in: seg).reduce(Decimal(0)) { $0 + $1.amount }
        let inc    = income(in: seg).reduce(Decimal(0)) { $0 + $1.amount }
        let maxV   = maxBarValue

        return Button { withAnimation(.easeOut(duration: 0.15)) { selectedIndex = idx } } label: {
            VStack(spacing: 6) {
                // Mini bar chart
                HStack(alignment: .bottom, spacing: 4) {
                    // Income bar — solid blue
                    if maxV > 0 {
                        let h = max(CGFloat(Double((inc / maxV) as NSDecimalNumber)) * 48, 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.bobChartBlue)
                            .frame(width: 10, height: h)
                    }
                    // Spend bar — dotted/light gray
                    if maxV > 0 {
                        let h = max(CGFloat(Double((spend / maxV) as NSDecimalNumber)) * 48, 2)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.bobInk2.opacity(0.4))
                            .frame(width: 10, height: h)
                            .overlay(
                                LinearGradient(
                                    colors: stride(from: 0, through: 48, by: 3).map { i in
                                        i % 6 < 3 ? Color.white.opacity(0.25) : Color.clear
                                    },
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }
                }
                .frame(width: 28, height: 52, alignment: .bottom)

                Text(seg.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? Color.bobInk : Color.bobInk2)
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            .frame(width: 72)
            .background(Color.bobSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white : Color.bobHairline, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: – Legend

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle().fill(Color.bobChartBlue).frame(width: 8, height: 8)
                Text("Income").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
            }
            HStack(spacing: 6) {
                Circle().fill(Color.bobInk2.opacity(0.4)).frame(width: 8, height: 8)
                Text("Total Spend").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
            }
            Spacer()
        }
    }

    // MARK: – Net cash flow card
    private var netCashFlowCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Income").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.bobInk2).textCase(.uppercase).tracking(0.6)
                    Text(CurrencyFormatter.string(currentIncome, code: currencyCode))
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(Color.bobGreen).monospacedDigit()
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Expenses").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.bobInk2).textCase(.uppercase).tracking(0.6)
                    Text(CurrencyFormatter.string(currentExpenses, code: currencyCode))
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(Color.bobDebit).monospacedDigit()
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, Spacing.m)

                Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Net").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.bobInk2).textCase(.uppercase).tracking(0.6)
                    Text((netCashFlow >= 0 ? "+" : "") + CurrencyFormatter.string(netCashFlow, code: currencyCode))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(netCashFlow >= 0 ? Color.bobGreen : Color.bobDebit)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, Spacing.m)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 16)

            if avgDailySpend > 0 {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.day.timeline.left").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                        Text("Daily avg: \(CurrencyFormatter.string(avgDailySpend, code: currencyCode))")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bobInk2)
                    }
                    if let biggest = biggestSingleExpense {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 12)).foregroundStyle(Color.bobDebit)
                            Text("Biggest: \(CurrencyFormatter.string(biggest.amount, code: currencyCode))")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bobInk2)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, 10)
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
        .padding(.horizontal, Spacing.pageMargin)
    }

    // MARK: – Daily spend bar chart
    private var dailySpendChart: some View {
        let data = dailyBreakdown
        guard !data.isEmpty else { return AnyView(EmptyView()) }
        let peak = data.map { ($0.amount as NSDecimalNumber).doubleValue }.max() ?? 1

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("DAILY BREAKDOWN")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.bobInk2)
                        .tracking(0.8)
                    Spacer()
                    Text("\(data.count) days active")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.bobInk3)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(Array(data.enumerated()), id: \.offset) { idx, item in
                            VStack(spacing: 4) {
                                let h = max(CGFloat((item.amount as NSDecimalNumber).doubleValue / peak) * 60, 4)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.bobDebit.opacity(0.5), Color.bobDebit.opacity(0.85)],
                                            startPoint: .bottom, endPoint: .top
                                        )
                                    )
                                    .frame(width: 14, height: h)
                                Text(item.label)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.bobInk3)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.pageMargin)
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, -Spacing.pageMargin)
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
        )
    }

    // MARK: – Period transaction list
    private var periodTransactionList: some View {
        let txns = periodTransactions.prefix(8)
        guard !txns.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("TRANSACTIONS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
                    .tracking(0.8)
                    .padding(.horizontal, Spacing.pageMargin)

                VStack(spacing: 0) {
                    ForEach(Array(txns.enumerated()), id: \.element.id) { idx, tx in
                        spendTxRow(tx)
                        if idx < txns.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.leading, 58)
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
        )
    }

    private func spendTxRow(_ tx: Expense) -> some View {
        let isIncome = tx.kind == .income
        let amtStr = CurrencyFormatter.string(tx.amount, code: currencyCode)
        let df = DateFormatter(); df.dateFormat = "MMM d"

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isIncome ? Color.bobGreen.opacity(0.18) : Color.bobDebit.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: tx.iconSymbol ?? tx.category?.sfSymbol ?? "circle.dashed")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isIncome ? Color.bobGreen : Color.bobDebit)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(tx.merchant?.isEmpty == false ? tx.merchant! : (tx.category?.name ?? (isIncome ? "Income" : "Expense")))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                    .lineLimit(1)
                Text(df.string(from: tx.date))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bobInk2)
            }

            Spacer()

            Text((isIncome ? "+" : "") + amtStr)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isIncome ? Color.bobGreen : Color.bobInk)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, 12)
    }

    // MARK: – Summary card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow(
                icon: "bag.circle",
                label: "Income",
                value: CurrencyFormatter.string(currentIncome, code: currencyCode),
                chevron: "chevron.right"
            )
            Divider().background(Color.bobHairline)
            summaryRow(
                icon: "banknote",
                label: "Total Spend",
                value: CurrencyFormatter.string(currentExpenses, code: currencyCode),
                chevron: "chevron.down"
            )
        }
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func summaryRow(icon: String, label: String, value: String, chevron: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Color.bobInk2)
                .frame(width: 32)
            Text(label)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.bobInk)
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.bobInk)
            Image(systemName: chevron)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, 16)
    }

    // MARK: – Breakdown section

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("BREAKDOWN")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .tracking(0.8)
                .padding(.horizontal, Spacing.pageMargin)

            VStack(spacing: 0) {
                // Categories | Tags tab
                HStack(spacing: 0) {
                    ForEach(BreakdownTab.allCases, id: \.self) { tab in
                        Button { withAnimation { breakdownTab = tab } } label: {
                            VStack(spacing: 8) {
                                Text(tab.rawValue)
                                    .font(.system(size: 15, weight: breakdownTab == tab ? .semibold : .regular))
                                    .foregroundStyle(breakdownTab == tab ? Color.bobInk : Color.bobInk2)
                                Rectangle()
                                    .fill(breakdownTab == tab ? Color.bobInk : Color.clear)
                                    .frame(height: 2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, Spacing.s)

                Divider().background(Color.bobHairline)

                // Include bills toggle
                HStack {
                    Spacer()
                    Text("Include bills")
                        .font(.system(size: 14)).foregroundStyle(Color.bobInk2)
                    Toggle("", isOn: $includeBills)
                        .labelsHidden().tint(Color.bobAccent)
                }
                .padding(.horizontal, Spacing.m).padding(.top, Spacing.s)

                // Ring chart
                ringChart
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.xl)

                // Category list
                if !categoryBreakdown.isEmpty {
                    Divider().background(Color.bobHairline).padding(.top, Spacing.s)

                    let visible = Array(categoryBreakdown.prefix(3))
                    VStack(spacing: 0) {
                        ForEach(Array(visible.enumerated()), id: \.element.name) { idx, cat in
                            categoryRow(cat: cat, idx: idx)
                            if idx < visible.count - 1 {
                                Divider().background(Color.bobHairline).padding(.leading, 58)
                            }
                        }
                    }

                    // See More button
                    Button { } label: {
                        Text("See More")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.bobInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.clear)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.bobInk2.opacity(0.5), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Spacing.m)
                    .padding(.bottom, Spacing.m)
                    .padding(.top, Spacing.s)
                }
            }
            .background(Color.bobSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, Spacing.pageMargin)
        }
    }

    // MARK: – Segment palette (blue-first to match reference)

    private let segmentPalette: [Color] = [
        Color.bobHex(0x4F7FFF), // blue — dominant
        Color.bobHex(0x8DB53E), // olive green
        Color.bobHex(0xBA68C8), // purple
        Color.bobHex(0xFF8A65), // orange
        Color.bobHex(0xFFB74D), // amber
        Color.bobHex(0x4DD0E1)  // teal
    ]

    private func segmentColor(_ idx: Int) -> Color { segmentPalette[idx % segmentPalette.count] }

    private func segStart(idx: Int, total: Decimal) -> Double {
        guard total > 0 else { return 0 }
        let pre = categoryBreakdown.prefix(idx).reduce(Decimal(0)) { $0 + $1.amount }
        return Double((pre / total) as NSDecimalNumber)
    }
    private func segEnd(idx: Int, total: Decimal) -> Double {
        guard total > 0 else { return 0 }
        let inc = categoryBreakdown.prefix(idx + 1).reduce(Decimal(0)) { $0 + $1.amount }
        return Double((inc / total) as NSDecimalNumber)
    }

    // MARK: – Ring chart (multi-segment donut)

    private var ringChart: some View {
        let total = categoryBreakdown.reduce(Decimal(0)) { $0 + $1.amount }
        let catCount = categoryBreakdown.count

        let periodLabel: String = {
            guard let seg = currentSegment else { return "" }
            switch selectedPeriod {
            case .week:
                let f = DateFormatter(); f.dateFormat = "MMM d"
                return "week of \(f.string(from: seg.start))"
            case .month:
                let f = DateFormatter(); f.dateFormat = "MMMM"
                return f.string(from: seg.start)
            case .quarter, .year: return seg.label
            }
        }()

        return GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: size / 2)
            let strokeW: CGFloat = 26
            let radius: CGFloat = (size - strokeW) / 2 - 4

            ZStack {
                // Background track
                Circle()
                    .stroke(Color.bobSurface2, lineWidth: strokeW)
                    .frame(width: size - 8, height: size - 8)
                    .position(center)

                // Segments
                ForEach(0..<catCount, id: \.self) { idx in
                    let start = segStart(idx: idx, total: total)
                    let end   = segEnd(idx: idx, total: total)
                    Circle()
                        .trim(from: start, to: max(start, end - 0.005))
                        .stroke(segmentColor(idx),
                                style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: size - 8, height: size - 8)
                        .position(center)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: catCount)
                }

                // Category icons on ring segments
                ForEach(0..<catCount, id: \.self) { idx in
                    let start = segStart(idx: idx, total: total)
                    let end   = segEnd(idx: idx, total: total)
                    let pct = end - start
                    if pct >= 0.06 { // only show icon if segment is big enough
                        let midAngle = ((start + end) / 2) * 2 * .pi - .pi / 2
                        let x = center.x + cos(midAngle) * radius
                        let y = center.y + sin(midAngle) * radius
                        ZStack {
                            Circle().fill(segmentColor(idx)).frame(width: 24, height: 24)
                            Image(systemName: categoryBreakdown[idx].symbol)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .position(x: x, y: y)
                    }
                }

                // Center text
                VStack(spacing: 4) {
                    Text("Total spend").font(.system(size: 14)).foregroundStyle(Color.bobInk2)
                    if !periodLabel.isEmpty {
                        Text(periodLabel).font(.system(size: 13)).foregroundStyle(Color.bobInk2)
                    }
                    Text(CurrencyFormatter.string(currentExpenses, code: currencyCode))
                        .font(.system(size: 30, weight: .bold)).foregroundStyle(Color.bobInk)
                        .contentTransition(.numericText())
                }
                .position(center)

                // ⓘ button at bottom of ring
                Button { } label: {
                    ZStack {
                        Circle().fill(Color.bobSurface2).frame(width: 28, height: 28)
                        Circle().stroke(Color.bobInk2.opacity(0.5), lineWidth: 1).frame(width: 28, height: 28)
                        Text("?").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bobInk2)
                    }
                }
                .buttonStyle(.plain)
                .position(x: center.x, y: center.y + radius + 18)
            }
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
    }

    // MARK: – Category row

    private func categoryRow(cat: (name: String, symbol: String, amount: Decimal), idx: Int) -> some View {
        let color = segmentColor(idx)
        let total = categoryBreakdown.reduce(Decimal(0)) { $0 + $1.amount }
        let pct = total > 0 ? Int(Double((cat.amount / total * 100) as NSDecimalNumber)) : 0

        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: cat.symbol).font(.system(size: 16, weight: .medium)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(cat.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)
                Text("\(pct)% of spend").font(.system(size: 13)).foregroundStyle(Color.bobInk2)
            }
            Spacer()
            Text(CurrencyFormatter.string(cat.amount, code: currencyCode))
                .font(.system(size: 16, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
        }
        .padding(.horizontal, Spacing.m).padding(.vertical, 14)
    }
}

// MARK: – Supporting types

struct PeriodSegment {
    let label: String
    let start: Date
    let end: Date
}

#Preview {
    SpendingView()
        .modelContainer(for: [Expense.self, BudgetSettings.self, RecurringTransaction.self], inMemory: true)
}
