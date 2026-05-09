import SwiftUI
import SwiftData

struct RecurringTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringTransaction.nextDueDate) private var recurrings: [RecurringTransaction]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]

    @State private var selectedTab: RecurTab = .upcoming
    @State private var showAddRecurring = false
    @State private var editingRecurring: RecurringTransaction?
    @State private var deletingRecurring: RecurringTransaction?
    @State private var showCalendar = false

    @AppStorage("paydayViewEnabled") private var paydayViewEnabled = false
    @AppStorage("currentCashBalance") private var currentCashBalance: Double = 0

    enum RecurTab { case upcoming, analytics }

    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }
    private var activeRecurrings: [RecurringTransaction] { recurrings.filter { $0.isActive } }
    private var inactiveRecurrings: [RecurringTransaction] { recurrings.filter { !$0.isActive } }

    private func monthlyEquivalent(_ r: RecurringTransaction) -> Decimal {
        switch r.frequency {
        case .weekly: return r.amount * 4
        case .biweekly: return r.amount * 2
        case .monthly: return r.amount
        case .yearly: return r.amount / 12
        }
    }

    // Items due in next 7 days
    private var dueSoon: [RecurringTransaction] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return recurrings.filter { $0.isActive && $0.nextDueDate <= cutoff }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    // Items due next 8–30 days
    private var dueLater: [RecurringTransaction] {
        let start = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let end   = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return recurrings.filter { $0.isActive && $0.nextDueDate > start && $0.nextDueDate <= end }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    private var dueSoonTotal: Decimal { dueSoon.reduce(0) { $0 + $1.amount } }

    // MARK: – Body

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                tabPicker
                    .padding(.top, 4)
                Divider().background(Color.bobHairline)

                if recurrings.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        if selectedTab == .upcoming {
                            upcomingContent
                        } else {
                            RecurringAnalyticsView(
                                recurrings: recurrings,
                                currencyCode: currencyCode
                            )
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCalendar) {
            RecurringCalendarView(recurrings: recurrings, currencyCode: currencyCode)
        }
        .sheet(isPresented: $showAddRecurring) { AddRecurringSheet(currencyCode: currencyCode) }
        .sheet(item: $editingRecurring) { r in AddRecurringSheet(currencyCode: currencyCode, recurringToEdit: r) }
        .alert("Delete Recurring", isPresented: .init(
            get: { deletingRecurring != nil },
            set: { if !$0 { deletingRecurring = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingRecurring = nil }
            Button("Delete", role: .destructive) {
                if let r = deletingRecurring { modelContext.delete(r); try? modelContext.save() }
                deletingRecurring = nil
            }
        } message: { Text("This won't delete past transactions created from this rule.") }
    }

    // MARK: – Top bar

    private var topBar: some View {
        HStack {
            Button { } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.bobInk2)
                    .frame(width: 36, height: 36)
            }.buttonStyle(.plain)

            Spacer()
            Text("Recurring").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.bobInk)
            Spacer()

            Button { showAddRecurring = true } label: {
                ZStack {
                    Circle().stroke(Color.bobInk2, lineWidth: 1.5).frame(width: 30, height: 30)
                    Image(systemName: "plus").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bobInk)
                }
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.pageMargin)
        .padding(.vertical, 14)
    }

    // MARK: – Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton("Upcoming", tab: .upcoming)
            tabButton("Analytics", tab: .analytics)
        }
    }

    private func tabButton(_ label: String, tab: RecurTab) -> some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { selectedTab = tab } } label: {
            VStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? Color.bobInk : Color.bobInk2)
                Rectangle()
                    .fill(selectedTab == tab ? Color.bobInk : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.pageMargin)
        }
        .buttonStyle(.plain)
    }

    // MARK: – Upcoming content

    private var upcomingContent: some View {
        VStack(spacing: Spacing.m) {
            comingUpCard
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.top, Spacing.m)

            paydayViewCard
                .padding(.horizontal, Spacing.pageMargin)

            if !dueSoon.isEmpty {
                dueSoonSection
            }
            if !dueLater.isEmpty {
                dueLaterSection
            }

            Spacer().frame(height: 100)
        }
    }

    // MARK: – "Coming up" card with mini calendar

    private var comingUpCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Coming up")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.bobInk)
                    if dueSoon.isEmpty {
                        Text("No recurring charges in the next 7 days.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.bobInk2)
                    } else {
                        Text("You have \(dueSoon.count) recurring charge\(dueSoon.count == 1 ? "" : "s") for \(CurrencyFormatter.string(dueSoonTotal, code: currencyCode)) in the next 7 days.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.bobInk2)
                    }
                }
                Spacer()
                Button { showCalendar = true } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bobInk2)
                }.buttonStyle(.plain)
            }

            miniCalendar
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: – Mini calendar

    private var miniCalendar: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Find the Sunday of the current week
        let weekday = cal.component(.weekday, from: today) // 1=Sun
        let startOfWeek = cal.date(byAdding: .day, value: -(weekday - 1), to: today)!
        let days: [Date] = (0..<14).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
        let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        // Map of due dates → recurring items
        var dueDates: [Date: [RecurringTransaction]] = [:]
        for r in activeRecurrings {
            let d = cal.startOfDay(for: r.nextDueDate)
            dueDates[d, default: []].append(r)
        }

        return VStack(spacing: 6) {
            // Day headers
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.bobInk2)
                        .frame(maxWidth: .infinity)
                }
            }

            // Two rows of 7 days
            VStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = days[row * 7 + col]
                            let isToday = cal.isDateInToday(day)
                            let items = dueDates[day] ?? []
                            let hasIncome = items.contains { $0.kind == .income }
                            let hasExpense = items.contains { $0.kind == .expense }

                            ZStack(alignment: .bottom) {
                                // Day circle
                                ZStack {
                                    if isToday {
                                        Circle()
                                            .fill(Color.bobChartBlue)
                                            .frame(width: 32, height: 32)
                                    }
                                    Text("\(cal.component(.day, from: day))")
                                        .font(.system(size: 14, weight: isToday ? .bold : .regular))
                                        .foregroundStyle(isToday ? .white : Color.bobInk)
                                }

                                // Indicator dot / icon for items due on this day
                                if !items.isEmpty {
                                    HStack(spacing: 2) {
                                        if hasIncome {
                                            Circle().fill(Color.bobAccent).frame(width: 5, height: 5)
                                        }
                                        if hasExpense {
                                            Circle().fill(Color.bobDebit).frame(width: 5, height: 5)
                                        }
                                    }
                                    .offset(y: 18)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                        }
                    }
                }
            }
        }
        .padding(Spacing.s)
        .background(Color.bobSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: – Payday View card

    private var billsBeforeNextPayday: Decimal {
        // Sum of expense recurrings due before the next income recurring
        guard let nextIncome = activeRecurrings.filter({ $0.kind == .income })
            .sorted(by: { $0.nextDueDate < $1.nextDueDate }).first else {
            return dueSoon.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
        }
        return activeRecurrings.filter {
            $0.kind == .expense && $0.nextDueDate <= nextIncome.nextDueDate
        }.reduce(0) { $0 + $1.amount }
    }

    private var safeToSpend: Decimal {
        Decimal(currentCashBalance) - billsBeforeNextPayday
    }

    private var paydayViewCard: some View {
        VStack(spacing: 0) {
            // Toggle row
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Payday View")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.bobInk)
                    Text("See what is safe to spend based on\nwhen your next income comes.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bobInk2)
                }
                Spacer()
                Toggle("", isOn: $paydayViewEnabled)
                    .labelsHidden()
                    .tint(Color.bobAccent)
            }
            .padding(Spacing.m)

            if paydayViewEnabled {
                Divider().background(Color.bobHairline)

                // Current Cash row
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().stroke(Color.bobInk2, lineWidth: 1.5).frame(width: 28, height: 28)
                            Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.bobInk2)
                        }
                        Text("Current Cash").font(.system(size: 16, weight: .medium)).foregroundStyle(Color.bobInk)
                        Spacer()
                        TextField("0", value: $currentCashBalance, format: .currency(code: currencyCode))
                            .font(.system(size: 16, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(Color.bobInk)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                        Image(systemName: "chevron.down").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                    }
                    .padding(Spacing.m)

                    Divider().background(Color.bobHairline)

                    // Bills Before Payday
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().stroke(Color.bobInk2, lineWidth: 1.5).frame(width: 28, height: 28)
                            Image(systemName: "minus").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.bobInk2)
                        }
                        Text("Bills Before Payday").font(.system(size: 16, weight: .medium)).foregroundStyle(Color.bobInk)
                        Spacer()
                        Text(CurrencyFormatter.string(billsBeforeNextPayday, code: currencyCode))
                            .font(.system(size: 16, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk)
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
                    }
                    .padding(Spacing.m)

                    Divider().background(Color.bobHairline)

                    // Safe To Spend
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.bobAccent.opacity(0.2)).frame(width: 28, height: 28)
                            Image(systemName: "equal").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.bobAccent)
                        }
                        Text("Safe To Spend").font(.system(size: 16, weight: .medium)).foregroundStyle(Color.bobInk)
                        Spacer()
                        Text(CurrencyFormatter.string(safeToSpend, code: currencyCode))
                            .font(.system(size: 16, weight: .bold)).monospacedDigit()
                            .foregroundStyle(safeToSpend >= 0 ? Color.bobInk : Color.bobDebit)
                        Button { } label: {
                            ZStack {
                                Circle().stroke(Color.bobInk2, lineWidth: 1).frame(width: 22, height: 22)
                                Text("i").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bobInk2)
                            }
                        }.buttonStyle(.plain)
                    }
                    .padding(Spacing.m)
                }
            }
        }
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: – Due soon section

    private var dueSoonSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("DUE SOON")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .tracking(0.8)
                .padding(.horizontal, Spacing.pageMargin)

            VStack(spacing: Spacing.s) {
                ForEach(dueSoon) { r in recurringRow(r) }
            }
            .padding(.horizontal, Spacing.pageMargin)
        }
    }

    // MARK: – Due later section

    private var dueLaterSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("COMING UP")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .tracking(0.8)
                .padding(.horizontal, Spacing.pageMargin)

            VStack(spacing: Spacing.s) {
                ForEach(dueLater) { r in recurringRow(r) }
            }
            .padding(.horizontal, Spacing.pageMargin)
        }
    }

    // MARK: – Recurring row

    private func recurringRow(_ r: RecurringTransaction) -> some View {
        let isIncome = r.kind == .income
        let color: Color = isIncome ? Color.bobAccent : Color.bobDebit
        let cal = Calendar.current
        let daysUntil = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
            to: cal.startOfDay(for: r.nextDueDate)).day ?? 0
        let subtitle = daysUntil <= 0 ? "Due today" : "in \(daysUntil) day\(daysUntil == 1 ? "" : "s")"

        return HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: isIncome ? "dollarsign" : (r.category?.sfSymbol ?? "arrow.up"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(r.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(daysUntil <= 0 ? Color.bobDebit : Color.bobInk2)
            }

            Spacer()

            Text((isIncome ? "+" : "") + CurrencyFormatter.string(r.amount, code: currencyCode))
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isIncome ? Color.bobAccent : Color.bobInk)

            Menu {
                Button { editingRecurring = r } label: { Label("Edit", systemImage: "pencil") }
                Button {
                    r.isActive.toggle(); try? modelContext.save(); HapticManager.light()
                } label: {
                    Label(r.isActive ? "Pause" : "Resume", systemImage: r.isActive ? "pause.circle" : "play.circle")
                }
                Divider()
                Button(role: .destructive) { deletingRecurring = r } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: – All tab content

    private var allContent: some View {
        VStack(spacing: Spacing.m) {
            // Summary strip
            HStack(spacing: 0) {
                summaryCell(label: "Monthly out",
                            value: CurrencyFormatter.compact(
                                activeRecurrings.filter { $0.kind == .expense }.reduce(0) { $0 + monthlyEquivalent($1) },
                                code: currencyCode),
                            color: Color.bobDebit)
                Divider().frame(height: 36).background(Color.bobHairline)
                summaryCell(label: "Monthly in",
                            value: CurrencyFormatter.compact(
                                activeRecurrings.filter { $0.kind == .income }.reduce(0) { $0 + monthlyEquivalent($1) },
                                code: currencyCode),
                            color: Color.bobAccent)
                Divider().frame(height: 36).background(Color.bobHairline)
                let ann = (activeRecurrings.filter { $0.kind == .income }.reduce(Decimal(0)) { $0 + monthlyEquivalent($1) }
                         - activeRecurrings.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + monthlyEquivalent($1) }) * 12
                summaryCell(label: "Annual net",
                            value: (ann >= 0 ? "+" : "") + CurrencyFormatter.compact(ann, code: currencyCode),
                            color: ann >= 0 ? Color.bobAccent : Color.bobDebit)
            }
            .padding(.vertical, 12)
            .background(Color.bobSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.top, Spacing.m)

            if !activeRecurrings.isEmpty {
                sectionBlock("ACTIVE — \(activeRecurrings.count)", items: activeRecurrings)
            }
            if !inactiveRecurrings.isEmpty {
                sectionBlock("PAUSED — \(inactiveRecurrings.count)", items: inactiveRecurrings)
            }

            Spacer().frame(height: 100)
        }
    }

    private func sectionBlock(_ title: String, items: [RecurringTransaction]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .tracking(0.8)
                .padding(.horizontal, Spacing.pageMargin)
            VStack(spacing: Spacing.s) {
                ForEach(items) { r in recurringRow(r) }
            }
            .padding(.horizontal, Spacing.pageMargin)
        }
    }

    private func summaryCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.bobInk2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Color.bobSurface).frame(width: 100, height: 100)
                Image(systemName: "arrow.clockwise").font(.system(size: 40, weight: .light)).foregroundStyle(Color.bobInk2)
            }
            VStack(spacing: 8) {
                Text("No recurring transactions").font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.bobInk)
                Text("Track subscriptions, rent, salary,\nand any repeating transaction")
                    .font(.bobBody).foregroundStyle(Color.bobInk2).multilineTextAlignment(.center)
            }
            Button { showAddRecurring = true } label: {
                HStack(spacing: 8) { Image(systemName: "plus"); Text("Add Recurring") }
                    .font(.bobBodyMed).foregroundStyle(.black)
                    .padding(.horizontal, 28).padding(.vertical, 14).background(Color.bobAccent).clipShape(Capsule())
            }
            Spacer()
        }.padding()
    }
}

#Preview {
    RecurringTransactionsView()
        .modelContainer(for: [RecurringTransaction.self, BudgetSettings.self], inMemory: true)
}
