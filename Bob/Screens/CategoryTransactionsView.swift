import SwiftUI
import SwiftData

struct CategoryTransactionsView: View {
    let categoryName: String
    let symbol: String
    let period: AnalyticsPeriod
    let kind: TransactionKind
    let currencyCode: String

    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse),
                  SortDescriptor(\Expense.createdAt, order: .reverse)])
    private var allExpenses: [Expense]

    @Environment(\.modelContext) private var modelContext
    @State private var editingExpense: Expense?

    private var filtered: [Expense] {
        allExpenses.filter { tx in
            tx.kind == kind &&
            (tx.category?.name == categoryName || (tx.category == nil && categoryName == "Other")) &&
            isInPeriod(tx.date)
        }
    }

    private var total: Decimal { filtered.reduce(0) { $0 + $1.amount } }
    private var average: Decimal { filtered.isEmpty ? 0 : total / Decimal(filtered.count) }

    private var byDay: [Date: [Expense]] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
    }

    private var sortedDays: [Date] { byDay.keys.sorted(by: >) }

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if !filtered.isEmpty {
                    summaryStrip
                }
                mainContent
            }
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bobBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(categoryName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.bobInk)
                    Text("\(period.label) · \(CurrencyFormatter.string(total, code: currencyCode))")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.bobInk2)
                }
            }
        }
        .sheet(item: $editingExpense) { tx in
            AddTransactionSheet(currencyCode: currencyCode, expenseToEdit: tx)
        }
    }

    // MARK: – Summary strip

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            summaryCell(
                icon: "sum",
                iconColor: kind == .expense ? Color.bobDebit : Color.bobGreen,
                label: "Total",
                value: CurrencyFormatter.string(total, code: currencyCode)
            )
            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 36)
            summaryCell(
                icon: "number",
                iconColor: Color.bobChartBlue,
                label: "Transactions",
                value: "\(filtered.count)"
            )
            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 36)
            summaryCell(
                icon: "divide",
                iconColor: Color.bobInk2,
                label: "Average",
                value: CurrencyFormatter.string(average, code: currencyCode)
            )
        }
        .padding(.vertical, 12)
        .background(Color.bobSurface.opacity(0.8))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
    }

    private func summaryCell(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.bobInk2)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.bobInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Main content

    @ViewBuilder
    private var mainContent: some View {
        if filtered.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: symbol).font(.system(size: 48)).foregroundStyle(Color.bobInk2)
                Text("No transactions").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.bobInk)
                Text("No \(categoryName.lowercased()) transactions for this period")
                    .font(.bobBody).foregroundStyle(Color.bobInk2).multilineTextAlignment(.center)
                Spacer()
            }
            .padding()
        } else {
            List {
                ForEach(sortedDays, id: \.self) { day in
                    Section {
                        ForEach(byDay[day] ?? [], id: \.id) { tx in
                            Button { editingExpense = tx } label: {
                                ExpenseRow(expense: tx, currencyCode: currencyCode)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.bobSurface)
                            .listRowInsets(EdgeInsets(top: 0, leading: Spacing.pageMargin, bottom: 0, trailing: Spacing.pageMargin))
                            .listRowSeparatorTint(Color.bobHairline)
                        }
                    } header: {
                        Text(dayLabel(for: day))
                            .eyebrow()
                            .padding(.vertical, Spacing.xs)
                            .background(Color.bobBackground)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.bobBackground)
        }
    }

    private func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    private func isInPeriod(_ date: Date) -> Bool {
        let cal = Calendar.current
        switch period {
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
}
