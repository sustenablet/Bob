import Foundation

struct MonthSummary {
    let spent: Decimal
    let budget: Decimal
    let monthStart: Date
    let monthEnd: Date
    let now: Date

    var remaining: Decimal { budget - spent }
    var isOverBudget: Bool { spent > budget }

    var progress: Double {
        guard budget > 0 else { return 0 }
        let ratio = (spent as NSDecimalNumber).doubleValue / (budget as NSDecimalNumber).doubleValue
        return min(max(ratio, 0), 1)
    }

    var daysLeft: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: now, to: monthEnd)
        return max(components.day ?? 0, 0)
    }

    var dailyAverage: Decimal {
        let calendar = Calendar.current
        let dayOfMonth = calendar.component(.day, from: now)
        guard dayOfMonth > 0 else { return 0 }
        return spent / Decimal(dayOfMonth)
    }

    static func currentMonthBounds(now: Date = Date()) -> (start: Date, end: Date) {
        bounds(for: now)
    }

    static func bounds(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? date
        let end = calendar.date(byAdding: .second, value: -1, to: nextMonth) ?? nextMonth
        return (start, end)
    }
}
