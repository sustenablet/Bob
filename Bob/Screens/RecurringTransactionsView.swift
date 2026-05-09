import SwiftUI
import SwiftData

struct RecurringTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringTransaction.nextDueDate) private var recurrings: [RecurringTransaction]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]

    @State private var showAddRecurring   = false
    @State private var editingRecurring: RecurringTransaction?
    @State private var deletingRecurring: RecurringTransaction?

    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }
    private var activeRecurrings:   [RecurringTransaction] { recurrings.filter { $0.isActive } }
    private var inactiveRecurrings: [RecurringTransaction] { recurrings.filter { !$0.isActive } }

    // Monthly cost / income at a glance
    private var monthlyNetLabel: String {
        let income  = recurrings.filter { $0.isActive && $0.kind == .income  }.reduce(Decimal(0)) { $0 + monthlyEquivalent($1) }
        let expense = recurrings.filter { $0.isActive && $0.kind == .expense }.reduce(Decimal(0)) { $0 + monthlyEquivalent($1) }
        let net = income - expense
        let formatted = CurrencyFormatter.string(abs(net as NSDecimalNumber as Decimal), code: currencyCode)
        return net >= 0 ? "+\(formatted)/mo" : "-\(formatted)/mo"
    }

    private func monthlyEquivalent(_ r: RecurringTransaction) -> Decimal {
        switch r.frequency {
        case .weekly:    return r.amount * 4
        case .biweekly:  return r.amount * 2
        case .monthly:   return r.amount
        case .yearly:    return r.amount / 12
        }
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
                            // Summary strip
                            summaryStrip

                            if !activeRecurrings.isEmpty {
                                sectionHeader("Active — \(activeRecurrings.count)")
                                ForEach(activeRecurrings) { r in
                                    RecurringCard(recurring: r, currencyCode: currencyCode)
                                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .onTapGesture { editingRecurring = r }
                                        .contextMenu { contextMenuItems(for: r) }
                                }
                            }

                            if !inactiveRecurrings.isEmpty {
                                sectionHeader("Paused — \(inactiveRecurrings.count)")
                                ForEach(inactiveRecurrings) { r in
                                    RecurringCard(recurring: r, currencyCode: currencyCode, isInactive: true)
                                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .onTapGesture { editingRecurring = r }
                                        .contextMenu { contextMenuItems(for: r) }
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.pageMargin)
                        .padding(.top, Spacing.m)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Recurring")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddRecurring = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.bobInk)
                    }
                }
            }
            .sheet(isPresented: $showAddRecurring) {
                AddRecurringSheet(currencyCode: currencyCode)
            }
            .sheet(item: $editingRecurring) { r in
                AddRecurringSheet(currencyCode: currencyCode, recurringToEdit: r)
            }
            .alert("Delete Recurring", isPresented: .init(
                get: { deletingRecurring != nil },
                set: { if !$0 { deletingRecurring = nil } }
            )) {
                Button("Cancel", role: .cancel) { deletingRecurring = nil }
                Button("Delete", role: .destructive) {
                    if let r = deletingRecurring { modelContext.delete(r); try? modelContext.save() }
                    deletingRecurring = nil
                }
            } message: {
                Text("This won't delete past transactions already created from this rule.")
            }
        }
    }

    // MARK: – Summary strip

    private var monthlyOut: Decimal {
        recurrings.filter { $0.isActive && $0.kind == .expense }.reduce(Decimal(0)) { $0 + monthlyEquivalent($1) }
    }
    private var monthlyIn: Decimal {
        recurrings.filter { $0.isActive && $0.kind == .income }.reduce(Decimal(0)) { $0 + monthlyEquivalent($1) }
    }
    private var annualNet: Decimal { (monthlyIn - monthlyOut) * 12 }

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            summaryCell(
                label: "Monthly out",
                value: CurrencyFormatter.compact(monthlyOut, code: currencyCode),
                color: .bobDebit
            )
            Divider().frame(height: 36)
            summaryCell(
                label: "Monthly in",
                value: CurrencyFormatter.compact(monthlyIn, code: currencyCode),
                color: .bobAccent
            )
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
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.bobInk2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Section header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: – Context menu

    @ViewBuilder
    private func contextMenuItems(for r: RecurringTransaction) -> some View {
        Button {
            editingRecurring = r
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            withAnimation {
                r.isActive.toggle()
                try? modelContext.save()
            }
        } label: {
            Label(r.isActive ? "Pause" : "Resume",
                  systemImage: r.isActive ? "pause.circle" : "play.circle")
        }

        Divider()

        Button(role: .destructive) {
            deletingRecurring = r
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: – Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Color.bobAccent.opacity(0.1)).frame(width: 100, height: 100)
                Image(systemName: "arrow.repeat")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.bobAccent)
            }
            VStack(spacing: 8) {
                Text("No recurring transactions")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                Text("Track subscriptions, rent, salary,\nand any repeating transaction")
                    .font(.bobBody)
                    .foregroundStyle(Color.bobInk2)
                    .multilineTextAlignment(.center)
            }
            Button {
                showAddRecurring = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Recurring")
                }
                .font(.bobBodyMed)
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.bobAccent)
                .clipShape(Capsule())
            }
            Spacer()
        }
        .padding()
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
            to: Calendar.current.startOfDay(for: recurring.nextDueDate)
        ).day ?? 0
    }

    private var dueBadge: (label: String, color: Color)? {
        guard !isInactive else { return nil }
        if daysUntilDue <= 0 { return ("Due today", Color.bobDebit) }
        if daysUntilDue == 1 { return ("Tomorrow", Color.bobHex(0xF59E0B)) }
        if daysUntilDue <= 7 { return ("In \(daysUntilDue)d", Color.bobInk3) }
        return nil
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(kindColor.opacity(0.12)).frame(width: 46, height: 46)
                Image(systemName: recurring.kind == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(kindColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(recurring.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isInactive ? Color.bobInk3 : Color.bobInk)

                HStack(spacing: 6) {
                    Text("\(frequencyLabel) · \(formattedNextDue)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bobInk3)

                    if let badge = dueBadge {
                        Text(badge.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(badge.color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(badge.color.opacity(0.12)))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(prefixedAmount)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(kindColor)
                Text(isInactive ? "Paused" : monthlyCostLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.bobInk3)
            }

            // Visible pause/resume button
            Button {
                recurring.isActive.toggle()
                try? modelContext.save()
                HapticManager.light()
            } label: {
                Image(systemName: recurring.isActive ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(recurring.isActive ? Color.bobInk3 : Color.bobAccent)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.bobHairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var frequencyLabel: String {
        switch recurring.frequency {
        case .weekly:   return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly:  return "Monthly"
        case .yearly:   return "Yearly"
        }
    }

    private var formattedNextDue: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: recurring.nextDueDate)
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
