import SwiftUI
import SwiftData
import UIKit

struct AddTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ExpenseCategory.sortOrder) private var allCategories: [ExpenseCategory]
    @Query(sort: \QuickAddTemplate.sortOrder) private var quickTemplates: [QuickAddTemplate]
    @Query private var statsList: [UserStats]
    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse)]) private var allExpenses: [Expense]
    @Query private var goals: [Goal]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]

    let currencyCode: String
    let expenseToEdit: Expense?
    var onAchievementsUnlocked: (([String]) -> Void)? = nil

    @State private var kind: TransactionKind = .expense
    @State private var amount: Decimal = .zero
    @State private var selectedCategory: ExpenseCategory?
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var merchant: String = ""
    @State private var showDatePicker = false
    @FocusState private var noteFieldFocused: Bool
    @FocusState private var merchantFieldFocused: Bool

    var isEditing: Bool { expenseToEdit != nil }
    var canSave: Bool { amount > 0 }

    private var visibleCategories: [ExpenseCategory] { allCategories.filter { $0.kind == kind } }
    private var filteredTemplates: [QuickAddTemplate] { quickTemplates.filter { $0.kind == kind } }
    private var accentColor: Color { kind == .income ? Color.bobGreen : Color.bobAccent }
    private var saveLabel: String {
        if isEditing { return "Save Changes" }
        return kind == .income ? "Add Income" : "Add Expense"
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            kindToggle.padding(.horizontal, Spacing.pageMargin).padding(.top, Spacing.s)
            amountDisplay.padding(.horizontal, Spacing.pageMargin).padding(.top, Spacing.m)

            if !filteredTemplates.isEmpty {
                templatesRow.padding(.top, Spacing.s)
            }

            categoryGrid.padding(.top, Spacing.m)
            detailsSection.padding(.horizontal, Spacing.pageMargin).padding(.top, Spacing.m)

            saveButton.padding(.horizontal, Spacing.pageMargin).padding(.top, Spacing.s)
            HairlineDivider().padding(.top, Spacing.s)
            CurrencyKeypad(amount: $amount).background(Color.bobBackground)
        }
        .background(Color.bobBackground.ignoresSafeArea())
        .onAppear(perform: hydrate)
        .onChange(of: kind) { _, _ in
            if selectedCategory?.kind != kind { selectedCategory = visibleCategories.first }
        }
    }

    // MARK: – Drag handle

    private var dragHandle: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.bobSurface3)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button("Cancel") { dismiss() }
                .font(.system(size: 15))
                .foregroundStyle(Color.bobInk2)
                .padding(.top, 8).padding(.trailing, Spacing.pageMargin)
        }
        .padding(.bottom, Spacing.xs)
    }

    // MARK: – Kind toggle

    private var kindToggle: some View {
        HStack(spacing: 0) {
            ForEach(TransactionKind.allCases) { option in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.2)) { kind = option }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option == .income ? "arrow.down.left" : "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(option.label).font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(kind == option ? .white : Color.bobInk2)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Capsule().fill(kind == option
                        ? (option == .income ? Color.bobGreen : Color.bobAccent)
                        : Color.clear))
                }.buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.bobSurface))
        .overlay(Capsule().stroke(Color.bobHairline, lineWidth: 1))
    }

    // MARK: – Amount display

    private var amountDisplay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kind == .income ? "Amount received" : "Amount spent").eyebrow()
            BigAmountView(
                amount: amount, currencyCode: currencyCode, size: 48,
                tint: amount > 0 ? accentColor : Color.bobInk2
            )
        }
    }

    // MARK: – Quick templates

    private var templatesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filteredTemplates) { t in
                    Button { applyTemplate(t) } label: {
                        HStack(spacing: 4) {
                            Text(t.name).font(.system(size: 12, weight: .medium))
                            Text(CurrencyFormatter.string(t.amount, code: currencyCode))
                                .font(.system(size: 11)).foregroundStyle(Color.bobInk2)
                        }
                        .foregroundStyle(Color.bobInk)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.bobSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.bobHairline, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, Spacing.pageMargin)
        }
    }

    private func applyTemplate(_ t: QuickAddTemplate) {
        amount = t.amount; selectedCategory = t.category; HapticManager.light()
    }

    // MARK: – Category grid

    private var categoryGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)
        return LazyVGrid(columns: cols, spacing: 0) {
            ForEach(visibleCategories, id: \.id) { cat in
                categoryCell(cat)
            }
        }
        .padding(.horizontal, Spacing.pageMargin)
    }

    private func categoryCell(_ cat: ExpenseCategory) -> some View {
        let isSelected = selectedCategory?.id == cat.id
        return Button {
            selectedCategory = cat
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isSelected ? accentColor : Color.bobSurface)
                        .frame(width: 48, height: 48)
                    Circle()
                        .stroke(isSelected ? accentColor : Color.bobHairline, lineWidth: 1)
                        .frame(width: 48, height: 48)
                    Image(systemName: cat.sfSymbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Color.bobInk2)
                }
                Text(cat.name)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? accentColor : Color.bobInk2)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: selectedCategory?.id)
    }

    // MARK: – Details section (always visible, no expanding)

    private var detailsSection: some View {
        VStack(spacing: 0) {
            // Date row — compact date picker (no layout shift)
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 15)).foregroundStyle(Color.bobInk2).frame(width: 20)
                Text("Date").font(.system(size: 14)).foregroundStyle(Color.bobInk2)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(accentColor)
                    .colorScheme(.dark)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 13)

            Divider().background(Color.bobHairline).padding(.leading, 52)

            // Merchant / Source row
            HStack(spacing: 12) {
                Image(systemName: kind == .income ? "person.fill" : "storefront")
                    .font(.system(size: 15)).foregroundStyle(Color.bobInk2).frame(width: 20)
                TextField(kind == .income ? "Source (optional)" : "Merchant (optional)", text: $merchant)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bobInk)
                    .focused($merchantFieldFocused)
                    .submitLabel(.next)
                    .onSubmit { noteFieldFocused = true }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 13)

            Divider().background(Color.bobHairline).padding(.leading, 52)

            // Note row
            HStack(spacing: 12) {
                Image(systemName: "pencil")
                    .font(.system(size: 15)).foregroundStyle(Color.bobInk2).frame(width: 20)
                TextField("Add a note (optional)", text: $note)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bobInk)
                    .focused($noteFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { noteFieldFocused = false }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 13)
        }
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bobHairline, lineWidth: 1))
    }

    // MARK: – Save button

    private var saveButton: some View {
        Button { save() } label: {
            Text(saveLabel)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canSave ? .white : Color.bobInk2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? accentColor : Color.bobSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(canSave ? Color.clear : Color.bobHairline, lineWidth: 1))
        }
        .disabled(!canSave)
        .animation(.easeOut(duration: 0.15), value: canSave)
    }

    // MARK: – Helpers

    private func hydrate() {
        guard let expense = expenseToEdit else {
            selectedCategory = visibleCategories.first; return
        }
        kind = expense.kind
        amount = expense.amount
        date = expense.date
        note = expense.note ?? ""
        merchant = expense.merchant ?? ""
        selectedCategory = expense.category
    }

    private func save() {
        guard canSave else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let trimNote     = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let isNewTransaction = expenseToEdit == nil

        if let expense = expenseToEdit {
            expense.amount = amount; expense.date = date
            expense.note = trimNote.isEmpty ? nil : trimNote
            expense.merchant = trimMerchant.isEmpty ? nil : trimMerchant
            expense.category = selectedCategory; expense.kind = kind
        } else {
            modelContext.insert(Expense(
                amount: amount, date: date,
                note: trimNote.isEmpty ? nil : trimNote,
                merchant: trimMerchant.isEmpty ? nil : trimMerchant,
                category: selectedCategory, kind: kind
            ))
        }
        try? modelContext.save()

        if isNewTransaction, let stats = statsList.first {
            let svc = GamificationService.shared
            svc.updateStreak(stats: stats)
            let unlocked = svc.checkAchievements(
                stats: stats,
                allExpenses: allExpenses,
                goals: goals,
                budget: settingsList.first
            )
            try? modelContext.save()
            if !unlocked.isEmpty { onAchievementsUnlocked?(unlocked) }
        }

        dismiss()
    }
}
