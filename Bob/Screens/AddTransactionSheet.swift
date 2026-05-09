import SwiftUI
import SwiftData
import UIKit

struct AddTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ExpenseCategory.sortOrder) private var allCategories: [ExpenseCategory]
    @Query(sort: \QuickAddTemplate.sortOrder) private var quickTemplates: [QuickAddTemplate]

    let currencyCode: String
    let expenseToEdit: Expense?

    @State private var kind: TransactionKind = .expense
    @State private var amount: Decimal = .zero
    @State private var selectedCategory: ExpenseCategory?
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var merchant: String = ""
    @State private var showDatePicker = false
    @State private var showNoteField = false
    @State private var showMerchantField = false

    var isEditing: Bool { expenseToEdit != nil }
    var canSave: Bool { amount > 0 }

    private var visibleCategories: [ExpenseCategory] { allCategories.filter { $0.kind == kind } }
    private var filteredTemplates: [QuickAddTemplate] { quickTemplates.filter { $0.kind == kind } }

    private var accentColor: Color { kind == .income ? .bobAccent : .bobDebit }
    private var accentLabel: String { kind == .income ? "Add Income" : "Add Expense" }

    // MARK: – Body

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            kindToggle.padding(.horizontal, Spacing.pageMargin).padding(.top, Spacing.s)
            amountSection.padding(.horizontal, Spacing.pageMargin).padding(.top, Spacing.m)
            categoryGrid.padding(.top, Spacing.m)

            if !filteredTemplates.isEmpty {
                templatesRow.padding(.top, Spacing.xs)
            }

            fieldsRow.padding(.horizontal, Spacing.pageMargin).padding(.top, Spacing.s)

            Spacer(minLength: 0)

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
                .fill(Color.bobHairline)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
            if isEditing {
                Text("Edit transaction")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button("Cancel") { dismiss() }
                .font(.system(size: 15))
                .foregroundStyle(Color.bobInk2)
                .padding(.top, 8)
                .padding(.trailing, Spacing.pageMargin)
        }
        .padding(.bottom, isEditing ? 4 : 0)
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
                        Text(option.label)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(kind == option ? .white : Color.bobInk2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(
                            kind == option
                                ? (option == .income ? Color.bobAccent : Color.bobDebit)
                                : Color.clear
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.bobSurface))
        .overlay(Capsule().stroke(Color.bobHairline, lineWidth: 1))
    }

    // MARK: – Amount display

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kind == .income ? "Amount received" : "Amount spent")
                .eyebrow()
            BigAmountView(
                amount: amount,
                currencyCode: currencyCode,
                size: 52,
                tint: amount > 0 ? accentColor : Color.bobInk2
            )
        }
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
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? accentColor : Color.bobSurface)
                        .frame(width: 50, height: 50)
                    Circle()
                        .stroke(isSelected ? accentColor : Color.bobHairline, lineWidth: 1)
                        .frame(width: 50, height: 50)
                    Image(systemName: cat.sfSymbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Color.bobInk2)
                }
                Text(cat.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? accentColor : Color.bobInk2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? accentColor.opacity(0.08) : Color.clear)
                    .padding(4)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selectedCategory?.id)
    }

    // MARK: – Quick templates

    private var templatesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filteredTemplates) { t in
                    Button { applyTemplate(t) } label: {
                        HStack(spacing: 4) {
                            Text(t.name)
                                .font(.system(size: 12, weight: .medium))
                            Text(CurrencyFormatter.string(t.amount, code: currencyCode))
                                .font(.system(size: 11))
                                .foregroundStyle(Color.bobInk2)
                        }
                        .foregroundStyle(Color.bobInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.bobSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.bobHairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.pageMargin)
        }
    }

    private func applyTemplate(_ t: QuickAddTemplate) {
        amount = t.amount
        selectedCategory = t.category
        HapticManager.light()
    }

    // MARK: – Fields row

    private var fieldsRow: some View {
        VStack(spacing: 0) {
            // Date chip + optional date picker
            HStack(spacing: Spacing.s) {
                fieldChip(icon: "calendar", label: dateLabel) {
                    withAnimation(.easeInOut(duration: 0.2)) { showDatePicker.toggle() }
                }

                fieldChip(icon: "pencil", label: note.isEmpty ? "Note" : note) {
                    showNoteField.toggle()
                }

                fieldChip(
                    icon: kind == .income ? "person.fill" : "storefront",
                    label: merchant.isEmpty ? (kind == .income ? "Source" : "Merchant") : merchant
                ) {
                    showMerchantField.toggle()
                }
            }

            if showDatePicker {
                DatePicker("", selection: $date, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .tint(accentColor)
                    .padding(.top, 4)
            }

            if showNoteField {
                TextField("Add a note…", text: $note)
                    .font(.bobBody)
                    .foregroundStyle(Color.bobInk)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(Color.bobSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.bobHairline, lineWidth: 1))
                    .padding(.top, 8)
                    .submitLabel(.done)
                    .onSubmit { showNoteField = false }
            }

            if showMerchantField {
                TextField(kind == .income ? "Source…" : "Merchant…", text: $merchant)
                    .font(.bobBody)
                    .foregroundStyle(Color.bobInk)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(Color.bobSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.bobHairline, lineWidth: 1))
                    .padding(.top, 8)
                    .submitLabel(.done)
                    .onSubmit { showMerchantField = false }
            }
        }
    }

    private func fieldChip(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.bobInk2)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.bobSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.bobHairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: – Save button

    private var saveButton: some View {
        Button { save() } label: {
            Text(isEditing ? "Save changes" : accentLabel)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canSave ? .white : Color.bobInk3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? accentColor : Color.bobSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(canSave ? Color.clear : Color.bobHairline, lineWidth: 1)
                )
        }
        .disabled(!canSave)
        .animation(.easeOut(duration: 0.15), value: canSave)
        .animation(.easeOut(duration: 0.15), value: kind)
    }

    // MARK: – Helpers

    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private func hydrate() {
        if let expense = expenseToEdit {
            kind      = expense.kind
            amount    = expense.amount
            date      = expense.date
            note      = expense.note ?? ""
            merchant  = expense.merchant ?? ""
            selectedCategory = expense.category
            if !note.isEmpty     { showNoteField = true }
            if !merchant.isEmpty { showMerchantField = true }
        } else {
            selectedCategory = visibleCategories.first
        }
    }

    private func save() {
        guard canSave else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let trimNote     = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)

        if let expense = expenseToEdit {
            expense.amount   = amount
            expense.date     = date
            expense.note     = trimNote.isEmpty ? nil : trimNote
            expense.merchant = trimMerchant.isEmpty ? nil : trimMerchant
            expense.category = selectedCategory
            expense.kind     = kind
        } else {
            modelContext.insert(Expense(
                amount:   amount,
                date:     date,
                note:     trimNote.isEmpty ? nil : trimNote,
                merchant: trimMerchant.isEmpty ? nil : trimMerchant,
                category: selectedCategory,
                kind:     kind
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}
