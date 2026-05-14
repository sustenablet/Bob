import SwiftUI
import SwiftData

// MARK: – Add Transaction Sheet
// Quick-capture design: amount is the hero, category is a swipeable strip,
// details tuck away. Keypad floats over content — nothing ever shifts.

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
    @State private var isKeypadVisible = true
    @State private var showDetails = false
    @State private var showIconPicker = false
    @State private var selectedIconSymbol = "arrow.up.circle"
    @State private var showSavePreview = false
    @FocusState private var noteFieldFocused: Bool
    @FocusState private var merchantFieldFocused: Bool

    var isEditing: Bool { expenseToEdit != nil }
    var canSave: Bool { amount > 0 }

    private var visibleCategories: [ExpenseCategory] { allCategories.filter { $0.kind == kind } }
    private var filteredTemplates: [QuickAddTemplate] { quickTemplates.filter { $0.kind == kind } }
    private var accentColor: Color { kind == .income ? Color.bobGreen : Color.bobAccent }
    private var iconOptions: [String] {
        kind == .income
        ? ["arrow.down.circle","dollarsign.circle","banknote","briefcase","gift","building.columns","creditcard","star","chart.line.uptrend.xyaxis","wallet.pass","person.crop.circle","circle.dashed"]
        : ["arrow.up.circle","cart","fork.knife","car","house","bolt","fuelpump","cross.case","bag","airplane","gamecontroller","doc.text","wrench.adjustable","pawprint","scissors","circle.dashed"]
    }
    private var saveLabel: String {
        if isEditing { return "Save Changes" }
        return kind == .income ? "Add Income" : "Add Expense"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bobBackground.ignoresSafeArea()

            // Accent glow behind amount area
            accentColor
                .opacity(0.06)
                .blur(radius: 60)
                .frame(height: 280)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        kindToggle
                            .padding(.top, 6)

                        amountHero

                        if !filteredTemplates.isEmpty {
                            templatesRow
                        }

                        categoryStrip
                        detailsCard
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
        .animation(.easeOut(duration: 0.2), value: kind)
        .onAppear(perform: hydrate)
        .onChange(of: kind) { _, _ in
            if selectedCategory?.kind != kind { selectedCategory = visibleCategories.first }
        }
        .onChange(of: merchantFieldFocused) { _, focused in
            if focused {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { isKeypadVisible = false }
            }
        }
        .onChange(of: noteFieldFocused) { _, focused in
            if focused {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { isKeypadVisible = false }
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
            isEditing ? "Confirm changes" : "Confirm transaction",
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
            ForEach(TransactionKind.allCases) { option in
                Button {
                    HapticManager.light()
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

    // MARK: – Amount hero

    private var amountHero: some View {
        Button {
            merchantFieldFocused = false
            noteFieldFocused = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                isKeypadVisible = true
            }
        } label: {
            VStack(spacing: 10) {
                Text(kind == .income ? "Amount received" : "Amount spent")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isKeypadVisible ? accentColor : Color.bobInk2)
                    .textCase(.uppercase)
                    .tracking(0.8)

                BigAmountView(
                    amount: amount,
                    currencyCode: currencyCode,
                    size: 54,
                    tint: amount > 0 ? accentColor : Color.bobInk3
                )

                if !isKeypadVisible {
                    Label("Tap to edit", systemImage: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(accentColor.opacity(0.7))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.bobSurface.opacity(0.55))
                    .overlay {
                        // Top glass sheen
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.06), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: isKeypadVisible
                                        ? [accentColor.opacity(0.55), accentColor.opacity(0.12)]
                                        : [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.22), value: isKeypadVisible)
        .animation(.easeOut(duration: 0.22), value: amount > 0)
    }

    // MARK: – Quick templates

    private var templatesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filteredTemplates) { t in
                    Button { applyTemplate(t) } label: {
                        HStack(spacing: 5) {
                            Text(t.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text(CurrencyFormatter.string(t.amount, code: currencyCode))
                                .font(.system(size: 11))
                                .foregroundStyle(Color.bobInk2)
                        }
                        .foregroundStyle(Color.bobInk)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Color.bobSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }

    private func applyTemplate(_ t: QuickAddTemplate) {
        amount = t.amount; selectedCategory = t.category; HapticManager.light()
    }

    // MARK: – Category strip

    private var categoryStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .textCase(.uppercase)
                .tracking(0.7)
                .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleCategories, id: \.id) { cat in
                        categoryPill(cat)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }

    private func categoryPill(_ cat: ExpenseCategory) -> some View {
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

    // MARK: – Details card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            // Toggle header
            Button {
                HapticManager.light()
                withAnimation(.easeOut(duration: 0.2)) { showDetails.toggle() }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bobInk2)
                    Text("Details")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bobInk2)
                    Spacer()
                    if !showDetails {
                        detailsPreview
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.bobInk3)
                        .rotationEffect(.degrees(showDetails ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if showDetails {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 0)

                // Date row
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bobInk2)
                        .frame(width: 22)
                    Text("Date")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bobInk2)
                    Spacer()
                    DatePicker("", selection: $date, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(accentColor)
                        .colorScheme(.dark)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.leading, 50)

                // Merchant / Source
                HStack(spacing: 12) {
                    Button {
                        showIconPicker = true
                    } label: {
                        Image(systemName: selectedIconSymbol)
                            .font(.system(size: 14))
                            .foregroundStyle(accentColor)
                            .frame(width: 22)
                    }
                    .buttonStyle(.plain)
                    TextField(
                        kind == .income ? "Source (optional)" : "Merchant (optional)",
                        text: $merchant
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bobInk)
                    .focused($merchantFieldFocused)
                    .submitLabel(.next)
                    .onSubmit { noteFieldFocused = true }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.leading, 50)

                // Note
                HStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bobInk2)
                        .frame(width: 22)
                    TextField("Note (optional)", text: $note)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bobInk)
                        .focused($noteFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { noteFieldFocused = false }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.bobSurface.opacity(0.7))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var detailsPreview: some View {
        HStack(spacing: 6) {
            if !merchant.isEmpty {
                Text(merchant)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bobInk2)
            }
            if !note.isEmpty {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bobInk3)
            }
            let cal = Calendar.current
            if !cal.isDateInToday(date) {
                Text(date, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bobInk3)
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
                Text(saveLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canSave ? .white : Color.bobInk2)
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
        }
        .background(Color.bobBackground)
    }

    // MARK: – Keypad float overlay

    private var keypadFloat: some View {
        VStack(spacing: 0) {
            // Handle + amount preview + done
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind == .income ? "Income" : "Expense")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.bobInk3)
                        .textCase(.uppercase)
                        .tracking(0.9)
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
                    colors: [Color.white.opacity(0.07), Color.clear],
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
                    colors: [Color.white.opacity(0.05), Color.clear],
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
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
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

    private func hydrate() {
        isKeypadVisible = expenseToEdit == nil
        guard let expense = expenseToEdit else {
            selectedCategory = visibleCategories.first
            selectedIconSymbol = kind == .income ? "arrow.down.circle" : "arrow.up.circle"
            return
        }
        kind = expense.kind
        amount = expense.amount
        date = expense.date
        note = expense.note ?? ""
        merchant = expense.merchant ?? ""
        selectedCategory = expense.category
        selectedIconSymbol = expense.iconSymbol ?? expense.category?.sfSymbol ?? (kind == .income ? "arrow.down.circle" : "arrow.up.circle")
        showDetails = !(note.isEmpty && merchant.isEmpty && Calendar.current.isDateInToday(date))
    }

    private var savePreviewText: String {
        let title = merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (selectedCategory?.name ?? (kind == .income ? "Income" : "Expense"))
            : merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteText = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let amountText = CurrencyFormatter.string(amount, code: currencyCode)
        let dateText = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        if noteText.isEmpty {
            return "\(kind == .income ? "Income" : "Expense"): \(title)\nAmount: \(amountText)\nDate: \(dateText)"
        }
        return "\(kind == .income ? "Income" : "Expense"): \(title)\nAmount: \(amountText)\nDate: \(dateText)\nNote: \(noteText)"
    }

    private func save() {
        showSavePreview = true
    }

    private func performSave() {
        guard canSave else { return }
        HapticManager.success()
        let trimNote     = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)

        if let expense = expenseToEdit {
            expense.amount = amount
            expense.date = date
            expense.note = trimNote.isEmpty ? nil : trimNote
            expense.merchant = trimMerchant.isEmpty ? nil : trimMerchant
            expense.iconSymbol = selectedIconSymbol
            expense.category = selectedCategory
            expense.kind = kind
        } else {
            modelContext.insert(Expense(
                amount: amount,
                date: date,
                note: trimNote.isEmpty ? nil : trimNote,
                merchant: trimMerchant.isEmpty ? nil : trimMerchant,
                iconSymbol: selectedIconSymbol,
                category: selectedCategory,
                kind: kind
            ))
        }
        try? modelContext.save()

        dismiss()
    }
}
