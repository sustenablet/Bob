import SwiftUI
import SwiftData
import UIKit

struct AddGoalSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let currencyCode: String
    var goalToEdit: Goal?

    @State private var name: String = ""
    @State private var emoji: String = "🎯"
    @State private var targetAmount: Decimal = .zero
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var showDatePicker = false

    private let emojis = ["🎯","🏠","🚗","✈️","💍","🎓","💻","📱","👶","🏖️","🎸","💰","🛒","⚡","🌟","🏋️","🎨","🐕","🌱","🏄"]

    var isEditing: Bool { goalToEdit != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && targetAmount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    // Target amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target amount").eyebrow()
                        BigAmountView(
                            amount: targetAmount,
                            currencyCode: currencyCode,
                            size: 48,
                            tint: targetAmount > 0 ? Color.bobAccent : Color.bobInk2
                        )
                    }
                    .padding(.top, Spacing.m)

                    // Emoji picker
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text("Choose an icon").eyebrow()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(emojis, id: \.self) { e in
                                    Button { emoji = e } label: {
                                        Text(e)
                                            .font(.system(size: 28))
                                            .frame(width: 52, height: 52)
                                            .background(emoji == e ? Color.bobAccent.opacity(0.15) : Color.bobSurface)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(emoji == e ? Color.bobAccent : Color.bobHairline, lineWidth: emoji == e ? 2 : 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Name
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Goal name").eyebrow()
                        TextField("e.g. Emergency Fund", text: $name)
                            .font(.system(size: 16))
                            .foregroundStyle(Color.bobInk)
                            .padding(Spacing.m)
                            .background(Color.bobSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bobHairline, lineWidth: 1))
                            .submitLabel(.done)
                    }

                    // Deadline
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Deadline").eyebrow()
                        Button {
                            withAnimation { showDatePicker.toggle() }
                        } label: {
                            HStack {
                                Text(formattedDeadline)
                                    .font(.bobBody).foregroundStyle(Color.bobInk)
                                Spacer()
                                Text(daysUntilDeadline)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.bobInk3)
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
                            DatePicker("", selection: $deadline, in: Date()..., displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .tint(Color.bobAccent)
                        }
                    }

                    // Monthly needed hint
                    if targetAmount > 0 {
                        monthlyHint
                    }

                    Spacer(minLength: Spacing.s)
                }
                .padding(.horizontal, Spacing.pageMargin)
            }

            // Save button
            VStack(spacing: 0) {
                HairlineDivider()
                Button { saveGoal() } label: {
                    Text(isEditing ? "Save Changes" : "Create Goal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(canSave ? .white : Color.bobInk3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSave ? Color.bobAccent : Color.bobSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(canSave ? Color.clear : Color.bobHairline, lineWidth: 1))
                }
                .disabled(!canSave)
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.vertical, Spacing.s)
                .animation(.easeOut(duration: 0.15), value: canSave)
            }

            HairlineDivider()
            CurrencyKeypad(amount: $targetAmount).background(Color.bobBackground)
        }
        .background(Color.bobBackground.ignoresSafeArea())
        .onAppear {
            guard let goal = goalToEdit else { return }
            name = goal.name
            emoji = goal.emoji
            targetAmount = goal.targetAmount
            deadline = goal.deadline
        }
    }

    // MARK: – Subviews

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

    private var monthlyHint: some View {
        let months = max(
            Calendar.current.dateComponents([.month], from: Date(), to: deadline).month ?? 1,
            1
        )
        let monthly = targetAmount / Decimal(months)
        return HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.bobHex(0xF59E0B))
            Text("Save \(CurrencyFormatter.string(monthly, code: currencyCode))/month to reach this goal on time")
                .font(.system(size: 13))
                .foregroundStyle(Color.bobInk2)
        }
        .padding(Spacing.m)
        .background(Color.bobHex(0xF59E0B).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: – Helpers

    private var formattedDeadline: String {
        let f = DateFormatter(); f.dateStyle = .long
        return f.string(from: deadline)
    }

    private var daysUntilDeadline: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "1 day" }
        if days < 30 { return "\(days) days" }
        let months = Calendar.current.dateComponents([.month], from: Date(), to: deadline).month ?? 0
        return "\(months) month\(months == 1 ? "" : "s")"
    }

    private func saveGoal() {
        guard canSave else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let trimName = name.trimmingCharacters(in: .whitespaces)
        if let existing = goalToEdit {
            existing.name = trimName
            existing.emoji = emoji
            existing.targetAmount = targetAmount
            existing.deadline = deadline
        } else {
            modelContext.insert(Goal(name: trimName, emoji: emoji, targetAmount: targetAmount, deadline: deadline))
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddGoalSheet(currencyCode: "USD")
        .modelContainer(for: Goal.self, inMemory: true)
}
