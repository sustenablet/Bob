import SwiftUI

struct ExpenseRow: View {
    let expense: Expense
    let currencyCode: String

    private var isIncome: Bool { expense.kind == .income }
    private var amountColor: Color { isIncome ? .bobAccent : .bobInk }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            // Category icon
            Image(systemName: expense.category?.sfSymbol ?? "circle.dashed")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(isIncome ? Color.bobAccent : Color.bobInk3)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isIncome ? Color.bobAccentSoft : Color.bobHairline.opacity(0.6))
                )

            // Title + secondary
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText)
                    .font(.bobCallout)
                    .foregroundStyle(Color.bobInk)
                    .lineLimit(1)

                if let secondary = secondaryText {
                    Text(secondary)
                        .font(.bobCaption)
                        .foregroundStyle(Color.bobInk2)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.xs)

            // Amount — right-aligned, mono
            Text(displayAmount)
                .font(.bobMono(15))
                .monospacedDigit()
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 12)
    }

    private var displayAmount: String {
        let formatted = CurrencyFormatter.string(expense.amount, code: currencyCode)
        return isIncome ? "+\(formatted)" : formatted
    }

    private var primaryText: String {
        if let merchant = expense.merchant, !merchant.isEmpty { return merchant }
        return expense.category?.name ?? (isIncome ? "Income" : "Expense")
    }

    private var secondaryText: String? {
        let hasNote = !(expense.note?.isEmpty ?? true)
        let hasMerchant = !(expense.merchant?.isEmpty ?? true)

        if hasMerchant, let cat = expense.category?.name {
            if hasNote { return "\(cat) · \(expense.note!)" }
            return cat
        }
        return hasNote ? expense.note : nil
    }
}
