import SwiftUI
import SwiftData
import UIKit

struct AddContributionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let goal: Goal
    let currencyCode: String

    @State private var amount: Decimal = .zero
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var showDatePicker = false

    var canSave: Bool { amount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    // Amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Contribution amount").eyebrow()
                        BigAmountView(
                            amount: amount,
                            currencyCode: currencyCode,
                            size: 48,
                            tint: amount > 0 ? Color.bobAccent : Color.bobInk2
                        )
                    }
                    .padding(.top, Spacing.m)

                    // Quick amounts
                    quickAmountsRow

                    // Goal context
                    goalContextCard

                    // Note
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Note").eyebrow()
                        TextField("e.g. Monthly savings, Tax refund", text: $note)
                            .font(.bobBody)
                            .foregroundStyle(Color.bobInk)
                            .padding(Spacing.m)
                            .background(Color.bobSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.bobHairline, lineWidth: 1))
                            .submitLabel(.done)
                    }

                    // Date
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Date").eyebrow()
                        Button {
                            withAnimation { showDatePicker.toggle() }
                        } label: {
                            HStack {
                                Text(relativeDate(date))
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
                            DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .tint(Color.bobAccent)
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
                    Text("Add Contribution")
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
            CurrencyKeypad(amount: $amount).background(Color.bobBackground)
        }
        .background(Color.bobBackground.ignoresSafeArea())
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

    private var quickAmountsRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Quick add").eyebrow()
            HStack(spacing: 10) {
                ForEach([50, 100, 250, 500], id: \.self) { value in
                    Button {
                        withAnimation { amount = Decimal(value) }
                        HapticManager.light()
                    } label: {
                        Text(CurrencyFormatter.compact(Decimal(value), code: currencyCode))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.bobAccent)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.bobAccent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var goalContextCard: some View {
        HStack(spacing: 12) {
            Text(goal.emoji).font(.system(size: 24))

            VStack(alignment: .leading, spacing: 3) {
                Text(goal.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                Text("\(Int(goal.progress * 100))% saved · \(CurrencyFormatter.string(goal.targetAmount - goal.totalSaved, code: currencyCode)) remaining")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bobInk2)
            }

            Spacer()

            if amount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    let newTotal = goal.totalSaved + amount
                    let newPct = min(Int((newTotal / goal.targetAmount * 100) as NSDecimalNumber), 100)
                    Text("→ \(newPct)%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.bobAccent)
                    Text("after this")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.bobInk3)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bobHairline, lineWidth: 1))
        .animation(.easeOut(duration: 0.2), value: amount)
    }

    // MARK: – Helpers

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: date)
    }

    private func save() {
        guard canSave else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let contribution = GoalContribution(
            amount: amount,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil
                  : note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        contribution.goal = goal
        modelContext.insert(contribution)
        goal.contributions = (goal.contributions ?? []) + [contribution]
        try? modelContext.save()
        dismiss()
    }
}
