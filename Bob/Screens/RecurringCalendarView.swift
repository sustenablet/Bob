import SwiftUI
import SwiftData

struct RecurringCalendarView: View {
    let recurrings: [RecurringTransaction]
    let currencyCode: String

    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth: Date = Date()

    private let cal = Calendar.current
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // MARK: – Computed

    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var monthShortTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM"
        return f.string(from: displayedMonth)
    }

    /// All days to display in the grid (6 weeks x 7 = 42 cells)
    private var gridDays: [Date?] {
        let start = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))!
        let weekday = cal.component(.weekday, from: start) // 1=Sun
        let offset = weekday - 1
        let range = cal.range(of: .day, in: .month, for: displayedMonth)!
        var days: [Date?] = Array(repeating: nil, count: offset)
        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: start))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    /// Map date → recurring items due on that day
    private var itemsByDate: [Date: [RecurringTransaction]] {
        var dict: [Date: [RecurringTransaction]] = [:]
        for r in recurrings where r.isActive {
            let d = cal.startOfDay(for: r.nextDueDate)
            dict[d, default: []].append(r)
        }
        return dict
    }

    // Bottom summary
    private var monthlyExpenses: [RecurringTransaction] {
        recurrings.filter { $0.isActive && $0.kind == .expense }
    }
    private var monthlyIncome: [RecurringTransaction] {
        recurrings.filter { $0.isActive && $0.kind == .income }
    }
    private var totalExpense: Decimal { monthlyExpenses.reduce(0) { $0 + $1.amount } }
    private var totalIncome: Decimal  { monthlyIncome.reduce(0) { $0 + $1.amount } }

    // MARK: – Body

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                // Day headers
                HStack(spacing: 0) {
                    ForEach(dayLabels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.bobInk2)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                .border(Color.bobHairline, width: 0.5)

                // Calendar grid
                let weeks = gridDays.chunked(into: 7)
                VStack(spacing: 0) {
                    ForEach(0..<weeks.count, id: \.self) { wi in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { di in
                                dayCell(day: weeks[wi][di])
                            }
                        }
                        if wi < weeks.count - 1 {
                            Divider().background(Color.bobHairline)
                        }
                    }
                }
                .border(Color.bobHairline, width: 0.5)

                Spacer()

                bottomBar
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: – Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthShortTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.bobInk)

            Spacer()

            HStack(spacing: 4) {
                Button {
                    withAnimation { displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth)! }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bobInk2)
                        .frame(width: 28, height: 28)
                }.buttonStyle(.plain)

                Button {
                    withAnimation { displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth)! }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bobInk2)
                        .frame(width: 28, height: 28)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.vertical, 14)
    }

    // MARK: – Day cell

    private func dayCell(day: Date?) -> some View {
        let isToday = day.map { cal.isDateInToday($0) } ?? false
        let isCurrentMonth = day.map { cal.component(.month, from: $0) == cal.component(.month, from: displayedMonth) } ?? false
        let items = day.map { itemsByDate[cal.startOfDay(for: $0)] ?? [] } ?? []
        let incomeItems = items.filter { $0.kind == .income }
        let expenseItems = items.filter { $0.kind == .expense }

        return VStack(spacing: 4) {
            // Top: merchant icon (first item if any)
            if let first = items.first {
                ZStack {
                    Circle()
                        .fill(first.kind == .income ? Color.bobAccent : Color.bobDebit)
                        .frame(width: 22, height: 22)
                    Image(systemName: first.kind == .income ? "dollarsign" : (first.category?.sfSymbol ?? "arrow.up"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black.opacity(0.8))
                }
            } else {
                Color.clear.frame(height: 22)
            }

            // Day number
            ZStack {
                if isToday {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.bobChartBlue)
                        .frame(height: 28)
                        .padding(.horizontal, 2)
                }
                Text(day.map { "\(cal.component(.day, from: $0))" } ?? "")
                    .font(.system(size: 15, weight: isToday ? .bold : .regular))
                    .foregroundStyle(
                        isToday ? .white :
                        (isCurrentMonth ? Color.bobInk : Color.bobInk3)
                    )
            }

            // Bottom: amount badge
            if !items.isEmpty {
                let total = items.reduce(Decimal(0)) { $0 + $1.amount }
                let isInc = incomeItems.count > expenseItems.count
                Text(CurrencyFormatter.compact(total, code: currencyCode))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isInc ? Color.black.opacity(0.8) : Color.bobChartBlue)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isInc ? Color.bobAccent : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isInc ? Color.clear : Color.bobChartBlue, lineWidth: 1)
                            )
                    )
            } else {
                Color.clear.frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(
            isToday ? Color.bobChartBlue.opacity(0.08) :
            (!isCurrentMonth ? Color.bobSurface2.opacity(0.4) : Color.clear)
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.bobHairline).frame(width: 0.5)
        }
    }

    // MARK: – Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 20) {
                if !monthlyExpenses.isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(Color.bobDebit).frame(width: 8, height: 8)
                        Text("\(monthlyExpenses.count) Subscription\(monthlyExpenses.count == 1 ? "" : "s")")
                            .font(.system(size: 13)).foregroundStyle(Color.bobInk2)
                    }
                }
                if !monthlyIncome.isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(Color.bobAccent).frame(width: 8, height: 8)
                        Text("\(monthlyIncome.count) Income item\(monthlyIncome.count == 1 ? "" : "s")")
                            .font(.system(size: 13)).foregroundStyle(Color.bobInk2)
                    }
                }
            }
            if !monthlyExpenses.isEmpty {
                Text(CurrencyFormatter.string(totalExpense, code: currencyCode))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.bobInk)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.bobSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.bobHairline).frame(height: 0.5)
        }
    }
}

// MARK: – Array chunked helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

#Preview {
    RecurringCalendarView(recurrings: [], currencyCode: "USD")
}
