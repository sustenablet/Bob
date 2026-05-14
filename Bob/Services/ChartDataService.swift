import Foundation

enum ChartPeriod {
    case week
    case month
    case quarter
    case year
}

struct ChartPeriodSegment {
    let label: String
    let start: Date
    let end: Date
}

enum ChartDataService {
    static func segments(for period: ChartPeriod, count: Int, now: Date = Date(), calendar: Calendar = .current) -> [ChartPeriodSegment] {
        switch period {
        case .week:
            return lastNWeeks(count, now: now, calendar: calendar)
        case .month:
            return lastNMonths(count, now: now, calendar: calendar)
        case .quarter:
            return lastNQuarters(count, now: now, calendar: calendar)
        case .year:
            return lastNYears(count, now: now, calendar: calendar)
        }
    }

    static func cumulativeDailyExpensePoints(
        transactions: [Expense],
        monthDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [(day: Int, amount: Decimal)] {
        let bounds = MonthSummary.bounds(for: monthDate)
        var dict: [Int: Decimal] = [:]
        for tx in transactions where tx.kind == .expense && tx.date >= bounds.start && tx.date <= bounds.end {
            let day = calendar.component(.day, from: tx.date)
            dict[day, default: 0] += tx.amount
        }
        let totalDays = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        var cumulative: Decimal = 0
        return (1...totalDays).map { day in
            cumulative += dict[day] ?? 0
            return (day, cumulative)
        }
    }

    static func monthlyIncomeExpenseSeries(
        transactions: [Expense],
        months: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [(label: String, income: Decimal, expenses: Decimal)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return (0..<months).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let bounds = MonthSummary.bounds(for: date)
            let inMonth = transactions.filter { $0.date >= bounds.start && $0.date <= bounds.end }
            let income = inMonth.filter { $0.kind == .income }.reduce(Decimal.zero) { $0 + $1.amount }
            let expenses = inMonth.filter { $0.kind == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
            return (formatter.string(from: bounds.start), income, expenses)
        }
    }

    static func dailyExpenseBreakdown(
        transactions: [Expense],
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [(label: String, amount: Decimal)] {
        var dict: [Date: Decimal] = [:]
        for tx in transactions where tx.kind == .expense && tx.date >= start && tx.date <= end {
            dict[calendar.startOfDay(for: tx.date), default: 0] += tx.amount
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return dict.sorted { $0.key < $1.key }.map { (formatter.string(from: $0.key), $0.value) }
    }

    private static func lastNWeeks(_ n: Int, now: Date, calendar: Calendar) -> [ChartPeriodSegment] {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let startOfThisWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return (0..<n).reversed().map { offset in
            let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: startOfThisWeek) ?? startOfThisWeek
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return ChartPeriodSegment(label: formatter.string(from: start), start: start, end: end)
        }
    }

    private static func lastNMonths(_ n: Int, now: Date, calendar: Calendar) -> [ChartPeriodSegment] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return (0..<n).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let bounds = MonthSummary.bounds(for: date)
            return ChartPeriodSegment(label: formatter.string(from: bounds.start), start: bounds.start, end: bounds.end)
        }
    }

    private static func lastNQuarters(_ n: Int, now: Date, calendar: Calendar) -> [ChartPeriodSegment] {
        let month = calendar.component(.month, from: now)
        let quarterStartMonth = ((month - 1) / 3) * 3 + 1
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let quarterAnchor = calendar.date(byAdding: .month, value: -(month - quarterStartMonth), to: currentMonthStart) ?? currentMonthStart
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return (0..<n).reversed().map { i in
            let start = calendar.date(byAdding: .month, value: -(i * 3), to: quarterAnchor) ?? quarterAnchor
            let rawEnd = calendar.date(byAdding: .month, value: 3, to: start) ?? start
            let end = calendar.date(byAdding: .second, value: -1, to: rawEnd) ?? rawEnd
            return ChartPeriodSegment(label: "Q \(formatter.string(from: start))", start: start, end: end)
        }
    }

    private static func lastNYears(_ n: Int, now: Date, calendar: Calendar) -> [ChartPeriodSegment] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return (0..<n).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .year, value: -offset, to: now) else { return nil }
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: date)) ?? date
            let rawEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? yearStart
            let end = calendar.date(byAdding: .second, value: -1, to: rawEnd) ?? rawEnd
            return ChartPeriodSegment(label: formatter.string(from: yearStart), start: yearStart, end: end)
        }
    }
}

