import SwiftUI
import SwiftData

struct RecurringTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringTransaction.nextDueDate) private var recurrings: [RecurringTransaction]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]

    @State private var showAddRecurring   = false
    @State private var editingRecurring: RecurringTransaction?
    @State private var deletingRecurring: RecurringTransaction?
    @State private var expandedCategories: Set<String> = []

    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }
    private var activeRecurrings:   [RecurringTransaction] { recurrings.filter { $0.isActive } }
    private var inactiveRecurrings: [RecurringTransaction] { recurrings.filter { !$0.isActive } }

    // MARK: – Computed

    private func monthlyEquivalent(_ r: RecurringTransaction) -> Decimal {
        switch r.frequency {
        case .weekly:    return r.amount * 4
        case .biweekly:  return r.amount * 2
        case .monthly:   return r.amount
        case .yearly:    return r.amount / 12
        }
    }

    private func annualEquivalent(_ r: RecurringTransaction) -> Decimal {
        switch r.frequency {
        case .weekly:    return r.amount * 52
        case .biweekly:  return r.amount * 26
        case .monthly:   return r.amount * 12
        case .yearly:    return r.amount
        }
    }

    private var monthlyOut: Decimal { activeRecurrings.filter { $0.kind == .expense }.reduce(0) { $0 + monthlyEquivalent($1) } }
    private var monthlyIn: Decimal  { activeRecurrings.filter { $0.kind == .income  }.reduce(0) { $0 + monthlyEquivalent($1) } }
    private var annualNet: Decimal  { (monthlyIn - monthlyOut) * 12 }
    private var annualOut: Decimal  { activeRecurrings.filter { $0.kind == .expense }.reduce(0) { $0 + annualEquivalent($1) } }
    private var annualIn: Decimal   { activeRecurrings.filter { $0.kind == .income  }.reduce(0) { $0 + annualEquivalent($1) } }

    private var largestExpense: RecurringTransaction? {
        activeRecurrings.filter { $0.kind == .expense }.max { monthlyEquivalent($0) < monthlyEquivalent($1) }
    }

    // 30-day upcoming payments
    private var upcoming30: [RecurringTransaction] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return activeRecurrings.filter { $0.nextDueDate <= cutoff }.sorted { $0.nextDueDate < $1.nextDueDate }
    }

    private var upcoming30Total: Decimal { upcoming30.reduce(0) { $0 + $1.amount } }

    // Category-grouped active recurrings
    private var activeByCategory: [(category: String, items: [RecurringTransaction], total: Decimal)] {
        let grouped = Dictionary(grouping: activeRecurrings) { r -> String in r.category?.name ?? "Uncategorized" }
        return grouped.map { key, items in
            (category: key, items: items.sorted { monthlyEquivalent($0) > monthlyEquivalent($1) },
             total: items.reduce(0) { $0 + monthlyEquivalent($1) })
        }
        .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bobBackground.ignoresSafeArea()

                if recurrings.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.m) {
                            summaryStrip
                            if !upcoming30.isEmpty { upcomingCalendarSection }
                            if !activeRecurrings.isEmpty { activeSection }
                            if !inactiveRecurrings.isEmpty { pausedSection }
                            annualProjectionCard
                        }
                        .padding(.horizontal, Spacing.pageMargin)
                        .padding(.top, Spacing.m)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Recurring")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.bobBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddRecurring = true } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .medium)).foregroundStyle(Color.bobInk)
                    }
                }
            }
            .sheet(isPresented: $showAddRecurring) { AddRecurringSheet(currencyCode: currencyCode) }
            .sheet(item: $editingRecurring) { r in AddRecurringSheet(currencyCode: currencyCode, recurringToEdit: r) }
            .alert("Delete Recurring", isPresented: .init(get: { deletingRecurring != nil }, set: { if !$0 { deletingRecurring = nil } })) {
                Button("Cancel", role: .cancel) { deletingRecurring = nil }
                Button("Delete", role: .destructive) {
                    if let r = deletingRecurring { modelContext.delete(r); try? modelContext.save() }
                    deletingRecurring = nil
                }
            } message: { Text("This won't delete past transactions already created from this rule.") }
        }
    }

    // MARK: – Summary strip

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            summaryCell(label: "Monthly out", value: CurrencyFormatter.compact(monthlyOut, code: currencyCode), color: .bobDebit)
            Divider().frame(height: 36)
            summaryCell(label: "Monthly in",  value: CurrencyFormatter.compact(monthlyIn,  code: currencyCode), color: .bobAccent)
            Divider().frame(height: 36)
            summaryCell(
                label: "Annual net",
                value: (annualNet >= 0 ? "+" : "") + CurrencyFormatter.compact(annualNet, code: currencyCode),
                color: annualNet >= 0 ? .bobAccent : .bobDebit
            )
        }
        .padding(.vertical, 14)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bobHairline, lineWidth: 1))
    }

    private func summaryCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.bobInk2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – 30-day payment calendar

    private var upcomingCalendarSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Next 30 Days").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)
                Spacer()
                Text(CurrencyFormatter.string(upcoming30Total, code: currencyCode))
                    .font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk2)
            }
            VStack(spacing: 0) {
                ForEach(Array(upcoming30.enumerated()), id: \.element.id) { idx, r in
                    calendarRow(r)
                    if idx < upcoming30.count - 1 { Divider().padding(.leading, 52) }
                }
            }
            .background(Color.bobSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bobHairline, lineWidth: 1))
        }
    }

    private func calendarRow(_ r: RecurringTransaction) -> some View {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: r.nextDueDate)).day ?? 0
        let dotColor: Color = days <= 0 ? .bobDebit : days <= 3 ? .bobDebit : days <= 7 ? Color.bobHex(0xF59E0B) : Color.bobInk3
        let isIncome = r.kind == .income
        let df = DateFormatter(); df.dateFormat = "MMM d"

        return Button { editingRecurring = r } label: {
            HStack(spacing: 12) {
                Text(df.string(from: r.nextDueDate))
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bobInk3).frame(width: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(r.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.bobInk).lineLimit(1)
                    if let cat = r.category?.name { Text(cat).font(.system(size: 11)).foregroundStyle(Color.bobInk3) }
                }
                Spacer()
                Text((isIncome ? "+" : "") + CurrencyFormatter.string(r.amount, code: currencyCode))
                    .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(isIncome ? Color.bobAccent : Color.bobInk)
                Circle().fill(dotColor).frame(width: 8, height: 8)
            }
            .padding(.horizontal, Spacing.m).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: – Active section (category-grouped)

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionHeader("Active — \(activeRecurrings.count)")
            ForEach(activeByCategory, id: \.category) { group in
                categoryGroup(group)
            }
        }
    }

    private func categoryGroup(_ group: (category: String, items: [RecurringTransaction], total: Decimal)) -> some View {
        let isExpanded = expandedCategories.contains(group.category) || activeByCategory.count == 1
        return VStack(spacing: Spacing.xs) {
            // Group header
            if activeByCategory.count > 1 {
                Button {
                    withAnimation {
                        if expandedCategories.contains(group.category) {
                            expandedCategories.remove(group.category)
                        } else {
                            expandedCategories.insert(group.category)
                        }
                    }
                } label: {
                    HStack {
                        Text(group.category)
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bobInk2)
                            .textCase(.uppercase).tracking(0.5)
                        Spacer()
                        Text("≈ \(CurrencyFormatter.compact(group.total, code: currencyCode))/mo")
                            .font(.system(size: 11)).foregroundStyle(Color.bobInk3)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.bobInk3)
                    }
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                ForEach(group.items) { r in
                    RecurringCard(recurring: r, currencyCode: currencyCode)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture { editingRecurring = r }
                        .contextMenu { contextMenuItems(for: r) }
                    // "Log Now" overlay for overdue items
                    if (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: r.nextDueDate)).day ?? 0) <= 0 {
                        Button { logNow(r) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                                Text("Log Now — record this payment")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(Color.bobDebit)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.bobDebit.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: – Paused section

    private var pausedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionHeader("Paused — \(inactiveRecurrings.count)")
            ForEach(inactiveRecurrings) { r in
                RecurringCard(recurring: r, currencyCode: currencyCode, isInactive: true)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture { editingRecurring = r }
                    .contextMenu { contextMenuItems(for: r) }
            }
        }
    }

    // MARK: – Annual projection card

    private var annualProjectionCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Annual Projection").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.bobInk)

            HStack(spacing: 0) {
                projectionStat(label: "Total out", value: CurrencyFormatter.compact(annualOut, code: currencyCode) + "/yr", color: .bobDebit)
                Divider().frame(height: 40).padding(.horizontal, Spacing.m)
                projectionStat(label: "Total in", value: CurrencyFormatter.compact(annualIn, code: currencyCode) + "/yr", color: .bobAccent)
                Divider().frame(height: 40).padding(.horizontal, Spacing.m)
                let net = annualIn - annualOut
                projectionStat(
                    label: net >= 0 ? "Net surplus" : "Net deficit",
                    value: (net >= 0 ? "+" : "") + CurrencyFormatter.compact(abs(net as NSDecimalNumber as Decimal), code: currencyCode),
                    color: net >= 0 ? .bobAccent : .bobDebit
                )
            }

            if let largest = largestExpense {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 13)).foregroundStyle(Color.bobDebit)
                    Text("Largest: \(largest.name) at \(CurrencyFormatter.string(monthlyEquivalent(largest), code: currencyCode))/mo")
                        .font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                }
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bobHairline, lineWidth: 1))
    }

    private func projectionStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11)).foregroundStyle(Color.bobInk3)
            Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: – Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.bobInk2).textCase(.uppercase).tracking(0.6)
    }

    @ViewBuilder
    private func contextMenuItems(for r: RecurringTransaction) -> some View {
        Button { editingRecurring = r } label: { Label("Edit", systemImage: "pencil") }
        Button {
            r.isActive.toggle()
            try? modelContext.save()
            HapticManager.light()
        } label: {
            Label(r.isActive ? "Pause" : "Resume", systemImage: r.isActive ? "pause.circle" : "play.circle")
        }
        Divider()
        Button(role: .destructive) { deletingRecurring = r } label: { Label("Delete", systemImage: "trash") }
    }

    private func logNow(_ r: RecurringTransaction) {
        let expense = Expense(
            amount: r.amount, date: r.nextDueDate, note: "Logged from recurring",
            merchant: nil, category: r.category, kind: r.kind == .income ? .income : .expense
        )
        modelContext.insert(expense)
        r.advanceToNextDueDate()
        try? modelContext.save()
        HapticManager.success()
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Color.bobAccent.opacity(0.1)).frame(width: 100, height: 100)
                Image(systemName: "arrow.repeat").font(.system(size: 40, weight: .light)).foregroundStyle(Color.bobAccent)
            }
            VStack(spacing: 8) {
                Text("No recurring transactions").font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.bobInk)
                Text("Track subscriptions, rent, salary,\nand any repeating transaction")
                    .font(.bobBody).foregroundStyle(Color.bobInk2).multilineTextAlignment(.center)
            }
            Button { showAddRecurring = true } label: {
                HStack(spacing: 8) { Image(systemName: "plus"); Text("Add Recurring") }
                    .font(.bobBodyMed).foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14).background(Color.bobAccent).clipShape(Capsule())
            }
            Spacer()
        }.padding()
    }
}

// MARK: – Recurring card

struct RecurringCard: View {
    @Environment(\.modelContext) private var modelContext
    let recurring: RecurringTransaction
    let currencyCode: String
    var isInactive: Bool = false

    private var kindColor: Color {
        isInactive ? Color.bobInk3 : (recurring.kind == .income ? Color.bobAccent : Color.bobDebit)
    }

    private var daysUntilDue: Int {
        Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: recurring.nextDueDate)).day ?? 0
    }

    private var dueBadge: (label: String, color: Color)? {
        guard !isInactive else { return nil }
        if daysUntilDue <= 0 { return ("Overdue", Color.bobDebit) }
        if daysUntilDue == 1 { return ("Tomorrow", Color.bobHex(0xF59E0B)) }
        if daysUntilDue <= 7 { return ("In \(daysUntilDue)d", Color.bobInk3) }
        return nil
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(kindColor.opacity(0.12)).frame(width: 46, height: 46)
                Image(systemName: recurring.kind == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 20)).foregroundStyle(kindColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(recurring.name).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isInactive ? Color.bobInk3 : Color.bobInk)
                HStack(spacing: 6) {
                    Text("\(frequencyLabel) · \(formattedNextDue)").font(.system(size: 12)).foregroundStyle(Color.bobInk3)
                    if let badge = dueBadge {
                        Text(badge.label).font(.system(size: 10, weight: .semibold)).foregroundStyle(badge.color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(badge.color.opacity(0.12)))
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(prefixedAmount).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(kindColor)
                Text(isInactive ? "Paused" : monthlyCostLabel).font(.system(size: 10)).foregroundStyle(Color.bobInk3)
            }
            Button {
                recurring.isActive.toggle()
                try? modelContext.save()
                HapticManager.light()
            } label: {
                Image(systemName: recurring.isActive ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(recurring.isActive ? Color.bobInk3 : Color.bobAccent)
            }
            .buttonStyle(.plain).padding(.leading, 4)
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.bobHairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var frequencyLabel: String {
        switch recurring.frequency {
        case .weekly: return "Weekly"; case .biweekly: return "Biweekly"
        case .monthly: return "Monthly"; case .yearly: return "Yearly"
        }
    }

    private var formattedNextDue: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: recurring.nextDueDate)
    }

    private var prefixedAmount: String {
        let formatted = CurrencyFormatter.string(recurring.amount, code: currencyCode)
        return recurring.kind == .income ? "+\(formatted)" : formatted
    }

    private var monthlyCostLabel: String {
        switch recurring.frequency {
        case .weekly:   return "≈ \(CurrencyFormatter.compact(recurring.amount * 4, code: currencyCode))/mo"
        case .biweekly: return "≈ \(CurrencyFormatter.compact(recurring.amount * 2, code: currencyCode))/mo"
        case .monthly:  return "\(CurrencyFormatter.compact(recurring.amount, code: currencyCode))/mo"
        case .yearly:   return "≈ \(CurrencyFormatter.compact(recurring.amount / 12, code: currencyCode))/mo"
        }
    }
}

#Preview {
    RecurringTransactionsView()
        .modelContainer(for: [RecurringTransaction.self, BudgetSettings.self], inMemory: true)
}
