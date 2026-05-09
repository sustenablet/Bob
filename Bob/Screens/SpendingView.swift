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
        switch selectedPeriod {
        case .week:    return lastNWeeks(6)
        case .month:   return lastNMonths(6)
        case .quarter: return lastNQuarters(4)
        case .year:    return lastNYears(3)
        }
    }

    private func lastNWeeks(_ n: Int) -> [PeriodSegment] {
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let startOfThisWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: today)!
        return (0..<n).reversed().map { offset in
            let start = cal.date(byAdding: .weekOfYear, value: -offset, to: startOfThisWeek)!
            let end   = cal.date(byAdding: .day, value: 6, to: start)!
            let f = DateFormatter(); f.dateFormat = "M/d"
            return PeriodSegment(label: f.string(from: start), start: start, end: end)
        }
    }

    private func lastNMonths(_ n: Int) -> [PeriodSegment] {
        let now = Date()
        return (0..<n).reversed().map { offset in
            let d = cal.date(byAdding: .month, value: -offset, to: now)!
            let comps = cal.dateComponents([.year, .month], from: d)
            let start = cal.date(from: comps)!
            let end   = cal.date(byAdding: .month, value: 1, to: start)!
            let f = DateFormatter(); f.dateFormat = "MMM"
            return PeriodSegment(label: f.string(from: start), start: start, end: end)
        }
    }

    private func lastNQuarters(_ n: Int) -> [PeriodSegment] {
        let now = Date()
        let month = cal.component(.month, from: now)
        let quarterStart = ((month - 1) / 3) * 3 + 1
        var result: [PeriodSegment] = []
        for i in (0..<n).reversed() {
            let offset = -i * 3
            let s = cal.date(byAdding: .month, value: offset - (month - quarterStart), to: cal.date(from: cal.dateComponents([.year, .month], from: now))!)!
            let e = cal.date(byAdding: .month, value: 3, to: s)!
            let f = DateFormatter(); f.dateFormat = "MMM"
            result.append(PeriodSegment(label: "Q \(f.string(from: s))", start: s, end: e))
        }
        return result
    }

    private func lastNYears(_ n: Int) -> [PeriodSegment] {
        let now = Date()
        return (0..<n).reversed().map { offset in
            let d = cal.date(byAdding: .year, value: -offset, to: now)!
            let start = cal.date(from: cal.dateComponents([.year], from: d))!
            let end   = cal.date(byAdding: .year, value: 1, to: start)!
            let f = DateFormatter(); f.dateFormat = "yyyy"
            return PeriodSegment(label: f.string(from: start), start: start, end: end)
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
            let sym = tx.category?.sfSymbol ?? "circle.dashed"
            let ex = dict[cat]
            dict[cat] = (ex?.symbol ?? sym, (ex?.amount ?? 0) + tx.amount)
        }
        return dict.map { (name: $0.key, symbol: $0.value.symbol, amount: $0.value.amount) }
            .sorted { $0.amount > $1.amount }
    }

    private var ringProgress: Double {
        guard maxBarValue > 0 else { return 0 }
        let ratio = Double((currentExpenses / maxBarValue) as NSDecimalNumber)
        return min(ratio, 1.0)
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

                    summaryCard
                        .padding(.horizontal, Spacing.pageMargin)
                        .padding(.top, Spacing.m)

                    breakdownSection
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
            Button { } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20)).foregroundStyle(Color.bobInk2).frame(width: 36, height: 36)
            }.buttonStyle(.plain)
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
                    Divider().background(Color.bobHairline).padding(.horizontal, Spacing.m)
                    VStack(spacing: 0) {
                        ForEach(Array(categoryBreakdown.enumerated()), id: \.element.name) { idx, cat in
                            categoryRow(cat: cat, idx: idx)
                            if idx < categoryBreakdown.count - 1 {
                                Divider().background(Color.bobHairline).padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.top, Spacing.xs)
                }
            }
            .background(Color.bobSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, Spacing.pageMargin)
        }
    }

    // MARK: – Ring chart

    private var ringChart: some View {
        let periodLabel = currentSegment.map { seg in
            switch selectedPeriod {
            case .week:
                let f = DateFormatter(); f.dateFormat = "MMM d"
                return "week of \(f.string(from: seg.start))"
            case .month:
                let f = DateFormatter(); f.dateFormat = "MMMM"
                return f.string(from: seg.start)
            case .quarter:
                return seg.label
            case .year:
                return seg.label
            }
        } ?? ""

        return ZStack {
            // Background ring
            Circle()
                .stroke(Color.bobSurface2, lineWidth: 20)

            // Progress ring — olive/green
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    Color.bobHex(0x8DB53E),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: ringProgress)

            // Center text
            VStack(spacing: 6) {
                Text("Total spend")
                    .font(.system(size: 14)).foregroundStyle(Color.bobInk2)
                if !periodLabel.isEmpty {
                    Text(periodLabel)
                        .font(.system(size: 13)).foregroundStyle(Color.bobInk2)
                }
                Text(CurrencyFormatter.string(currentExpenses, code: currencyCode))
                    .font(.system(size: 32, weight: .bold)).foregroundStyle(Color.bobInk)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: 240, height: 240)
        .frame(maxWidth: .infinity)
    }

    // MARK: – Category row

    private func categoryRow(cat: (name: String, symbol: String, amount: Decimal), idx: Int) -> some View {
        let palette: [Color] = [
            Color.bobHex(0x4ADE80), Color.bobHex(0x4F7FFF), Color.bobHex(0xFFB74D),
            Color.bobHex(0xFF5252), Color.bobHex(0xBA68C8), Color.bobHex(0xFF8A65)
        ]
        let color = palette[idx % palette.count]
        let total = categoryBreakdown.reduce(Decimal(0)) { $0 + $1.amount }
        let pct = total > 0 ? Int(Double((cat.amount / total * 100) as NSDecimalNumber)) : 0

        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 36, height: 36)
                Image(systemName: cat.symbol).font(.system(size: 14, weight: .medium)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(cat.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.bobInk)
                Text("\(pct)% of total").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
            }
            Spacer()
            Text(CurrencyFormatter.string(cat.amount, code: currencyCode))
                .font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
        }
        .padding(.horizontal, Spacing.m).padding(.vertical, 13)
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
