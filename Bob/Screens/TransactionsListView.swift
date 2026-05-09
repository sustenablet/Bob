import SwiftUI
import SwiftData

struct TransactionsListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]
    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse),
                  SortDescriptor(\Expense.createdAt, order: .reverse)])
    private var allTransactions: [Expense]
    @Query(sort: \ExpenseCategory.sortOrder) private var allCategories: [ExpenseCategory]

    @State private var searchText        = ""
    @State private var editingExpense: Expense?
    @State private var expenseToDelete: Expense?
    @State private var selectedCategory: ExpenseCategory?
    @State private var dateRange: DateRangeFilter = .thisMonth
    @State private var sort: SortOption = .newest
    @State private var showFilters       = false

    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }

    // MARK: – Filtering & sorting

    private var filtered: [Expense] {
        var base = allTransactions

        // Search
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            base = base.filter {
                ($0.merchant?.lowercased().contains(q) ?? false) ||
                ($0.note?.lowercased().contains(q) ?? false) ||
                ($0.category?.name.lowercased().contains(q) ?? false)
            }
        }

        // Category
        if let cat = selectedCategory {
            base = base.filter { $0.category?.id == cat.id }
        }

        // Date range
        let cal = Calendar.current
        switch dateRange {
        case .all: break
        case .today:
            base = base.filter { cal.isDateInToday($0.date) }
        case .thisWeek:
            let start = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            base = base.filter { $0.date >= start }
        case .thisMonth:
            let b = MonthSummary.currentMonthBounds()
            base = base.filter { $0.date >= b.start && $0.date <= b.end }
        case .last3Months:
            let start = cal.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            base = base.filter { $0.date >= start }
        }

        // Sort
        switch sort {
        case .newest:  base.sort { $0.date > $1.date }
        case .oldest:  base.sort { $0.date < $1.date }
        case .highest: base.sort { $0.amount > $1.amount }
        case .lowest:  base.sort { $0.amount < $1.amount }
        }

        return base
    }

    // MARK: – Summary stats

    private var totalIncome: Decimal  { filtered.filter { $0.kind == .income  }.reduce(0) { $0 + $1.amount } }
    private var totalExpenses: Decimal { filtered.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount } }

    private var activeFilters: Int {
        (selectedCategory != nil ? 1 : 0) + (dateRange != .all ? 1 : 0) + (sort != .newest ? 1 : 0)
    }

    // MARK: – Grouping

    private var byDay: [Date: [Expense]] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
    }

    private var sortedDays: [Date] {
        byDay.keys.sorted(by: sort == .oldest ? (<) : (>))
    }

    // MARK: – Body

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                summaryBar
                filterBar

                if filtered.isEmpty {
                    emptyState
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
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) { expenseToDelete = tx } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                dayHeader(for: day)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.bobBackground)
                }
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search transactions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { withAnimation { showFilters.toggle() } } label: {
                    Image(systemName: activeFilters > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(activeFilters > 0 ? Color.bobAccent : Color.bobInk)
                        .font(.system(size: 18))
                        .overlay(alignment: .topTrailing) {
                            if activeFilters > 0 {
                                Text("\(activeFilters)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.bobDebit)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                }
            }
        }
        .sheet(item: $editingExpense) { tx in
            AddTransactionSheet(currencyCode: currencyCode, expenseToEdit: tx)
        }
        .alert("Delete Transaction", isPresented: .init(
            get: { expenseToDelete != nil },
            set: { if !$0 { expenseToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { expenseToDelete = nil }
            Button("Delete", role: .destructive) {
                if let tx = expenseToDelete { delete(tx) }
                expenseToDelete = nil
            }
        } message: { Text("This cannot be undone.") }
    }

    // MARK: – Summary bar

    private var summaryBar: some View {
        HStack(spacing: 0) {
            summaryStatCell(
                label: "Income",
                amount: totalIncome,
                color: .bobAccent,
                icon: "arrow.down.circle.fill"
            )
            Divider().frame(height: 36)
            summaryStatCell(
                label: "Expenses",
                amount: totalExpenses,
                color: .bobDebit,
                icon: "arrow.up.circle.fill"
            )
            Divider().frame(height: 36)
            summaryStatCell(
                label: "Net",
                amount: abs(totalIncome - totalExpenses),
                color: totalIncome >= totalExpenses ? .bobAccent : .bobDebit,
                icon: totalIncome >= totalExpenses ? "plus.circle.fill" : "minus.circle.fill"
            )
        }
        .padding(.vertical, 12)
        .background(Color.bobSurface)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private func summaryStatCell(label: String, amount: Decimal, color: Color, icon: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.bobInk2)
            }
            Text(CurrencyFormatter.string(amount, code: currencyCode))
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.bobInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Filter bar

    @ViewBuilder
    private var filterBar: some View {
        if showFilters {
            VStack(spacing: Spacing.s) {
                // Date range chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DateRangeFilter.allCases, id: \.self) { range in
                            filterChip(range.label, selected: dateRange == range) {
                                withAnimation { dateRange = range }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.pageMargin)
                }

                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("All", selected: selectedCategory == nil) {
                            withAnimation { selectedCategory = nil }
                        }
                        ForEach(allCategories, id: \.id) { cat in
                            filterChip(cat.name, selected: selectedCategory?.id == cat.id) {
                                withAnimation { selectedCategory = selectedCategory?.id == cat.id ? nil : cat }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.pageMargin)
                }

                // Sort row
                HStack(spacing: 8) {
                    Text("Sort:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bobInk2)
                        .padding(.leading, Spacing.pageMargin)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                filterChip(option.label, selected: sort == option) {
                                    withAnimation { sort = option }
                                }
                            }
                        }
                        .padding(.trailing, Spacing.pageMargin)
                    }
                }

                if activeFilters > 0 {
                    Button {
                        withAnimation {
                            selectedCategory = nil
                            dateRange = .all
                            sort = .newest
                        }
                    } label: {
                        Text("Clear all filters")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.bobDebit)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, Spacing.s)
            .background(Color.bobSurface)
            .overlay(alignment: .bottom) { HairlineDivider() }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func filterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : Color.bobInk2)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(selected ? Color.bobInk : Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : Color.bobHairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: – Day header

    private func dayHeader(for date: Date) -> some View {
        let items = byDay[date] ?? []
        let net = items.reduce(Decimal.zero) { acc, tx in acc + (tx.kind == .income ? tx.amount : -tx.amount) }
        let netColor: Color = net > 0 ? .bobAccent : net < 0 ? .bobDebit : .bobInk3
        let netDisplay: String = {
            let formatted = CurrencyFormatter.string(abs(net as NSDecimalNumber as Decimal), code: currencyCode)
            return net > 0 ? "+\(formatted)" : net < 0 ? "-\(formatted)" : formatted
        }()

        return HStack {
            Text(dayLabel(for: date)).eyebrow()
            Spacer()
            Text(netDisplay)
                .font(.bobMono(12)).monospacedDigit().foregroundStyle(netColor)
        }
        .padding(.vertical, Spacing.xs)
        .background(Color.bobBackground)
    }

    // MARK: – Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: searchText.isEmpty && activeFilters == 0 ? "tray" : "magnifyingglass")
                .font(.system(size: 52)).foregroundStyle(Color.bobInk3)
            Text(searchText.isEmpty && activeFilters == 0 ? "No transactions yet" : "No results")
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.bobInk)
            Text(searchText.isEmpty && activeFilters == 0
                 ? "Tap + to add your first transaction"
                 : "Try adjusting your filters")
                .font(.bobBody).foregroundStyle(Color.bobInk2).multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: – Helpers

    private func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    private func delete(_ tx: Expense) {
        modelContext.delete(tx); try? modelContext.save()
    }
}

// MARK: – Filter enums

enum DateRangeFilter: String, CaseIterable {
    case all, today, thisWeek, thisMonth, last3Months

    var label: String {
        switch self {
        case .all:         return "All time"
        case .today:       return "Today"
        case .thisWeek:    return "This week"
        case .thisMonth:   return "This month"
        case .last3Months: return "Last 3 months"
        }
    }
}

enum SortOption: String, CaseIterable {
    case newest, oldest, highest, lowest

    var label: String {
        switch self {
        case .newest:  return "Newest"
        case .oldest:  return "Oldest"
        case .highest: return "Highest"
        case .lowest:  return "Lowest"
        }
    }
}
