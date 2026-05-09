import SwiftUI

/// Large serif display for a currency amount.
/// Used on the Home hero and the AddExpense input display.
struct BigAmountView: View {
    let amount: Decimal
    let currencyCode: String
    var size: CGFloat = 68
    var tint: Color = .bobInk

    var body: some View {
        Text(formatted)
            .font(.bobSerif(size))
            .tracking(-0.5)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText())
            .animation(.easeOut(duration: 0.2), value: amount)
    }

    private var formatted: String {
        CurrencyFormatter.string(amount, code: currencyCode)
    }
}
