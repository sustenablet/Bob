import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var goals: [Goal]
    @Query private var recurrings: [RecurringTransaction]
    @Query(sort: \QuickAddTemplate.sortOrder) private var quickTemplates: [QuickAddTemplate]

    @AppStorage("showOnboarding")    var showOnboarding    = true
    @AppStorage("userName")          var userName          = ""
    @AppStorage("dailyReminder")     var dailyReminder     = false
    @AppStorage("budgetAlerts")      var budgetAlerts      = true

    @State private var showBudgetEditor   = false
    @State private var showNewCategory    = false
    @State private var showDeleteConfirm  = false
    @State private var newCatName         = ""
    @State private var newCatSymbol       = "circle.dashed"
    @State private var newCatKind: TransactionKind = .expense

    private var settings: BudgetSettings? { settingsList.first }
    private var currencyCode: String { settings?.currencyCode ?? "USD" }

    // MARK: – Body

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.l) {
                    profileCard
                    generalGroup
                    notificationsGroup
                    manageGroup
                    dataGroup
                    aboutGroup
                    dangerZone
                }
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.top, Spacing.m)
                .padding(.bottom, 60)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.bobBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .sheet(isPresented: $showBudgetEditor) {
            BudgetEditorSheet(
                currencyCode: currencyCode,
                initialAmount: settings?.monthlyBudget ?? 0
            ) { newAmount in
                settings?.monthlyBudget = newAmount
                try? modelContext.save()
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showNewCategory) {
            NewCategorySheet(
                name: $newCatName,
                symbol: $newCatSymbol,
                kind: $newCatKind,
                onSave: addCategory
            )
            .presentationDetents([.medium, .large])
        }
        .alert("Delete All Data", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) { deleteAllData() }
        } message: {
            Text("This will permanently delete all your transactions, goals, recurring items, and templates. This cannot be undone.")
        }
        .onChange(of: dailyReminder) { _, enabled in
            enabled ? scheduleDailyReminder() : removeDailyReminder()
        }
    }

    // MARK: – Profile card

    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.bobInk)
                    .frame(width: 56, height: 56)
                Text(userName.trimmingCharacters(in: .whitespaces).prefix(1).uppercased().isEmpty
                     ? "?" : String(userName.trimmingCharacters(in: .whitespaces).prefix(1).uppercased()))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("Your name", text: $userName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                    .submitLabel(.done)

                Text(greetingPreview)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bobInk2)
            }

            Spacer()
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.bobHairline, lineWidth: 1))
    }

    private var greetingPreview: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let time = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        let name = userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "How your greeting will appear" : "\(time), \(name)"
    }

    // MARK: – General group

    private var generalGroup: some View {
        settingsGroup("General") {
            navRow(icon: "dollarsign.circle.fill", color: Color.bobHex(0x34A853),
                   title: "Monthly Budget",
                   value: settings?.monthlyBudget ?? 0 > 0
                       ? CurrencyFormatter.string(settings!.monthlyBudget, code: currencyCode)
                       : "Not set") {
                showBudgetEditor = true
            }

            rowDivider

            currencyRow
        }
    }

    private var currencyRow: some View {
        Menu {
            ForEach(supportedCurrencies, id: \.self) { code in
                Button(currencyDisplayName(code)) {
                    settings?.currencyCode = code
                    try? modelContext.save()
                }
            }
        } label: {
            HStack(spacing: 14) {
                iconBox("coloncurrencysign", color: Color.bobHex(0x1A73E8))
                Text("Currency").font(.bobBody).foregroundStyle(Color.bobInk)
                Spacer()
                Text(currencyCode).font(.system(size: 14)).foregroundStyle(Color.bobInk2)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }

    // MARK: – Notifications group

    private var notificationsGroup: some View {
        settingsGroup("Notifications") {
            toggleRow(icon: "bell.badge.fill", color: Color.bobHex(0xFF6B35),
                      title: "Budget Alerts",
                      subtitle: "Warns at 80% and 100% spend",
                      isOn: $budgetAlerts)

            rowDivider

            toggleRow(icon: "moon.fill", color: Color.bobHex(0x7C4DFF),
                      title: "Daily Reminder",
                      subtitle: "Reminds you to log at 9 PM",
                      isOn: $dailyReminder)
        }
    }

    // MARK: – Manage group

    private var manageGroup: some View {
        settingsGroup("Manage") {
            NavigationLink {
                CategoriesView()
            } label: {
                navRowLabel(icon: "tag.fill", color: Color.bobHex(0x0F9D58),
                            title: "Categories",
                            value: "\(categories.count)")
            }
            .buttonStyle(.plain)

            rowDivider

            NavigationLink {
                TemplatesView()
            } label: {
                navRowLabel(icon: "bolt.fill", color: Color.bobHex(0xF4B400),
                            title: "Quick Templates",
                            value: "\(quickTemplates.count)")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: – Data group

    private var dataGroup: some View {
        settingsGroup("Data") {
            navRow(icon: "square.and.arrow.up.fill", color: Color.bobHex(0x1A73E8),
                   title: "Export Transactions") {
                exportData(type: .transactions)
            }

            rowDivider

            navRow(icon: "square.and.arrow.up.fill", color: Color.bobHex(0x34A853),
                   title: "Export Goals") {
                exportData(type: .goals)
            }

            rowDivider

            navRow(icon: "square.and.arrow.up.fill", color: Color.bobHex(0x7C4DFF),
                   title: "Export Recurring") {
                exportData(type: .recurring)
            }
        }
    }

    // MARK: – About group

    private var aboutGroup: some View {
        settingsGroup("About") {
            HStack(spacing: 14) {
                iconBox("info.circle.fill", color: Color.bobHex(0x9E9E9E))
                Text("Version").font(.bobBody).foregroundStyle(Color.bobInk)
                Spacer()
                Text(appVersion).font(.system(size: 14)).foregroundStyle(Color.bobInk2)
            }
            .padding(.vertical, 12)

            rowDivider

            navRow(icon: "arrow.counterclockwise", color: Color.bobInk2,
                   title: "Replay Onboarding") {
                showOnboarding = true
            }
        }
    }

    // MARK: – Danger zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Danger Zone").eyebrow().padding(.horizontal, 4)

            Button {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 14) {
                    iconBox("trash.fill", color: Color.bobDebit)
                    Text("Delete All Data")
                        .font(.bobBody)
                        .foregroundStyle(Color.bobDebit)
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, Spacing.m)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.bobSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.bobDebit.opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: – Row builders

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).eyebrow().padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, Spacing.m)
            .background(Color.bobSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.bobHairline, lineWidth: 1))
        }
    }

    private func navRow(icon: String, color: Color, title: String, value: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            navRowLabel(icon: icon, color: color, title: title, value: value)
        }
        .buttonStyle(.plain)
    }

    private func navRowLabel(icon: String, color: Color, title: String, value: String? = nil) -> some View {
        HStack(spacing: 14) {
            iconBox(icon, color: color)
            Text(title).font(.bobBody).foregroundStyle(Color.bobInk)
            Spacer()
            if let v = value {
                Text(v).font(.system(size: 14)).foregroundStyle(Color.bobInk2)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func toggleRow(icon: String, color: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            iconBox(icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bobBody).foregroundStyle(Color.bobInk)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Color.bobInk2)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Color.bobAccent)
        }
        .padding(.vertical, 10)
    }

    private func iconBox(_ icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color).frame(width: 32, height: 32)
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
        }
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 46)
    }

    // MARK: – Helpers

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private let supportedCurrencies = ["USD", "EUR", "GBP", "BRL", "CAD", "AUD", "JPY", "CHF", "CNY", "INR"]

    private func currencyDisplayName(_ code: String) -> String {
        let name = Locale(identifier: "en_US").localizedString(forCurrencyCode: code) ?? code
        return "\(code) — \(name)"
    }

    private func addCategory() {
        let name = newCatName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let sameKind = categories.filter { $0.kind == newCatKind }
        let nextOrder = (sameKind.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(ExpenseCategory(name: name, sfSymbol: newCatSymbol, sortOrder: nextOrder, kind: newCatKind))
        try? modelContext.save()
        showNewCategory = false
    }

    private func deleteAllData() {
        try? modelContext.delete(model: Expense.self)
        try? modelContext.delete(model: Goal.self)
        try? modelContext.delete(model: GoalContribution.self)
        try? modelContext.delete(model: RecurringTransaction.self)
        try? modelContext.delete(model: QuickAddTemplate.self)
        try? modelContext.save()
    }

    // MARK: – Export

    private enum ExportType { case transactions, goals, recurring }

    private func exportData(type: ExportType) {
        let csv: String
        let filename: String
        switch type {
        case .transactions:
            csv = DataExporter.exportExpensesToCSV(expenses, currencyCode: currencyCode); filename = "transactions.csv"
        case .goals:
            csv = DataExporter.exportGoalsToCSV(goals, currencyCode: currencyCode); filename = "goals.csv"
        case .recurring:
            csv = DataExporter.exportRecurringToCSV(recurrings, currencyCode: currencyCode); filename = "recurring.csv"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        root.present(UIActivityViewController(activityItems: [url], applicationActivities: nil), animated: true)
    }

    // MARK: – Notifications

    private func scheduleDailyReminder() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                DispatchQueue.main.async { dailyReminder = false }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Time to log your spending 📊"
            content.body = "Keep your finances up to date — it only takes a minute."
            content.sound = .default
            var comps = DateComponents(); comps.hour = 21; comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "bob.daily.reminder", content: content, trigger: trigger)
            )
        }
    }

    private func removeDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["bob.daily.reminder"])
    }
}

// MARK: – Categories sub-page

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var selectedKind: TransactionKind = .expense
    @State private var showNewCategory = false
    @State private var newCatName = ""
    @State private var newCatSymbol = "circle.dashed"
    @State private var newCatKind: TransactionKind = .expense

    private var filtered: [ExpenseCategory] { categories.filter { $0.kind == selectedKind } }

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                kindPicker.padding(Spacing.pageMargin)
                List {
                    ForEach(filtered, id: \.id) { cat in categoryRow(cat) }
                        .onDelete(perform: delete)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.bobBackground)
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bobBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newCatName = ""; newCatSymbol = selectedKind == .income ? "dollarsign.circle" : "circle.dashed"
                    newCatKind = selectedKind; showNewCategory = true
                } label: { Image(systemName: "plus").foregroundStyle(Color.bobInk) }
            }
        }
        .sheet(isPresented: $showNewCategory) {
            NewCategorySheet(name: $newCatName, symbol: $newCatSymbol, kind: $newCatKind, onSave: addCategory)
                .presentationDetents([.medium, .large])
        }
    }

    private var kindPicker: some View {
        HStack(spacing: 0) {
            ForEach(TransactionKind.allCases) { kind in
                Button { withAnimation { selectedKind = kind } } label: {
                    Text(kind == .expense ? "Expenses" : "Income")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedKind == kind ? .white : Color.bobInk2)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Capsule().fill(selectedKind == kind ? Color.bobInk : Color.clear))
                }.buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.bobSurface))
        .overlay(Capsule().stroke(Color.bobHairline, lineWidth: 1))
    }

    private func categoryRow(_ cat: ExpenseCategory) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cat.kind == .income ? Color.bobAccent : Color.bobInk.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: cat.sfSymbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(cat.kind == .income ? .white : Color.bobInk2)
            }
            Text(cat.name).font(.system(size: 15)).foregroundStyle(Color.bobInk)
            Spacer()
            let count = cat.expenses?.count ?? 0
            Text(count > 0 ? "\(count) uses" : "Unused")
                .font(.system(size: 12)).foregroundStyle(Color.bobInk2)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.bobSurface)
        .listRowSeparatorTint(Color.bobHairline)
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets {
            let cat = filtered[i]
            if (cat.expenses?.count ?? 0) == 0 { modelContext.delete(cat) }
        }
        try? modelContext.save()
    }

    private func addCategory() {
        let name = newCatName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let sameKind = categories.filter { $0.kind == newCatKind }
        let order = (sameKind.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(ExpenseCategory(name: name, sfSymbol: newCatSymbol, sortOrder: order, kind: newCatKind))
        try? modelContext.save()
        showNewCategory = false
    }
}

// MARK: – Templates sub-page

struct TemplatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuickAddTemplate.sortOrder) private var templates: [QuickAddTemplate]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]

    @State private var showNew = false
    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()
            if templates.isEmpty { emptyState } else {
                List {
                    ForEach(templates, id: \.id) { templateRow($0) }
                        .onDelete(perform: delete)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.bobBackground)
            }
        }
        .navigationTitle("Quick Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bobBackground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNew = true } label: { Image(systemName: "plus").foregroundStyle(Color.bobInk) }
            }
        }
        .sheet(isPresented: $showNew) {
            NewQuickTemplateSheet(currencyCode: currencyCode, existingCount: templates.count)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bolt.circle").font(.system(size: 52)).foregroundStyle(Color.bobInk3)
            Text("No templates yet").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.bobInk)
            Text("Templates let you add frequent\ntransactions with one tap")
                .font(.bobBody).foregroundStyle(Color.bobInk2).multilineTextAlignment(.center)
            Button { showNew = true } label: {
                Text("Create Template").font(.bobBodyMed).foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.bobAccent).clipShape(Capsule())
            }
            Spacer()
        }
    }

    private func templateRow(_ t: QuickAddTemplate) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(t.kind == .income ? Color.bobAccent.opacity(0.12) : Color.bobDebit.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: t.category?.sfSymbol ?? (t.kind == .income ? "arrow.down.circle" : "arrow.up.circle"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(t.kind == .income ? Color.bobAccent : Color.bobDebit)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(t.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.bobInk)
                Text(t.kind == .income ? "Income" : "Expense").font(.system(size: 12)).foregroundStyle(Color.bobInk2)
            }
            Spacer()
            Text(CurrencyFormatter.string(t.amount, code: currencyCode))
                .font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Color.bobInk2)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.bobSurface)
        .listRowSeparatorTint(Color.bobHairline)
    }

    private func delete(at offsets: IndexSet) {
        offsets.forEach { modelContext.delete(templates[$0]) }
        try? modelContext.save()
    }
}

// MARK: – Budget editor sheet

private struct BudgetEditorSheet: View {
    let currencyCode: String; let initialAmount: Decimal; let onSave: (Decimal) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Decimal = .zero

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }.font(.bobBody).foregroundStyle(Color.bobInk2)
                Spacer()
                Text("Monthly Budget").font(.bobBodyMed)
                Spacer()
                Button("Save") { onSave(amount); dismiss() }
                    .font(.bobBodyMed)
                    .foregroundStyle(amount > 0 ? Color.bobAccent : Color.bobInk3)
                    .disabled(amount <= 0)
            }
            .padding(.horizontal, Spacing.pageMargin).padding(.vertical, Spacing.s)
            HairlineDivider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Budget").eyebrow()
                BigAmountView(amount: amount, currencyCode: currencyCode, size: 52)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.pageMargin).padding(.vertical, Spacing.l)
            Spacer()
            HairlineDivider()
            CurrencyKeypad(amount: $amount).background(Color.bobBackground)
        }
        .background(Color.bobBackground.ignoresSafeArea())
        .onAppear { amount = initialAmount }
    }
}

// MARK: – New quick template sheet

private struct NewQuickTemplateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExpenseCategory.sortOrder) private var allCategories: [ExpenseCategory]

    let currencyCode: String; let existingCount: Int

    @State private var name = ""; @State private var amount: Decimal = .zero
    @State private var kind: TransactionKind = .expense
    @State private var selectedCategory: ExpenseCategory?

    private var visibleCategories: [ExpenseCategory] { allCategories.filter { $0.kind == kind } }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }.font(.bobBody).foregroundStyle(Color.bobInk2)
                Spacer(); Text("New Template").font(.bobBodyMed); Spacer()
                Button("Add") { save() }.font(.bobBodyMed)
                    .foregroundStyle(canSave ? Color.bobAccent : Color.bobInk3).disabled(!canSave)
            }
            .padding(.horizontal, Spacing.pageMargin).padding(.vertical, Spacing.s)
            HairlineDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    kindToggle.padding(.top, Spacing.m)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Name").eyebrow()
                        TextField("e.g. Morning Coffee", text: $name).font(.bobBody).foregroundStyle(Color.bobInk)
                        HairlineDivider()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount").eyebrow()
                        BigAmountView(amount: amount, currencyCode: currencyCode, size: 48,
                                      tint: amount > 0 ? Color.bobAccent : Color.bobInk2)
                    }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Category").eyebrow()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.xs) {
                                ForEach(visibleCategories, id: \.id) { cat in
                                    CategoryChip(category: cat, isSelected: selectedCategory?.id == cat.id) { selectedCategory = cat }
                                }
                            }.padding(.bottom, 2)
                        }
                    }
                }.padding(.horizontal, Spacing.pageMargin)
            }
            HairlineDivider()
            CurrencyKeypad(amount: $amount).background(Color.bobBackground)
        }
        .background(Color.bobBackground.ignoresSafeArea())
        .onChange(of: kind) { _, _ in selectedCategory = visibleCategories.first }
        .onAppear { selectedCategory = visibleCategories.first }
    }

    private var kindToggle: some View {
        HStack(spacing: 0) {
            ForEach(TransactionKind.allCases) { option in
                Button { withAnimation(.easeOut(duration: 0.18)) { kind = option } } label: {
                    Text(option.label).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(kind == option ? Color.white : Color.bobInk2)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(Capsule().fill(kind == option ? (option == .income ? Color.bobAccent : Color.bobDebit) : Color.clear))
                }.buttonStyle(.plain)
            }
        }
        .padding(4).background(Capsule().fill(Color.bobSurface)).overlay(Capsule().stroke(Color.bobHairline, lineWidth: 1))
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces); guard !n.isEmpty, amount > 0 else { return }
        modelContext.insert(QuickAddTemplate(name: n, amount: amount, kind: kind, category: selectedCategory, sortOrder: existingCount))
        try? modelContext.save(); dismiss()
    }
}

// MARK: – New category sheet

private struct NewCategorySheet: View {
    @Binding var name: String; @Binding var symbol: String; @Binding var kind: TransactionKind
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var symbols: [String] {
        kind == .income
            ? ["dollarsign.circle","gift","arrow.uturn.backward","star","briefcase","banknote","creditcard","building.columns","chart.line.uptrend.xyaxis","circle.dashed"]
            : ["fork.knife","cart","car","bag","doc.text","music.note","heart","house","airplane","fuelpump","gift","pawprint","scissors","wrench.adjustable","circle.dashed"]
    }
    private var accentColor: Color { kind == .income ? .bobAccent : .bobDebit }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }.font(.bobBody).foregroundStyle(Color.bobInk2)
                Spacer(); Text("New Category").font(.bobBodyMed); Spacer()
                Button("Add") { onSave() }.font(.bobBodyMed)
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.bobInk3 : accentColor)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, Spacing.pageMargin).padding(.vertical, Spacing.s)
            HairlineDivider()
            VStack(alignment: .leading, spacing: Spacing.l) {
                kindToggle
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Name").eyebrow()
                    TextField("e.g. Subscriptions", text: $name).font(.bobBody).foregroundStyle(Color.bobInk)
                    HairlineDivider()
                }
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Icon").eyebrow()
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 5), spacing: Spacing.xs) {
                        ForEach(symbols, id: \.self) { sym in
                            Button { symbol = sym } label: {
                                Image(systemName: sym).font(.system(size: 18))
                                    .foregroundStyle(symbol == sym ? accentColor : Color.bobInk2)
                                    .frame(width: 48, height: 48)
                                    .background(RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                                        .fill(symbol == sym ? accentColor.opacity(0.12) : Color.clear))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                                        .stroke(Color.bobHairline, lineWidth: Hairline.width))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.pageMargin).padding(.top, Spacing.l)
            Spacer()
        }
        .background(Color.bobBackground.ignoresSafeArea())
    }

    private var kindToggle: some View {
        HStack(spacing: 0) {
            ForEach(TransactionKind.allCases) { option in
                Button { withAnimation(.easeOut(duration: 0.18)) { kind = option } } label: {
                    Text(option.label).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(kind == option ? Color.white : Color.bobInk2)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(Capsule().fill(kind == option ? (option == .income ? Color.bobAccent : Color.bobDebit) : Color.clear))
                }.buttonStyle(.plain)
            }
        }
        .padding(4).background(Capsule().fill(Color.bobSurface)).overlay(Capsule().stroke(Color.bobHairline, lineWidth: 1))
    }
}
