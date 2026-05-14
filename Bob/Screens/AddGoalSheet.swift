import SwiftUI
import SwiftData
import PhotosUI

struct AddGoalSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let currencyCode: String
    var goalToEdit: Goal?

    @State private var name: String = ""
    @State private var iconName: String = "target"
    @State private var photoData: Data?
    @State private var targetAmount: Decimal = .zero
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var isKeypadVisible = true
    @State private var showPhotoPicker = false
    @FocusState private var nameFieldFocused: Bool

    private let goalIcons = [
        "target", "house", "car", "airplane", "ring.circle",
        "graduationcap", "laptopcomputer", "iphone", "person.fill", "beach.umbrella",
        "guitars", "banknote", "cart", "bolt", "star",
        "dumbbell", "paintpalette", "dog", "leaf", "figure.surfing",
        "building.columns", "bed.double", "fork.knife", "heart", "camera.fill",
        "book.fill", "gamecontroller", "bicycle", "bag.fill", "crown.fill"
    ]

    var isEditing: Bool { goalToEdit != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && targetAmount > 0 }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bobBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        amountCard
                            .padding(.top, 6)

                        iconSection
                        nameSection
                        deadlineSection

                        if targetAmount > 0 {
                            monthlyHint
                        }

                        Color.clear.frame(height: 100)
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
        .onAppear {
            isKeypadVisible = goalToEdit == nil
            guard let goal = goalToEdit else { return }
            name = goal.name
            iconName = goal.iconName
            photoData = goal.photoData
            targetAmount = goal.targetAmount
            deadline = goal.deadline
        }
        .onChange(of: nameFieldFocused) { _, focused in
            if focused {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                    isKeypadVisible = false
                }
            }
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
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bobInk2)
                    .padding(.trailing, 20)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: – Amount card (tappable, opens keypad)

    private var amountCard: some View {
        Button {
            nameFieldFocused = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                isKeypadVisible = true
            }
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Target Amount")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.bobInk2)
                        .textCase(.uppercase)
                        .tracking(0.7)

                    BigAmountView(
                        amount: targetAmount,
                        currencyCode: currencyCode,
                        size: 42,
                        tint: targetAmount > 0 ? Color.bobAccent : Color.bobInk3
                    )
                }

                Spacer()

                if !isKeypadVisible {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.bobAccent.opacity(0.8))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.bobSurface.opacity(0.75))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: isKeypadVisible
                                        ? [Color.bobAccent.opacity(0.55), Color.bobAccent.opacity(0.15)]
                                        : [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isKeypadVisible)
    }

    // MARK: – Icon section

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Icon")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
                    .textCase(.uppercase)
                    .tracking(0.7)
                Spacer()
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 11, weight: .medium))
                        Text("Photo")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.bobAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.bobAccent.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 2)

            // Preview
            if let data = photoData, let uiImage = UIImage(data: data) {
                HStack {
                    Spacer()
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(goalIcons, id: \.self) { icon in
                        Button {
                            iconName = icon
                            photoData = nil
                            photoItem = nil
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(iconName == icon ? .white : Color.bobAccent)
                                .frame(width: 44, height: 44)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(iconName == icon ? Color.bobAccent : Color.bobAccent.opacity(0.1))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }

    @State private var photoItem: PhotosPickerItem? {
        didSet {
            Task {
                guard let item = photoItem else { return }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photoData = data
                    iconName = "photo"
                }
            }
        }
    }

    // MARK: – Name section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Goal Name")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .textCase(.uppercase)
                .tracking(0.7)
                .padding(.horizontal, 2)

            HStack(spacing: 12) {
                GoalIconView(iconName: iconName, photoData: photoData, size: 28, showBackground: false)

                TextField("e.g. Emergency Fund, New Car", text: $name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.bobInk)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { nameFieldFocused = false }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.bobSurface.opacity(0.75))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                nameFieldFocused ? Color.bobAccent.opacity(0.4) : Color.white.opacity(0.07),
                                lineWidth: nameFieldFocused ? 1.5 : 1
                            )
                    }
            }
            .animation(.easeOut(duration: 0.18), value: nameFieldFocused)
        }
    }

    // MARK: – Deadline section

    private var deadlineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Deadline")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .textCase(.uppercase)
                .tracking(0.7)
                .padding(.horizontal, 2)

            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.bobAccent)
                    .frame(width: 28)

                Text(formattedDeadline)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.bobInk)

                Spacer()

                Text(daysUntilDeadline)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bobInk2)

                DatePicker("", selection: $deadline, in: Date()..., displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Color.bobAccent)
                    .colorScheme(.dark)
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.bobSurface.opacity(0.75))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
            }
        }
    }

    // MARK: – Monthly savings hint

    private var monthlyHint: some View {
        let months = max(
            Calendar.current.dateComponents([.month], from: Date(), to: deadline).month ?? 1, 1
        )
        let monthly = targetAmount / Decimal(months)

        return HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.bobHex(0xF59E0B))
            Text("Save \(CurrencyFormatter.string(monthly, code: currencyCode))/month to reach this goal on time")
                .font(.system(size: 13))
                .foregroundStyle(Color.bobInk2)
        }
        .padding(Spacing.m)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.bobHex(0xF59E0B).opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.bobHex(0xF59E0B).opacity(0.2), lineWidth: 1)
                }
        }
    }

    // MARK: – Save bar

    private var saveBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

            Button { saveGoal() } label: {
                Text(isEditing ? "Save Changes" : "Create Goal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canSave ? .white : Color.bobInk2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSave ? Color.bobAccent : Color.bobSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(canSave ? Color.clear : Color.white.opacity(0.08), lineWidth: 1))
            }
            .disabled(!canSave)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .animation(.easeOut(duration: 0.15), value: canSave)
        }
        .background(Color.bobBackground)
    }

    // MARK: – Keypad overlay

    private var keypadFloat: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Savings Goal")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.bobInk3)
                        .textCase(.uppercase)
                        .tracking(0.9)
                    BigAmountView(
                        amount: targetAmount,
                        currencyCode: currencyCode,
                        size: 26,
                        tint: targetAmount > 0 ? Color.bobAccent : Color.bobInk3
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
                        .background(Color.bobAccent)
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
                    startPoint: .top, endPoint: .bottom
                )
            }

            Rectangle().fill(Color.white.opacity(0.09)).frame(height: 1)
            CurrencyKeypad(amount: $targetAmount)
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
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.6), radius: 40, y: -6)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: – Helpers

    private var formattedDeadline: String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: deadline)
    }

    private var daysUntilDeadline: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        if days <= 0 { return "Today" }
        if days < 30 { return "\(days)d" }
        let months = Calendar.current.dateComponents([.month], from: Date(), to: deadline).month ?? 0
        return "\(months)mo"
    }

    private func saveGoal() {
        guard canSave else { return }
        HapticManager.success()
        let trimName = name.trimmingCharacters(in: .whitespaces)
        if let existing = goalToEdit {
            existing.name = trimName
            existing.iconName = iconName
            existing.photoData = photoData
            existing.targetAmount = targetAmount
            existing.deadline = deadline
        } else {
            let goal = Goal(name: trimName, iconName: iconName, photoData: photoData, targetAmount: targetAmount, deadline: deadline)
            modelContext.insert(goal)
        }
        try? modelContext.save()

        dismiss()
    }
}

#Preview {
    AddGoalSheet(currencyCode: "USD")
        .modelContainer(for: Goal.self, inMemory: true)
}
