import SwiftUI
import SwiftData

// MARK: – Add Recurring Sheet
// Structured "setup" design: name + amount together, frequency is the visual centerpiece.
// Feels like configuring a subscription, not quick-adding a purchase.
// Keypad floats over content as an overlay — nothing shifts.

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
    @State private var isKeypadVisible = true
    @State private var selectedIconSymbol = "arrow.up.circle"
    @State private var showIconPicker = false
    @State private var showSavePreview = false
    @FocusState private var nameFieldFocused: Bool

    var isEditing: Bool { recurringToEdit != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0 }

    private var accentColor: Color { kind == .income ? Color.bobGreen : Color.bobAccent }
    private var visibleCategories: [ExpenseCategory] { allCategories.filter { $0.kind == kindAsTransaction } }
    private var kindAsTransaction: TransactionKind { kind == .income ? .income : .expense }
    private var iconOptions: [String] {
        kind == .income
        ? ["arrow.down.circle","dollarsign.circle","banknote","briefcase","gift","building.columns","creditcard","star","chart.line.uptrend.xyaxis","wallet.pass","person.crop.circle","circle.dashed"]
        : ["arrow.up.circle","cart","fork.knife","car","house","bolt","fuelpump","cross.case","bag","airplane","gamecontroller","doc.text","wrench.adjustable","pawprint","scissors","circle.dashed"]
    }
    private var frequencyDisplayString: String {
        switch frequency {
        case .weekly:   return "week"
        case .biweekly: return "2 weeks"
        case .monthly:  return "month"
        case .yearly:   return "year"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bobBackground.ignoresSafeArea()

            // Subtle tinted atmosphere at top — differentiates from AddTransaction sheet
            LinearGradient(
                colors: [accentColor.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.45)
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.3), value: kind)

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        kindToggle
                            .padding(.top, 6)

                        summaryCard
                        frequencySection
                        categorySection
                        dateSection
                    }
                    .padding(.horizontal, 20)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: isKeypadVisible ? 300 : 20)
                }

                saveBar
            }

            if isKeypadVisible {
                keypadFloat
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: isKeypadVisible)
        .animation(.easeOut(duration: 0.25), value: kind)
        .onAppear(perform: hydrate)
        .onChange(of: kind) { _, _ in
            if selectedCategory?.kind != kindAsTransaction { selectedCategory = visibleCategories.first }
        }
        .onChange(of: nameFieldFocused) { _, focused in
            if focused {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                    isKeypadVisible = false
                }
            }
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerSheet(
                title: "Choose icon",
                symbols: iconOptions,
                selectedSymbol: $selectedIconSymbol
            )
        }
        .confirmationDialog(
            isEditing ? "Confirm changes" : "Confirm recurring",
            isPresented: $showSavePreview,
            titleVisibility: .visible
        ) {
            Button(isEditing ? "Save now" : "Add now") { performSave() }
            Button("Back", role: .cancel) { }
        } message: {
            Text(savePreviewText)
        }
    }

    // MARK: – Top bar

    private var topBar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.bobHairline)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.bobInk2)
                }
                    .padding(.trailing, 20)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    // MARK: – Kind toggle

    private var kindToggle: some View {
        HStack(spacing: 0) {
            ForEach([RecurringKind.expense, .income], id: \.self) { option in
                Button {
                    HapticManager.light()
                    withAnimation(.easeOut(duration: 0.2)) { kind = option }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option == .income ? "arrow.down.left" : "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(option == .income ? "Income" : "Expense")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(kind == option ? .white : Color.bobInk2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(
                        kind == option
                            ? (option == .income ? Color.bobGreen : Color.bobAccent)
                            : Color.clear
                    ))
                }.buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.bobSurface))
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: – Summary card (name + amount together)

    private var summaryCard: some View {
        VStack(spacing: 0) {
            // Name field row
            HStack(spacing: 12) {
                Button {
                    showIconPicker = true
                } label: {
                    Image(systemName: selectedIconSymbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(accentColor)
                        .frame(width: 28)
                }
                .buttonStyle(.plain)
                .animation(.easeOut(duration: 0.2), value: kind)

                TextField(
                    kind == .income ? "e.g. Salary, Rent income" : "e.g. Netflix, Rent, Gym",
                    text: $name
                )
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.bobInk)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .onSubmit { nameFieldFocused = false }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Amount row — tap to open keypad
            Button {
                nameFieldFocused = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                    isKeypadVisible = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(amount > 0 ? accentColor : Color.bobInk3)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        if amount > 0 {
                            Text("per \(frequencyDisplayString)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isKeypadVisible ? accentColor.opacity(0.8) : Color.bobInk3)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .transition(.opacity)
                        }
                        BigAmountView(
                            amount: amount,
                            currencyCode: currencyCode,
                            size: 32,
                            tint: amount > 0 ? accentColor : Color.bobInk3
                        )
                    }

                    Spacer()

                    if !isKeypadVisible {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(accentColor.opacity(0.7))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .animation(.easeOut(duration: 0.2), value: isKeypadVisible)
            .animation(.easeOut(duration: 0.2), value: amount > 0)
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.bobSurface.opacity(0.7))
                .overlay {
                    // Glass sheen at top
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.07), Color.clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.4)
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: – Frequency section (visual centrepiece)

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Repeats")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
                    .textCase(.uppercase)
                    .tracking(0.7)
                Spacer()
                // Live preview of selected frequency
                Text(frequencyPreviewText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accentColor)
            }
            .padding(.horizontal, 2)

            // 2×2 grid of frequency options
            let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(
                    [RecurringFrequency.weekly, .biweekly, .monthly, .yearly],
                    id: \.self
                ) { freq in
                    frequencyTile(freq)
                }
            }
        }
    }

    private var frequencyPreviewText: String {
        guard amount > 0 else { return "" }
        let amtStr = CurrencyFormatter.string(amount, code: currencyCode)
        switch frequency {
        case .weekly:   return "\(amtStr) / week"
        case .biweekly: return "\(amtStr) / 2 weeks"
        case .monthly:  return "\(amtStr) / month"
        case .yearly:   return "\(amtStr) / year"
        }
    }

    private func frequencyTile(_ freq: RecurringFrequency) -> some View {
        let isSelected = frequency == freq
        return Button {
            HapticManager.light()
            withAnimation(.easeOut(duration: 0.18)) { frequency = freq }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: frequencyIcon(freq))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? .white : Color.bobInk2)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(frequencyLabel(freq))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Color.bobInk)
                    Text(frequencySub(freq))
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.bobInk3)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? accentColor : Color.bobSurface.opacity(0.7))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.1), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }

    private func frequencyIcon(_ freq: RecurringFrequency) -> String {
        switch freq {
        case .weekly:   return "7.circle"
        case .biweekly: return "14.circle"
        case .monthly:  return "calendar.circle"
        case .yearly:   return "calendar.badge.clock"
        }
    }

    // MARK: – Category section

    private var categorySection: some View {
        Group {
            if !visibleCategories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Category")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.bobInk2)
                        .textCase(.uppercase)
                        .tracking(0.7)
                        .padding(.horizontal, 2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(visibleCategories, id: \.id) { cat in
                                categoryChip(cat)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, -20)
                }
            }
        }
    }

    private func categoryChip(_ cat: ExpenseCategory) -> some View {
        let isSelected = selectedCategory?.id == cat.id
        return Button {
            selectedCategory = cat
            HapticManager.light()
        } label: {
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                        .frame(width: 28, height: 28)
                    Image(systemName: cat.sfSymbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Color.bobInk2)
                }
                Text(cat.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : Color.bobInk2)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(isSelected ? accentColor : Color.bobSurface.opacity(0.8))
                    .overlay {
                        Capsule()
                            .stroke(
                                isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.14), value: isSelected)
    }

    // MARK: – Date section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start Date")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .textCase(.uppercase)
                .tracking(0.7)
                .padding(.horizontal, 2)

            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accentColor)
                    .frame(width: 28)
                Text("First payment on")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bobInk2)
                Spacer()
                DatePicker("", selection: $startDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(accentColor)
                    .colorScheme(.dark)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.bobSurface.opacity(0.7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
            }
        }
    }

    // MARK: – Save bar

    private var saveBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            Button { showSavePreview = true } label: {
                HStack(spacing: 8) {
                    if canSave && amount > 0 {
                        Text(isEditing ? "Save Changes" : (kind == .income ? "Add Income" : "Add Expense"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text(isEditing ? "Save Changes" : (kind == .income ? "Add Income" : "Add Expense"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.bobInk2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? accentColor : Color.bobSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        canSave ? Color.clear : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
                )
            }
            .disabled(!canSave)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .animation(.easeOut(duration: 0.15), value: canSave)
            .animation(.easeOut(duration: 0.15), value: kind)
        }
        .background(Color.bobBackground)
    }

    // MARK: – Keypad float overlay

    private var keypadFloat: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "repeat")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(accentColor)
                        Text("Recurring \(kind == .income ? "income" : "expense")")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.bobInk3)
                            .textCase(.uppercase)
                            .tracking(0.7)
                    }
                    BigAmountView(
                        amount: amount,
                        currencyCode: currencyCode,
                        size: 26,
                        tint: amount > 0 ? accentColor : Color.bobInk3
                    )
                }
                Spacer()
                Button {
                    HapticManager.light()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                        isKeypadVisible = false
                    }
                } label: {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 13)
            .background {
                LinearGradient(
                    colors: [accentColor.opacity(0.06), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            Rectangle()
                .fill(Color.white.opacity(0.09))
                .frame(height: 1)

            CurrencyKeypad(amount: $amount)
        }
        .background {
            ZStack {
                Color(red: 0.09, green: 0.09, blue: 0.09)
                LinearGradient(
                    colors: [accentColor.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.3)
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.25), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.6), radius: 40, y: -6)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: – Helpers

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
        isKeypadVisible = recurringToEdit == nil
        guard let r = recurringToEdit else {
            selectedCategory = visibleCategories.first
            selectedIconSymbol = kind == .income ? "arrow.down.circle" : "arrow.up.circle"
            return
        }
        name = r.name
        amount = r.amount
        kind = r.kind
        frequency = r.frequency
        startDate = r.startDate
        selectedCategory = r.category
        selectedIconSymbol = r.iconSymbol ?? r.category?.sfSymbol ?? (r.kind == .income ? "arrow.down.circle" : "arrow.up.circle")
    }

    private var savePreviewText: String {
        let trimName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let amountText = CurrencyFormatter.string(amount, code: currencyCode)
        let dateText = DateFormatter.localizedString(from: startDate, dateStyle: .medium, timeStyle: .none)
        return "\(kind == .income ? "Recurring income" : "Recurring expense"): \(trimName)\nAmount: \(amountText) / \(frequencyDisplayString)\nStart date: \(dateText)"
    }

    private func save() {
        showSavePreview = true
    }

    private func performSave() {
        guard canSave else { return }
        HapticManager.success()
        let trimName = name.trimmingCharacters(in: .whitespaces)

        if let existing = recurringToEdit {
            existing.name = trimName
            existing.amount = amount
            existing.kind = kind
            existing.frequency = frequency
            existing.startDate = startDate
            existing.nextDueDate = RecurringTransaction.calculateNextDueDate(from: startDate, frequency: frequency)
            existing.iconSymbol = selectedIconSymbol
            existing.category = selectedCategory
        } else {
            modelContext.insert(RecurringTransaction(
                name: trimName,
                amount: amount,
                kind: kind,
                frequency: frequency,
                startDate: startDate,
                iconSymbol: selectedIconSymbol,
                category: selectedCategory
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}
