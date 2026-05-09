import SwiftUI

struct MonthlySummaryCard: View {
    let income: Decimal
    let expenses: Decimal
    let budget: Decimal
    let currencyCode: String
    let monthLabel: String

    @AppStorage("budgetAlerts") private var budgetAlerts = true

    private var cashFlow: Decimal { income - expenses }
    private var budgetProgress: Double {
        guard budget > 0 else { return 0 }
        return min(Double((expenses / budget) as NSDecimalNumber), 1.0)
    }
    private var budgetUsedPct: Int { Int(budgetProgress * 100) }
    private var isOverBudget: Bool { budget > 0 && expenses > budget }
    private var progressColor: Color {
        if budgetProgress >= 1.0 { return .bobDebit }
        if budgetProgress >= 0.8 { return Color.bobHex(0xF59E0B) }
        return .bobAccent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Summary")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.bobInk)
                    Text(monthLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bobInk2)
                }
                Spacer()
                // Net cash flow badge
                let isPositive = cashFlow >= 0
                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(CurrencyFormatter.string(
                        abs(cashFlow as NSDecimalNumber as Decimal),
                        code: currencyCode
                    ))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                }
                .foregroundStyle(isPositive ? Color.bobAccent : Color.bobDebit)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isPositive ? Color.bobAccent.opacity(0.1) : Color.bobDebit.opacity(0.1))
                )
            }
            .padding(.horizontal, Spacing.m)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.s)

            Divider().padding(.horizontal, Spacing.m)

            // Income / Expenses rows
            VStack(spacing: 0) {
                statRow(
                    icon: "arrow.down.circle.fill",
                    label: "Income",
                    amount: income,
                    color: .bobAccent
                )
                Divider().padding(.leading, 52)
                statRow(
                    icon: "arrow.up.circle.fill",
                    label: "Expenses",
                    amount: expenses,
                    color: .bobDebit
                )
            }
            .padding(.horizontal, Spacing.m)

            // Budget progress (only shown when budget is set)
            if budget > 0 && budgetAlerts {
                Divider().padding(.horizontal, Spacing.m)

                VStack(spacing: 8) {
                    HStack {
                        Text("Budget")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.bobInk2)
                        Spacer()
                        Text(isOverBudget
                             ? "Over by \(CurrencyFormatter.string(expenses - budget, code: currencyCode))"
                             : "\(budgetUsedPct)% of \(CurrencyFormatter.string(budget, code: currencyCode))"
                        )
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isOverBudget ? Color.bobDebit : Color.bobInk2)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.bobHairline)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor)
                                .frame(width: geo.size.width * budgetProgress, height: 6)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: budgetProgress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.m)
            } else {
                Spacer().frame(height: Spacing.m)
            }
        }
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.bobHairline, lineWidth: 1)
        )
    }

    private func statRow(icon: String, label: String, amount: Decimal, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
                .frame(width: 32)

            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.bobInk2)

            Spacer()

            Text(CurrencyFormatter.string(amount, code: currencyCode))
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.bobInk)
        }
        .padding(.vertical, 14)
    }
}
