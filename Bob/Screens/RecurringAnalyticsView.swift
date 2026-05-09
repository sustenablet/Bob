import SwiftUI
import SwiftData

struct RecurringAnalyticsView: View {
    let recurrings: [RecurringTransaction]
    let currencyCode: String

    @State private var detailSection: RecurAnalyticsSection? = nil

    private let cal = Calendar.current

    // MARK: – Monthly equivalent helper

    private func monthly(_ r: RecurringTransaction) -> Decimal {
        switch r.frequency {
        case .weekly:   return r.amount * 4
        case .biweekly: return r.amount * 2
        case .monthly:  return r.amount
        case .yearly:   return r.amount / 12
        }
    }

    private var activeExpenses: [RecurringTransaction] { recurrings.filter { $0.isActive && $0.kind == .expense } }
    private var activeIncome:   [RecurringTransaction] { recurrings.filter { $0.isActive && $0.kind == .income  } }

    // MARK: – Section 1: Monthly trend data (6 months)

    private var trendData: [(month: String, amount: Decimal)] {
        let currentMonthly = activeExpenses.reduce(Decimal(0)) { $0 + monthly($1) }
        let f = DateFormatter(); f.dateFormat = "MMM"
        return (0..<6).reversed().map { offset in
            let d = cal.date(byAdding: .month, value: -offset, to: Date())!
            return (month: f.string(from: d), amount: currentMonthly)
        }
    }

    // MARK: – Section 2: Income vs Bills

    private var monthlyIn:  Decimal { activeIncome.reduce(0)   { $0 + monthly($1) } }
    private var monthlyOut: Decimal { activeExpenses.reduce(0) { $0 + monthly($1) } }

    // MARK: – Section 3: Frequency breakdown

    private var frequencyData: [(label: String, count: Int, amount: Decimal)] {
        let groups: [(RecurringFrequency, String)] = [(.weekly, "Weekly"), (.biweekly, "Biweekly"), (.monthly, "Monthly"), (.yearly, "Yearly")]
        return groups.map { freq, label in
            let items = activeExpenses.filter { $0.frequency == freq }
            return (label: label, count: items.count, amount: items.reduce(0) { $0 + monthly($1) })
        }
    }

    // MARK: – Section 4: Category breakdown

    private var categoryData: [(name: String, symbol: String, amount: Decimal)] {
        var dict: [String: (symbol: String, amount: Decimal)] = [:]
        for r in activeExpenses {
            let key = r.category?.name ?? "Uncategorized"
            let sym = r.category?.sfSymbol ?? "circle.dashed"
            let ex = dict[key]
            dict[key] = (ex?.symbol ?? sym, (ex?.amount ?? 0) + monthly(r))
        }
        return dict.map { (name: $0.key, symbol: $0.value.symbol, amount: $0.value.amount) }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: – Section 5: Due date heatmap

    private var dueDateMap: [Int: Int] {
        var dict: [Int: Int] = [:]
        for r in recurrings where r.isActive {
            let day = cal.component(.day, from: r.nextDueDate)
            dict[day, default: 0] += 1
        }
        return dict
    }

    private var dueDateAmountMap: [Int: Decimal] {
        var dict: [Int: Decimal] = [:]
        for r in recurrings where r.isActive {
            let day = cal.component(.day, from: r.nextDueDate)
            dict[day, default: 0] += r.amount
        }
        return dict
    }

    // MARK: – Section 6: Top expenses

    private var topExpenses: [RecurringTransaction] { activeExpenses.sorted { monthly($0) > monthly($1) } }

    // MARK: – Body

    var body: some View {
        VStack(spacing: Spacing.m) {
            section1_trend
            section2_ratio
            section3_frequency
            section4_category
            section5_heatmap
            section6_top
            Spacer().frame(height: 100)
        }
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.top, Spacing.m)
        .sheet(item: $detailSection) { sec in
            RecurringChartDetailView(section: sec)
        }
    }

    // MARK: – Section card builder

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        onView: @escaping () -> Void,
        @ViewBuilder preview: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.bobInk)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bobInk2)
                }
                Spacer()
                Button(action: onView) {
                    HStack(spacing: 4) {
                        Text("View")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.bobChartBlue)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.bobChartBlue.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            preview()
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: – Section 1: Monthly Cost Trend

    private var section1_trend: some View {
        sectionCard(
            title: "Monthly Cost Trend",
            subtitle: "Is your recurring spend growing or stable?",
            onView: { detailSection = .trend(data: trendData, currencyCode: currencyCode) }
        ) {
            let maxAmt = trendData.map { ($0.amount as NSDecimalNumber).doubleValue }.max() ?? 1
            let isEmpty = trendData.allSatisfy { $0.amount == 0 }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(trendData.enumerated()), id: \.offset) { idx, pt in
                    let h = isEmpty ? CGFloat([40, 55, 45, 60, 50, 65][idx]) : CGFloat(Double((pt.amount as NSDecimalNumber).doubleValue) / maxAmt) * 80
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isEmpty ? Color.bobSurface2 : Color.bobChartBlue)
                            .frame(height: max(h, 6))
                        Text(pt.month)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.bobInk2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 95)
        }
    }

    // MARK: – Section 2: Income vs Bills Ratio

    private var section2_ratio: some View {
        sectionCard(
            title: "Income vs Bills Ratio",
            subtitle: "What % of recurring income goes to bills?",
            onView: { detailSection = .ratio(monthlyIn: monthlyIn, monthlyOut: monthlyOut, currencyCode: currencyCode) }
        ) {
            let isEmpty = monthlyIn == 0 && monthlyOut == 0
            let ratio: Double = isEmpty ? 0.5 : (monthlyIn > 0 ? min(Double((monthlyOut / monthlyIn) as NSDecimalNumber), 1.0) : 1.0)

            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(isEmpty ? Color.bobSurface2 : Color.bobAccent, lineWidth: 12).frame(width: 80, height: 80)
                    if !isEmpty {
                        Circle().trim(from: 0, to: ratio)
                            .stroke(Color.bobDebit, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90)).frame(width: 80, height: 80)
                    }
                    Text(isEmpty ? "—" : "\(Int(ratio * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isEmpty ? Color.bobInk2 : (ratio > 0.8 ? Color.bobDebit : Color.bobAccent))
                }

                VStack(alignment: .leading, spacing: 8) {
                    statMini("Monthly in", value: isEmpty ? "—" : CurrencyFormatter.compact(monthlyIn, code: currencyCode), color: .bobAccent)
                    statMini("Monthly out", value: isEmpty ? "—" : CurrencyFormatter.compact(monthlyOut, code: currencyCode), color: .bobDebit)
                    let net = monthlyIn - monthlyOut
                    statMini("Net", value: isEmpty ? "—" : (net >= 0 ? "+" : "") + CurrencyFormatter.compact(net, code: currencyCode), color: net >= 0 ? .bobAccent : .bobDebit)
                }
                Spacer()
            }
        }
    }

    private func statMini(_ label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.bobInk2)
            Spacer()
            Text(value).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
        }
    }

    // MARK: – Section 3: Billing Frequency

    private var section3_frequency: some View {
        sectionCard(
            title: "Billing Frequency",
            subtitle: "Which billing cadence costs you most?",
            onView: { detailSection = .frequency(data: frequencyData, currencyCode: currencyCode) }
        ) {
            let freqColors: [Color] = [Color.bobChartBlue, Color.bobAccent, Color.bobHex(0xBA68C8), Color.bobHex(0xFF8A65)]
            let maxAmt = frequencyData.map { ($0.amount as NSDecimalNumber).doubleValue }.max() ?? 1
            let isEmpty = frequencyData.allSatisfy { $0.amount == 0 }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(frequencyData.enumerated()), id: \.offset) { idx, item in
                    let h = isEmpty ? CGFloat([50, 80, 70, 40][idx]) : CGFloat(Double((item.amount as NSDecimalNumber).doubleValue) / maxAmt) * 80
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isEmpty ? Color.bobSurface2 : freqColors[idx])
                            .frame(height: max(h, 6))
                        Text(item.label.prefix(1) + "").font(.system(size: 10)).foregroundStyle(Color.bobInk2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 95)
        }
    }

    // MARK: – Section 4: Category Breakdown

    private var section4_category: some View {
        sectionCard(
            title: "Category Breakdown",
            subtitle: "Which areas cost most on a recurring basis?",
            onView: { detailSection = .category(data: categoryData, currencyCode: currencyCode) }
        ) {
            let palette: [Color] = [Color.bobHex(0x4F7FFF), Color.bobHex(0x8DB53E), Color.bobHex(0xBA68C8)]
            let isEmpty = categoryData.isEmpty
            let maxAmt = categoryData.first?.amount ?? 1
            let display = isEmpty ? [("Uncategorized", "circle.dashed", Decimal(0)), ("Housing", "house.fill", Decimal(0)), ("Food", "fork.knife", Decimal(0))] : Array(categoryData.prefix(3))

            VStack(spacing: 8) {
                ForEach(Array(display.enumerated()), id: \.element.name) { idx, cat in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(isEmpty ? Color.bobSurface2 : palette[idx % palette.count].opacity(0.2)).frame(width: 28, height: 28)
                            Image(systemName: cat.symbol).font(.system(size: 11, weight: .medium))
                                .foregroundStyle(isEmpty ? Color.bobInk2 : palette[idx % palette.count])
                        }
                        Text(cat.name).font(.system(size: 13)).foregroundStyle(isEmpty ? Color.bobInk2 : Color.bobInk).lineLimit(1)
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.bobSurface2).frame(height: 6)
                                if !isEmpty && maxAmt > 0 {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(palette[idx % palette.count])
                                        .frame(width: geo.size.width * CGFloat(Double((cat.amount / maxAmt) as NSDecimalNumber)), height: 6)
                                }
                            }
                        }.frame(width: 80, height: 6)
                        Text(isEmpty ? "—" : CurrencyFormatter.compact(cat.amount, code: currencyCode))
                            .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(isEmpty ? Color.bobInk2 : Color.bobInk)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: – Section 5: Due Date Heatmap

    private var section5_heatmap: some View {
        sectionCard(
            title: "Due Date Heatmap",
            subtitle: "Which days have the most billing pressure?",
            onView: { detailSection = .heatmap(dayMap: dueDateMap, amountMap: dueDateAmountMap, recurrings: recurrings, currencyCode: currencyCode) }
        ) {
            let isEmpty = dueDateMap.isEmpty
            let maxCount = dueDateMap.values.max() ?? 1

            VStack(spacing: 6) {
                HStack(spacing: 3) {
                    ForEach(1...31, id: \.self) { day in
                        let count = dueDateMap[day] ?? 0
                        let intensity = maxCount > 0 ? Double(count) / Double(maxCount) : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isEmpty ? Color.bobSurface2 : (count == 0 ? Color.bobSurface2 : Color.bobChartBlue.opacity(0.2 + intensity * 0.8)))
                            .frame(height: 28)
                    }
                }
                HStack {
                    Text("1").font(.system(size: 9)).foregroundStyle(Color.bobInk2)
                    Spacer()
                    Text("15").font(.system(size: 9)).foregroundStyle(Color.bobInk2)
                    Spacer()
                    Text("31").font(.system(size: 9)).foregroundStyle(Color.bobInk2)
                }
            }
        }
    }

    // MARK: – Section 6: Top Recurring Expenses

    private var section6_top: some View {
        sectionCard(
            title: "Top Recurring Expenses",
            subtitle: "Your biggest recurring costs at a glance",
            onView: { detailSection = .topExpenses(items: topExpenses, currencyCode: currencyCode) }
        ) {
            let isEmpty = topExpenses.isEmpty
            let display = isEmpty ? [] : Array(topExpenses.prefix(3))
            let palette: [Color] = [Color.bobChartBlue, Color.bobAccent, Color.bobHex(0xBA68C8)]
            let maxAmt = display.first.map { monthly($0) } ?? 1

            if isEmpty {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        HStack(spacing: 10) {
                            Circle().fill(Color.bobSurface2).frame(width: 28, height: 28)
                            RoundedRectangle(cornerRadius: 4).fill(Color.bobSurface2).frame(height: 12)
                            Spacer()
                            RoundedRectangle(cornerRadius: 4).fill(Color.bobSurface2).frame(width: 50, height: 12)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(display.enumerated()), id: \.element.id) { idx, item in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(palette[idx % palette.count].opacity(0.18)).frame(width: 28, height: 28)
                                Text("\(idx + 1)").font(.system(size: 11, weight: .bold)).foregroundStyle(palette[idx % palette.count])
                            }
                            Text(item.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bobInk).lineLimit(1)
                            Spacer()
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.bobSurface2).frame(height: 5)
                                    RoundedRectangle(cornerRadius: 3).fill(palette[idx % palette.count])
                                        .frame(width: maxAmt > 0 ? geo.size.width * CGFloat(Double((monthly(item) / maxAmt) as NSDecimalNumber)) : 0, height: 5)
                                }
                            }.frame(width: 60, height: 5)
                            Text(CurrencyFormatter.compact(monthly(item), code: currencyCode))
                                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(Color.bobInk).frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}
