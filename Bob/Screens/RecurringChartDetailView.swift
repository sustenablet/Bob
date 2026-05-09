import SwiftUI

// MARK: – Section data model passed to the detail sheet

enum RecurAnalyticsSection: Identifiable {
    case trend(data: [(month: String, amount: Decimal)], currencyCode: String)
    case ratio(monthlyIn: Decimal, monthlyOut: Decimal, currencyCode: String)
    case frequency(data: [(label: String, count: Int, amount: Decimal)], currencyCode: String)
    case category(data: [(name: String, symbol: String, amount: Decimal)], currencyCode: String)
    case heatmap(dayMap: [Int: Int], amountMap: [Int: Decimal], recurrings: [RecurringTransaction], currencyCode: String)
    case topExpenses(items: [RecurringTransaction], currencyCode: String)

    var id: String {
        switch self {
        case .trend:      return "trend"
        case .ratio:      return "ratio"
        case .frequency:  return "frequency"
        case .category:   return "category"
        case .heatmap:    return "heatmap"
        case .topExpenses: return "topExpenses"
        }
    }

    var title: String {
        switch self {
        case .trend:      return "Monthly Cost Trend"
        case .ratio:      return "Income vs Bills Ratio"
        case .frequency:  return "Billing Frequency"
        case .category:   return "Category Breakdown"
        case .heatmap:    return "Due Date Heatmap"
        case .topExpenses: return "Top Recurring Expenses"
        }
    }

    var chartTypes: [String] {
        switch self {
        case .trend:      return ["Line", "Bar", "Area"]
        case .ratio:      return ["Donut", "Bar", "Progress"]
        case .frequency:  return ["Bar", "Donut", "List"]
        case .category:   return ["Bars", "Donut", "Ranked"]
        case .heatmap:    return ["Heatmap", "Calendar", "Timeline"]
        case .topExpenses: return ["Ranked", "Bar", "Donut"]
        }
    }

    var isEmpty: Bool {
        switch self {
        case .trend(let d, _):     return d.allSatisfy { $0.amount == 0 }
        case .ratio(let i, let o, _): return i == 0 && o == 0
        case .frequency(let d, _): return d.allSatisfy { $0.amount == 0 }
        case .category(let d, _):  return d.isEmpty
        case .heatmap(let m, _, _, _): return m.isEmpty
        case .topExpenses(let i, _): return i.isEmpty
        }
    }
}

// MARK: – Detail sheet

struct RecurringChartDetailView: View {
    let section: RecurAnalyticsSection
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: Int = 0

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                typePicker
                    .padding(.top, Spacing.m)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.l) {
                        chartArea
                            .padding(.top, Spacing.m)
                        if !section.isEmpty {
                            summaryStats
                        } else {
                            emptyMessage
                        }
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, Spacing.pageMargin)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: – Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
                    .frame(width: 34, height: 34)
                    .background(Color.bobSurface2)
                    .clipShape(Circle())
            }.buttonStyle(.plain)
            Spacer()
            Text(section.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bobInk)
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.vertical, 16)
    }

    // MARK: – Type picker

    private var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(section.chartTypes.enumerated()), id: \.offset) { idx, label in
                    Button { withAnimation(.easeOut(duration: 0.15)) { selectedType = idx } } label: {
                        Text(label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedType == idx ? Color.black : Color.bobInk2)
                            .padding(.horizontal, 18).padding(.vertical, 9)
                            .background(selectedType == idx ? Color.white : Color.bobSurface2)
                            .clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.pageMargin)
        }
    }

    // MARK: – Chart area (delegates to section-specific views)

    @ViewBuilder
    private var chartArea: some View {
        switch section {
        case .trend(let data, let cc):
            TrendDetailChart(data: data, currencyCode: cc, type: selectedType)
                .frame(height: 280)
                .padding(Spacing.m)
                .background(Color.bobSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))

        case .ratio(let inc, let out, let cc):
            RatioDetailChart(monthlyIn: inc, monthlyOut: out, currencyCode: cc, type: selectedType)
                .frame(height: 280)
                .padding(Spacing.m)
                .background(Color.bobSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))

        case .frequency(let data, let cc):
            FrequencyDetailChart(data: data, currencyCode: cc, type: selectedType)
                .frame(height: 280)
                .padding(Spacing.m)
                .background(Color.bobSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))

        case .category(let data, let cc):
            CategoryDetailChart(data: data, currencyCode: cc, type: selectedType)
                .frame(height: 280)
                .padding(Spacing.m)
                .background(Color.bobSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))

        case .heatmap(let dayMap, let amtMap, let recs, let cc):
            HeatmapDetailChart(dayMap: dayMap, amountMap: amtMap, recurrings: recs, currencyCode: cc, type: selectedType)
                .padding(Spacing.m)
                .background(Color.bobSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))

        case .topExpenses(let items, let cc):
            TopExpensesDetailChart(items: items, currencyCode: cc, type: selectedType)
                .padding(Spacing.m)
                .background(Color.bobSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: – Summary stats

    @ViewBuilder
    private var summaryStats: some View {
        VStack(spacing: 0) {
            switch section {
            case .trend(let data, let cc):
                let total = data.reduce(Decimal(0)) { $0 + $1.amount }
                let avg = data.isEmpty ? Decimal(0) : total / Decimal(data.count)
                statRow("Total (6 months)", value: CurrencyFormatter.string(total, code: cc))
                Divider().background(Color.bobHairline)
                statRow("Monthly average", value: CurrencyFormatter.string(avg, code: cc))
                Divider().background(Color.bobHairline)
                statRow("Months tracked", value: "\(data.count)")

            case .ratio(let inc, let out, let cc):
                let net = inc - out
                statRow("Monthly in", value: CurrencyFormatter.string(inc, code: cc))
                Divider().background(Color.bobHairline)
                statRow("Monthly out", value: CurrencyFormatter.string(out, code: cc))
                Divider().background(Color.bobHairline)
                statRow("Net monthly", value: (net >= 0 ? "+" : "") + CurrencyFormatter.string(net, code: cc))

            case .frequency(let data, let cc):
                statRow("Total categories", value: "\(data.count)")
                Divider().background(Color.bobHairline)
                if let top = data.max(by: { $0.amount < $1.amount }) {
                    statRow("Highest cadence", value: "\(top.label) — \(CurrencyFormatter.string(top.amount, code: cc))/mo")
                }

            case .category(let data, let cc):
                let total = data.reduce(Decimal(0)) { $0 + $1.amount }
                statRow("Total categories", value: "\(data.count)")
                Divider().background(Color.bobHairline)
                statRow("Total monthly", value: CurrencyFormatter.string(total, code: cc))
                if let top = data.first {
                    Divider().background(Color.bobHairline)
                    statRow("Top category", value: "\(top.name) — \(CurrencyFormatter.string(top.amount, code: cc))")
                }

            case .heatmap(let m, let a, _, let cc):
                let busiest = m.max(by: { $0.value < $1.value })
                statRow("Days with bills", value: "\(m.count)")
                Divider().background(Color.bobHairline)
                if let b = busiest { statRow("Busiest day", value: "Day \(b.key) (\(b.value) bills)") }
                Divider().background(Color.bobHairline)
                let total = a.values.reduce(Decimal(0)) { $0 + $1 }
                statRow("Monthly total", value: CurrencyFormatter.string(total, code: cc))

            case .topExpenses(let items, let cc):
                let total = items.reduce(Decimal(0)) { $0 + recurMonthly($1) }
                statRow("Active expenses", value: "\(items.count)")
                Divider().background(Color.bobHairline)
                statRow("Total monthly", value: CurrencyFormatter.string(total, code: cc))
                Divider().background(Color.bobHairline)
                statRow("Annual estimate", value: CurrencyFormatter.string(total * 12, code: cc))
            }
        }
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundStyle(Color.bobInk2)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bobInk)
        }
        .padding(.horizontal, Spacing.m).padding(.vertical, 14)
    }

    private var emptyMessage: some View {
        Text("Add recurring transactions\nto see analytics")
            .font(.system(size: 15)).foregroundStyle(Color.bobInk2)
            .multilineTextAlignment(.center)
            .padding(.vertical, Spacing.xl)
    }

    private func recurMonthly(_ r: RecurringTransaction) -> Decimal {
        switch r.frequency {
        case .weekly: return r.amount * 4
        case .biweekly: return r.amount * 2
        case .monthly: return r.amount
        case .yearly: return r.amount / 12
        }
    }
}

// MARK: – Trend chart (Section 1)

struct TrendDetailChart: View {
    let data: [(month: String, amount: Decimal)]
    let currencyCode: String
    let type: Int

    private var maxVal: Double { data.map { Double(($0.amount as NSDecimalNumber).doubleValue) }.max() ?? 1 }

    var body: some View {
        if data.allSatisfy({ $0.amount == 0 }) {
            ghostBars(count: 6)
        } else {
            switch type {
            case 0: lineChart
            case 1: barChart
            default: areaChart
            }
        }
    }

    private var lineChart: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height - 24
            ZStack {
                gridLines(h: h)
                linePath(w: w, h: h)
                    .stroke(Color.bobChartBlue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                ForEach(Array(data.enumerated()), id: \.offset) { idx, pt in
                    let x = xPos(idx, w); let y = yPos(pt.amount, h)
                    Circle().fill(Color.bobChartBlue).frame(width: 8, height: 8).position(x: x, y: y)
                }
                xLabels(w: w, h: h)
            }
        }
    }

    private var areaChart: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height - 24
            ZStack {
                gridLines(h: h)
                areaPath(w: w, h: h)
                    .fill(LinearGradient(colors: [Color.bobChartBlue.opacity(0.4), Color.bobChartBlue.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                linePath(w: w, h: h)
                    .stroke(Color.bobChartBlue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                xLabels(w: w, h: h)
            }
        }
    }

    private var barChart: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height - 24
            let barW = (w / CGFloat(data.count)) * 0.55
            ZStack {
                gridLines(h: h)
                ForEach(Array(data.enumerated()), id: \.offset) { idx, pt in
                    let x = xPos(idx, w)
                    let barH = maxVal > 0 ? CGFloat(Double((pt.amount as NSDecimalNumber).doubleValue) / maxVal) * h * 0.88 : 8
                    RoundedRectangle(cornerRadius: 4).fill(Color.bobChartBlue)
                        .frame(width: barW, height: max(barH, 4))
                        .position(x: x, y: h - barH / 2)
                    Text(pt.month).font(.system(size: 9)).foregroundStyle(Color.bobInk2)
                        .position(x: x, y: h + 12)
                }
            }
        }
    }

    private func gridLines(h: CGFloat) -> some View {
        ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { pct in
            Path { p in let y = h * (1 - pct * 0.88); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: 10000, y: y)) }
                .stroke(Color.bobHairline, lineWidth: 0.5)
        }
    }

    private func xLabels(w: CGFloat, h: CGFloat) -> some View {
        ForEach(Array(data.enumerated()), id: \.offset) { idx, pt in
            Text(pt.month).font(.system(size: 9)).foregroundStyle(Color.bobInk2)
                .position(x: xPos(idx, w), y: h + 12)
        }
    }

    private func xPos(_ idx: Int, _ w: CGFloat) -> CGFloat {
        guard data.count > 1 else { return w / 2 }
        return CGFloat(idx) / CGFloat(data.count - 1) * w
    }
    private func yPos(_ amount: Decimal, _ h: CGFloat) -> CGFloat {
        guard maxVal > 0 else { return h }
        return h - CGFloat(Double((amount as NSDecimalNumber).doubleValue) / maxVal) * h * 0.88
    }
    private func linePath(w: CGFloat, h: CGFloat) -> Path {
        var p = Path()
        for (i, pt) in data.enumerated() {
            let cp = CGPoint(x: xPos(i, w), y: yPos(pt.amount, h))
            i == 0 ? p.move(to: cp) : p.addLine(to: cp)
        }
        return p
    }
    private func areaPath(w: CGFloat, h: CGFloat) -> Path {
        var p = Path(); p.move(to: CGPoint(x: 0, y: h))
        for (i, pt) in data.enumerated() { p.addLine(to: CGPoint(x: xPos(i, w), y: yPos(pt.amount, h))) }
        p.addLine(to: CGPoint(x: w, y: h)); p.closeSubpath()
        return p
    }
    private func ghostBars(count: Int) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4).fill(Color.bobSurface2)
                    .frame(height: CGFloat([40, 60, 50, 70, 45, 55][i]))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

// MARK: – Ratio chart (Section 2)

struct RatioDetailChart: View {
    let monthlyIn: Decimal
    let monthlyOut: Decimal
    let currencyCode: String
    let type: Int

    private var isEmpty: Bool { monthlyIn == 0 && monthlyOut == 0 }
    private var ratio: Double {
        guard monthlyIn > 0 else { return 0 }
        return min(Double((monthlyOut / monthlyIn) as NSDecimalNumber), 1.0)
    }
    private var net: Decimal { monthlyIn - monthlyOut }

    var body: some View {
        if isEmpty {
            greyRing
        } else {
            switch type {
            case 0: donutView
            case 1: barCompare
            default: progressBar
            }
        }
    }

    private var donutView: some View {
        ZStack {
            Circle().stroke(Color.bobSurface2, lineWidth: 28).frame(width: 200, height: 200)
            if monthlyIn > 0 {
                Circle().trim(from: 0, to: 1).stroke(Color.bobAccent, style: StrokeStyle(lineWidth: 28, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 200, height: 200)
                Circle().trim(from: 0, to: ratio).stroke(Color.bobDebit, style: StrokeStyle(lineWidth: 28, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 200, height: 200)
            }
            VStack(spacing: 4) {
                Text(CurrencyFormatter.string(net, code: currencyCode)).font(.system(size: 22, weight: .bold)).foregroundStyle(net >= 0 ? Color.bobAccent : Color.bobDebit)
                Text("net monthly").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
            }
        }.frame(maxWidth: .infinity)
    }

    private var barCompare: some View {
        let maxV = max((monthlyIn as NSDecimalNumber).doubleValue, (monthlyOut as NSDecimalNumber).doubleValue)
        return HStack(alignment: .bottom, spacing: 24) {
            VStack(spacing: 8) {
                let h = CGFloat(Double((monthlyIn as NSDecimalNumber).doubleValue) / maxV) * 180
                RoundedRectangle(cornerRadius: 8).fill(Color.bobAccent).frame(width: 60, height: max(h, 8))
                Text("Income").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                Text(CurrencyFormatter.compact(monthlyIn, code: currencyCode)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bobAccent)
            }
            VStack(spacing: 8) {
                let h = CGFloat(Double((monthlyOut as NSDecimalNumber).doubleValue) / maxV) * 180
                RoundedRectangle(cornerRadius: 8).fill(Color.bobDebit).frame(width: 60, height: max(h, 8))
                Text("Bills").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                Text(CurrencyFormatter.compact(monthlyOut, code: currencyCode)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bobDebit)
            }
        }.frame(maxWidth: .infinity)
    }

    private var progressBar: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(Color.bobAccent).frame(height: 28)
                    RoundedRectangle(cornerRadius: 8).fill(Color.bobDebit).frame(width: geo.size.width * ratio, height: 28)
                }
            }.frame(height: 28)
            HStack {
                HStack(spacing: 6) { Circle().fill(Color.bobAccent).frame(width: 8, height: 8); Text("Income \(CurrencyFormatter.compact(monthlyIn, code: currencyCode))").font(.system(size: 12)).foregroundStyle(Color.bobInk2) }
                Spacer()
                HStack(spacing: 6) { Circle().fill(Color.bobDebit).frame(width: 8, height: 8); Text("Bills \(CurrencyFormatter.compact(monthlyOut, code: currencyCode))").font(.system(size: 12)).foregroundStyle(Color.bobInk2) }
            }
        }.frame(maxWidth: .infinity)
    }

    private var greyRing: some View {
        ZStack {
            Circle().stroke(Color.bobSurface2, lineWidth: 28).frame(width: 200, height: 200)
            Text("—").font(.system(size: 22, weight: .bold)).foregroundStyle(Color.bobInk2)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: – Frequency chart (Section 3)

struct FrequencyDetailChart: View {
    let data: [(label: String, count: Int, amount: Decimal)]
    let currencyCode: String
    let type: Int

    private let colors: [Color] = [Color.bobChartBlue, Color.bobAccent, Color.bobHex(0xBA68C8), Color.bobHex(0xFF8A65)]
    private var isEmpty: Bool { data.allSatisfy { $0.amount == 0 } }
    private var maxAmt: Double { data.map { Double(($0.amount as NSDecimalNumber).doubleValue) }.max() ?? 1 }

    var body: some View {
        if isEmpty { ghostFrequencyBars } else {
            switch type {
            case 0: frequencyBars
            case 1: frequencyDonut
            default: frequencyList
            }
        }
    }

    private var frequencyBars: some View {
        HStack(alignment: .bottom, spacing: 16) {
            ForEach(Array(data.enumerated()), id: \.offset) { idx, item in
                let h = maxAmt > 0 ? CGFloat(Double((item.amount as NSDecimalNumber).doubleValue) / maxAmt) * 160 : 8
                VStack(spacing: 6) {
                    Text(CurrencyFormatter.compact(item.amount, code: currencyCode)).font(.system(size: 10, weight: .semibold)).foregroundStyle(colors[idx % colors.count])
                    RoundedRectangle(cornerRadius: 6).fill(colors[idx % colors.count]).frame(width: 48, height: max(h, 8))
                    Text(item.label).font(.system(size: 11)).foregroundStyle(Color.bobInk2).lineLimit(1)
                    Text("\(item.count)").font(.system(size: 10)).foregroundStyle(Color.bobInk2)
                }
            }
        }.frame(maxWidth: .infinity)
    }

    private var frequencyDonut: some View {
        let total = data.reduce(Decimal(0)) { $0 + $1.amount }
        return ZStack {
            Circle().stroke(Color.bobSurface2, lineWidth: 24).frame(width: 180, height: 180)
            if total > 0 {
                var cumulative = 0.0
                ForEach(Array(data.enumerated()), id: \.offset) { idx, item in
                    let frac = Double((item.amount / total) as NSDecimalNumber)
                    Circle().trim(from: cumulative, to: cumulative + frac - 0.005)
                        .stroke(colors[idx % colors.count], style: StrokeStyle(lineWidth: 24, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 180, height: 180)
                    let _ = { cumulative += frac }()
                }
            }
            VStack(spacing: 2) {
                Text(CurrencyFormatter.compact(total, code: currencyCode)).font(.system(size: 18, weight: .bold)).foregroundStyle(Color.bobInk)
                Text("per month").font(.system(size: 11)).foregroundStyle(Color.bobInk2)
            }
        }.frame(maxWidth: .infinity)
    }

    private var frequencyList: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.sorted(by: { $0.amount > $1.amount }).enumerated()), id: \.offset) { idx, item in
                HStack(spacing: 12) {
                    ZStack { Circle().fill(colors[idx % colors.count].opacity(0.2)).frame(width: 36, height: 36); Text("\(idx + 1)").font(.system(size: 14, weight: .bold)).foregroundStyle(colors[idx % colors.count]) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bobInk)
                        Text("\(item.count) item\(item.count == 1 ? "" : "s")").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                    }
                    Spacer()
                    Text(CurrencyFormatter.string(item.amount, code: currencyCode)).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
                }
                .padding(.vertical, 10)
                if idx < data.count - 1 { Divider().background(Color.bobHairline) }
            }
        }
    }

    private var ghostFrequencyBars: some View {
        HStack(alignment: .bottom, spacing: 16) {
            ForEach(["W","B","M","Y"], id: \.self) { label in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.bobSurface2).frame(width: 48, height: CGFloat.random(in: 40...100))
                    Text(label).font(.system(size: 11)).foregroundStyle(Color.bobInk2)
                }
            }
        }.frame(maxWidth: .infinity)
    }
}

// MARK: – Category chart (Section 4)

struct CategoryDetailChart: View {
    let data: [(name: String, symbol: String, amount: Decimal)]
    let currencyCode: String
    let type: Int

    private let palette: [Color] = [Color.bobHex(0x4F7FFF), Color.bobHex(0x8DB53E), Color.bobHex(0xBA68C8), Color.bobHex(0xFF8A65), Color.bobHex(0xFFB74D), Color.bobHex(0x4DD0E1)]
    private var isEmpty: Bool { data.isEmpty }
    private var maxAmt: Decimal { data.map { $0.amount }.max() ?? 1 }
    private var total: Decimal { data.reduce(0) { $0 + $1.amount } }

    var body: some View {
        if isEmpty { ghostHBars } else {
            switch type {
            case 0: hBars
            case 1: categoryDonut
            default: rankedList
            }
        }
    }

    private var hBars: some View {
        VStack(spacing: 10) {
            ForEach(Array(data.enumerated()), id: \.element.name) { idx, cat in
                VStack(spacing: 4) {
                    HStack {
                        Text(cat.name).font(.system(size: 13)).foregroundStyle(Color.bobInk).lineLimit(1)
                        Spacer()
                        Text(CurrencyFormatter.string(cat.amount, code: currencyCode)).font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
                        Text(total > 0 ? "\(Int(Double((cat.amount / total * 100) as NSDecimalNumber)))" + "%" : "—").font(.system(size: 11)).foregroundStyle(Color.bobInk2).frame(width: 36, alignment: .trailing)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.bobSurface2).frame(height: 7)
                            RoundedRectangle(cornerRadius: 3).fill(palette[idx % palette.count])
                                .frame(width: maxAmt > 0 ? geo.size.width * CGFloat(Double((cat.amount / maxAmt) as NSDecimalNumber)) : 0, height: 7)
                        }
                    }.frame(height: 7)
                }
            }
        }
    }

    private var categoryDonut: some View {
        ZStack {
            Circle().stroke(Color.bobSurface2, lineWidth: 24).frame(width: 180, height: 180)
            if total > 0 {
                var cum = 0.0
                ForEach(Array(data.enumerated()), id: \.element.name) { idx, cat in
                    let frac = Double((cat.amount / total) as NSDecimalNumber)
                    Circle().trim(from: cum, to: cum + frac - 0.005)
                        .stroke(palette[idx % palette.count], style: StrokeStyle(lineWidth: 24, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 180, height: 180)
                    let _ = { cum += frac }()
                }
            }
            Text(CurrencyFormatter.compact(total, code: currencyCode)).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.bobInk)
        }.frame(maxWidth: .infinity)
    }

    private var rankedList: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.enumerated()), id: \.element.name) { idx, cat in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(palette[idx % palette.count].opacity(0.15)).frame(width: 38, height: 38)
                        Image(systemName: cat.symbol).font(.system(size: 14, weight: .medium)).foregroundStyle(palette[idx % palette.count])
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cat.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bobInk)
                        Text(total > 0 ? "\(Int(Double((cat.amount / total * 100) as NSDecimalNumber)))% of total" : "—").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                    }
                    Spacer()
                    Text(CurrencyFormatter.string(cat.amount, code: currencyCode)).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
                }
                .padding(.vertical, 10)
                if idx < data.count - 1 { Divider().background(Color.bobHairline) }
            }
        }
    }

    private var ghostHBars: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(spacing: 4) {
                    HStack { RoundedRectangle(cornerRadius: 3).fill(Color.bobSurface2).frame(width: 80, height: 12); Spacer(); Text("—").foregroundStyle(Color.bobInk2) }
                    RoundedRectangle(cornerRadius: 3).fill(Color.bobSurface2).frame(height: 7)
                }
            }
        }
    }
}

// MARK: – Heatmap chart (Section 5)

struct HeatmapDetailChart: View {
    let dayMap: [Int: Int]
    let amountMap: [Int: Decimal]
    let recurrings: [RecurringTransaction]
    let currencyCode: String
    let type: Int

    private var isEmpty: Bool { dayMap.isEmpty }
    private var maxCount: Int { dayMap.values.max() ?? 1 }

    var body: some View {
        if isEmpty { ghostHeatmap } else {
            switch type {
            case 0: heatmapView
            case 1: calendarView
            default: timelineList
            }
        }
    }

    private var heatmapView: some View {
        VStack(spacing: 12) {
            let cells = Array(1...31)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(cells, id: \.self) { day in
                    let count = dayMap[day] ?? 0
                    let intensity = maxCount > 0 ? Double(count) / Double(maxCount) : 0
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(count == 0 ? Color.bobSurface2 : Color.bobChartBlue.opacity(0.2 + intensity * 0.8))
                        if count > 0 {
                            Text("\(day)").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.bobInk)
                        } else {
                            Text("\(day)").font(.system(size: 10)).foregroundStyle(Color.bobInk2)
                        }
                    }
                    .frame(height: 36)
                }
            }
            if let busiestDay = dayMap.max(by: { $0.value < $1.value }) {
                Text("Day \(busiestDay.key) is your busiest billing day (\(busiestDay.value) bill\(busiestDay.value == 1 ? "" : "s"))")
                    .font(.system(size: 12)).foregroundStyle(Color.bobInk2).multilineTextAlignment(.center)
            }
        }
    }

    private var calendarView: some View {
        RecurringCalendarView(recurrings: recurrings, currencyCode: currencyCode)
            .frame(height: 400)
    }

    private var timelineList: some View {
        VStack(spacing: 0) {
            let sorted = dayMap.keys.sorted()
            ForEach(Array(sorted.enumerated()), id: \.element) { idx, day in
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.bobChartBlue.opacity(0.15)).frame(width: 36, height: 36)
                        Text("\(day)").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.bobChartBlue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(dayMap[day] ?? 0) bill\(dayMap[day] == 1 ? "" : "s")").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bobInk)
                        Text("Day \(day) of the month").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                    }
                    Spacer()
                    if let amt = amountMap[day] {
                        Text(CurrencyFormatter.string(amt, code: currencyCode)).font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
                    }
                }
                .padding(.vertical, 10)
                if idx < sorted.count - 1 { Divider().background(Color.bobHairline) }
            }
        }
    }

    private var ghostHeatmap: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(1...31, id: \.self) { day in
                RoundedRectangle(cornerRadius: 6).fill(Color.bobSurface2).frame(height: 36)
            }
        }
    }
}

// MARK: – Top Expenses chart (Section 6)

struct TopExpensesDetailChart: View {
    let items: [RecurringTransaction]
    let currencyCode: String
    let type: Int

    private let palette: [Color] = [Color.bobChartBlue, Color.bobAccent, Color.bobHex(0xBA68C8), Color.bobHex(0xFF8A65), Color.bobHex(0xFFB74D), Color.bobHex(0x4DD0E1), Color.bobHex(0xF06292), Color.bobHex(0x4DD0E1)]
    private var sorted: [RecurringTransaction] { items.sorted { monthly($0) > monthly($1) } }
    private var maxMonthly: Decimal { sorted.first.map { monthly($0) } ?? 1 }
    private var isEmpty: Bool { items.isEmpty }

    var body: some View {
        if isEmpty { ghostRanked } else {
            switch type {
            case 0: rankedList
            case 1: barChart
            default: expenseDonut
            }
        }
    }

    private var rankedList: some View {
        VStack(spacing: 0) {
            ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, item in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(palette[idx % palette.count].opacity(0.15)).frame(width: 38, height: 38)
                        Text("\(idx + 1)").font(.system(size: 14, weight: .bold)).foregroundStyle(palette[idx % palette.count])
                    }
                    Text(item.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.bobInk).lineLimit(1)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(CurrencyFormatter.string(monthly(item), code: currencyCode)).font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2).fill(palette[idx % palette.count])
                                .frame(width: maxMonthly > 0 ? geo.size.width * CGFloat(Double((monthly(item) / maxMonthly) as NSDecimalNumber)) : 0, height: 3)
                        }.frame(width: 60, height: 3)
                    }
                }
                .padding(.vertical, 10)
                if idx < sorted.count - 1 { Divider().background(Color.bobHairline) }
            }
        }
    }

    private var barChart: some View {
        let top8 = Array(sorted.prefix(8))
        let maxV = Double((maxMonthly as NSDecimalNumber).doubleValue)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(top8.enumerated()), id: \.element.id) { idx, item in
                let h = maxV > 0 ? CGFloat(Double((monthly(item) as NSDecimalNumber).doubleValue) / maxV) * 160 : 8
                VStack(spacing: 4) {
                    Text(CurrencyFormatter.compact(monthly(item), code: currencyCode)).font(.system(size: 8)).foregroundStyle(palette[idx % palette.count])
                    RoundedRectangle(cornerRadius: 4).fill(palette[idx % palette.count]).frame(height: max(h, 8))
                    Text(String(item.name.prefix(5))).font(.system(size: 8)).foregroundStyle(Color.bobInk2).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var expenseDonut: some View {
        let top6 = Array(sorted.prefix(6))
        let total = top6.reduce(Decimal(0)) { $0 + monthly($1) }
        return ZStack {
            Circle().stroke(Color.bobSurface2, lineWidth: 24).frame(width: 180, height: 180)
            if total > 0 {
                var cum = 0.0
                ForEach(Array(top6.enumerated()), id: \.element.id) { idx, item in
                    let frac = Double((monthly(item) / total) as NSDecimalNumber)
                    Circle().trim(from: cum, to: cum + frac - 0.005)
                        .stroke(palette[idx % palette.count], style: StrokeStyle(lineWidth: 24, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 180, height: 180)
                    let _ = { cum += frac }()
                }
            }
            Text(CurrencyFormatter.compact(total, code: currencyCode)).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.bobInk)
        }.frame(maxWidth: .infinity)
    }

    private var ghostRanked: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    Circle().fill(Color.bobSurface2).frame(width: 38, height: 38)
                    RoundedRectangle(cornerRadius: 4).fill(Color.bobSurface2).frame(height: 14)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4).fill(Color.bobSurface2).frame(width: 60, height: 14)
                }
            }
        }
    }

    private func monthly(_ r: RecurringTransaction) -> Decimal {
        switch r.frequency {
        case .weekly: return r.amount * 4
        case .biweekly: return r.amount * 2
        case .monthly: return r.amount
        case .yearly: return r.amount / 12
        }
    }
}
