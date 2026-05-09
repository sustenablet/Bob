import SwiftUI
import SwiftData

struct TransactionsListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]
    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse),
                  SortDescriptor(\Expense.createdAt, order: .reverse)])
    private var allTransactions: [Expense]
    @Query(sort: \ExpenseCategory.sortOrder) private var allCategories: [ExpenseCategory]

    @State private var searchText            = ""
    @State private var editingExpense: Expense?
    @State private var expenseToDelete: Expense?
    @State private var recategorizingExpense: Expense?
    @State private var selectedCategory: ExpenseCategory?
    @State private var dateRange: DateRangeFilter = .thisMonth
    @State private var sort: SortOption = .newest
    @State private var amountFilter: AmountFilter = .any
    @State private var showFilters = false

    enum AmountFilter: String, CaseIterable {
        case any, over50, over100
        var label: String {
            switch self { case .any: return "Any amount"; case .over50: return "> $50"; case .over100: return "> $100" }
        }
        var minAmount: Decimal { switch self { case .any: return 0; case .over50: return 50; case .over100: return 100 } }
    }

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

        // Amount filter
        if amountFilter != .any {
            base = base.filter { $0.amount >= amountFilter.minAmount }
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

    private var totalIncome: Decimal   { filtered.filter { $0.kind == .income  }.reduce(0) { $0 + $1.amount } }
    private var totalExpenses: Decimal { filtered.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount } }

    private var activeFilters: Int {
        (selectedCategory != nil ? 1 : 0) + (dateRange != .all ? 1 : 0) +
        (sort != .newest ? 1 : 0) + (amountFilter != .any ? 1 : 0)
    }

    // Category summary (when filtered to one category)
    private var categorySummary: (total: Decimal, count: Int, avg: Decimal)? {
        guard let _ = selectedCategory else { return nil }
        let txns = filtered
        guard !txns.isEmpty else { return nil }
        let total = txns.reduce(0) { $0 + $1.amount }
        return (total, txns.count, total / Decimal(txns.count))
    }

    // Highest-spend day
    private var highestSpendDay: Date? {
        let byDay = Dictionary(grouping: filtered.filter { $0.kind == .expense }) { Calendar.current.startOfDay(for: $0.date) }
        return byDay.max { a, b in a.value.reduce(0) { $0 + $1.amount } < b.value.reduce(0) { $0 + $1.amount } }?.key
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

                // Category summary panel
                if let cat = selectedCategory, let summary = categorySummary {
                    categorySummaryPanel(cat: cat, summary: summary)
                        .padding(.horizontal, Spacing.pageMargin)
                }

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
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button { recategorizingExpense = tx } label: {
                                            Label("Category", systemImage: "tag")
                                        }
                                        .tint(Color.bobAccent)
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
        .toolbarBackground(Color.bobBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
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
        .sheet(item: $recategorizingExpense) { tx in
            RecategorizeSheet(expense: tx, currencyCode: currencyCode)
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

                // Amount filter
                HStack(spacing: 8) {
                    Text("Amount:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bobInk2)
                        .padding(.leading, Spacing.pageMargin)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(AmountFilter.allCases, id: \.self) { amt in
                                filterChip(amt.label, selected: amountFilter == amt) {
                                    withAnimation { amountFilter = amt }
                                }
                            }
                        }
                        .padding(.trailing, Spacing.pageMargin)
                    }
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
                            amountFilter = .any
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

    // MARK: – Category summary panel

    private func categorySummaryPanel(cat: ExpenseCategory, summary: (total: Decimal, count: Int, avg: Decimal)) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.bobAccent.opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: cat.sfSymbol).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.bobAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(cat.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bobInk)
                Text("\(summary.count) transactions · \(CurrencyFormatter.string(summary.avg, code: currencyCode)) avg")
                    .font(.system(size: 12)).foregroundStyle(Color.bobInk2)
            }
            Spacer()
            Text(CurrencyFormatter.string(summary.total, code: currencyCode))
                .font(.system(size: 16, weight: .bold)).monospacedDigit().foregroundStyle(Color.bobInk)
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bobAccent.opacity(0.3), lineWidth: 1))
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
        let isHighest = highestSpendDay == date

        return HStack {
            HStack(spacing: 6) {
                Text(dayLabel(for: date)).eyebrow()
                if isHighest {
                    Text("· highest").font(.system(size: 10)).foregroundStyle(Color.bobDebit)
                }
            }
            Spacer()
            Text(netDisplay).font(.bobMono(12)).monospacedDigit().foregroundStyle(netColor)
        }
        .padding(.vertical, Spacing.xs)
        .background(Color.bobBackground)
    }

    // MARK: – Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: searchText.isEmpty && activeFilters == 0 ? "tray" : "magnifyingglass")
                .font(.system(size: 52)).foregroundStyle(Color.bobInk2)
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

// MARK: – Recategorize sheet

struct RecategorizeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExpenseCategory.sortOrder) private var allCategories: [ExpenseCategory]

    let expense: Expense
    let currencyCode: String

    private var visibleCategories: [ExpenseCategory] { allCategories.filter { $0.kind == expense.kind } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }.font(.bobBody).foregroundStyle(Color.bobInk2)
                Spacer()
                Text("Change Category").font(.bobBodyMed)
                Spacer()
                Color.clear.frame(width: 60)
            }
            .padding(.horizontal, Spacing.pageMargin).padding(.vertical, Spacing.s)
            HairlineDivider()

            // Current transaction preview
            HStack(spacing: 10) {
                Text(expense.merchant?.isEmpty == false ? expense.merchant! : expense.category?.name ?? "Expense")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.bobInk)
                Spacer()
                Text(CurrencyFormatter.string(expense.amount, code: currencyCode))
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(expense.kind == .income ? Color.bobAccent : Color.bobDebit)
            }
            .padding(.horizontal, Spacing.pageMargin).padding(.vertical, Spacing.m)
            HairlineDivider()

            ScrollView {
                let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(visibleCategories, id: \.id) { cat in
                        Button {
                            expense.category = cat
                            try? modelContext.save()
                            HapticManager.light()
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(expense.category?.id == cat.id ? Color.bobAccent : Color.bobSurface)
                                        .frame(width: 52, height: 52)
                                    Circle()
                                        .stroke(expense.category?.id == cat.id ? Color.bobAccent : Color.bobHairline, lineWidth: 1)
                                        .frame(width: 52, height: 52)
                                    Image(systemName: cat.sfSymbol)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(expense.category?.id == cat.id ? .white : Color.bobInk2)
                                }
                                Text(cat.name).font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(expense.category?.id == cat.id ? Color.bobAccent : Color.bobInk2)
                                    .multilineTextAlignment(.center).lineLimit(2)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.pageMargin)
            }
        }
        .background(Color.bobBackground.ignoresSafeArea())
    }
}
