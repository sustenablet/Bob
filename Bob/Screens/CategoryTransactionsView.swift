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

    private var byDay: [Date: [Expense]] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
    }

    private var sortedDays: [Date] { byDay.keys.sorted(by: >) }

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()

            if filtered.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: symbol).font(.system(size: 48)).foregroundStyle(Color.bobInk3)
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
                        .foregroundStyle(Color.bobInk3)
                }
            }
        }
        .sheet(item: $editingExpense) { tx in
            AddTransactionSheet(currencyCode: currencyCode, expenseToEdit: tx)
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
