import SwiftUI
import SwiftData
import UIKit

struct AddRecurringSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let currencyCode: String
    var recurringToEdit: RecurringTransaction?

    @Query(sort: \ExpenseCategory.sortOrder) private var allCategories: [ExpenseCategory]

    @State private var name: String = ""
    @State private var amount: Decimal = .zero
    @State private var kind: RecurringKind = .expense
    @State private var frequency: RecurringFrequency = .monthly
    @State private var startDate: Date = Date()
    @State private var selectedCategory: ExpenseCategory?
    @State private var showDatePicker = false

    var isEditing: Bool { recurringToEdit != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0 }

    private var accentColor: Color { kind == .income ? .bobAccent : .bobDebit }
    private var visibleCategories: [ExpenseCategory] { allCategories.filter { $0.kind == kindAsTransaction } }
    private var kindAsTransaction: TransactionKind { kind == .income ? .income : .expense }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            dragHandle

            // Scrollable content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    kindToggle
                        .padding(.top, Spacing.m)

                    // Amount display
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind == .income ? "Amount received" : "Amount paid").eyebrow()
                        BigAmountView(
                            amount: amount,
                            currencyCode: currencyCode,
                            size: 48,
                            tint: amount > 0 ? accentColor : Color.bobInk2
                        )
                    }

                    // Name
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Name").eyebrow()
                        TextField("e.g. Rent, Netflix, Salary", text: $name)
                            .font(.bobBody)
                            .foregroundStyle(Color.bobInk)
                            .padding(Spacing.m)
                            .background(Color.bobSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bobHairline, lineWidth: 1))
                            .submitLabel(.done)
                    }

                    // Frequency
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text("Repeats").eyebrow()
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                            ForEach([RecurringFrequency.weekly, .biweekly, .monthly, .yearly], id: \.self) { freq in
                                Button { withAnimation { frequency = freq } } label: {
                                    VStack(spacing: 2) {
                                        Text(frequencyLabel(freq))
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(frequencySub(freq))
                                            .font(.system(size: 11))
                                            .opacity(0.7)
                                    }
                                    .foregroundStyle(frequency == freq ? .white : Color.bobInk2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(frequency == freq ? accentColor : Color.bobSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                                        frequency == freq ? Color.clear : Color.bobHairline, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Category
                    if !visibleCategories.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Category").eyebrow()
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.xs) {
                                    ForEach(visibleCategories, id: \.id) { cat in
                                        CategoryChip(
                                            category: cat,
                                            isSelected: selectedCategory?.id == cat.id
                                        ) { selectedCategory = cat }
                                    }
                                }
                            }
                        }
                    }

                    // Start date
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Start Date").eyebrow()
                        Button {
                            withAnimation { showDatePicker.toggle() }
                        } label: {
                            HStack {
                                Text(formattedDate)
                                    .font(.bobBody).foregroundStyle(Color.bobInk)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.bobInk3)
                                    .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                            }
                            .padding(Spacing.m)
                            .background(Color.bobSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bobHairline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        if showDatePicker {
                            DatePicker("", selection: $startDate, displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .tint(accentColor)
                        }
                    }

                    Spacer(minLength: Spacing.s)
                }
                .padding(.horizontal, Spacing.pageMargin)
            }

            // Save button
            VStack(spacing: 0) {
                HairlineDivider()
                Button { save() } label: {
                    Text(isEditing ? "Save Changes" : (kind == .income ? "Add Income" : "Add Expense"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(canSave ? .white : Color.bobInk3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSave ? accentColor : Color.bobSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(canSave ? Color.clear : Color.bobHairline, lineWidth: 1))
                }
                .disabled(!canSave)
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.vertical, Spacing.s)
                .animation(.easeOut(duration: 0.15), value: canSave)
                .animation(.easeOut(duration: 0.15), value: kind)
            }

            HairlineDivider()
            CurrencyKeypad(amount: $amount).background(Color.bobBackground)
        }
        .background(Color.bobBackground.ignoresSafeArea())
        .onAppear(perform: hydrate)
        .onChange(of: kind) { _, _ in
            if selectedCategory?.kind != kindAsTransaction { selectedCategory = visibleCategories.first }
        }
    }

    // MARK: – Drag handle + cancel

    private var dragHandle: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.bobHairline)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button("Cancel") { dismiss() }
                .font(.system(size: 15))
                .foregroundStyle(Color.bobInk2)
                .padding(.top, 8)
                .padding(.trailing, Spacing.pageMargin)
        }
        .padding(.bottom, Spacing.xs)
    }

    // MARK: – Kind toggle

    private var kindToggle: some View {
        HStack(spacing: 0) {
            ForEach([RecurringKind.expense, .income], id: \.self) { option in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.2)) { kind = option }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option == .income ? "arrow.down.left" : "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(option == .income ? "Income" : "Expense")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(kind == option ? .white : Color.bobInk2)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Capsule().fill(
                        kind == option ? (option == .income ? Color.bobAccent : Color.bobDebit) : Color.clear
                    ))
                }.buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.bobSurface))
        .overlay(Capsule().stroke(Color.bobHairline, lineWidth: 1))
    }

    // MARK: – Helpers

    private var formattedDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(startDate) { return "Today" }
        if cal.isDateInYesterday(startDate) { return "Yesterday" }
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: startDate)
    }

    private func frequencyLabel(_ freq: RecurringFrequency) -> String {
        switch freq {
        case .weekly:   return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly:  return "Monthly"
        case .yearly:   return "Yearly"
        }
    }

    private func frequencySub(_ freq: RecurringFrequency) -> String {
        switch freq {
        case .weekly:   return "Every 7 days"
        case .biweekly: return "Every 14 days"
        case .monthly:  return "Once a month"
        case .yearly:   return "Once a year"
        }
    }

    private func hydrate() {
        guard let r = recurringToEdit else {
            selectedCategory = visibleCategories.first
            return
        }
        name = r.name
        amount = r.amount
        kind = r.kind
        frequency = r.frequency
        startDate = r.startDate
        selectedCategory = r.category
    }

    private func save() {
        guard canSave else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let trimName = name.trimmingCharacters(in: .whitespaces)

        if let existing = recurringToEdit {
            existing.name = trimName
            existing.amount = amount
            existing.kind = kind
            existing.frequency = frequency
            existing.startDate = startDate
            existing.nextDueDate = RecurringTransaction.calculateNextDueDate(from: startDate, frequency: frequency)
            existing.category = selectedCategory
        } else {
            modelContext.insert(RecurringTransaction(
                name: trimName, amount: amount, kind: kind,
                frequency: frequency, startDate: startDate, category: selectedCategory
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}
