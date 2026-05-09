import Foundation

enum CurrencyFormatter {
    static func string(_ amount: Decimal, code: String, showSymbol: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = showSymbol ? .currency : .decimal
        formatter.currencyCode = code
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    static func symbol(for code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? "$"
    }

    /// Short format: $1.2K, $3.4M — for compact chart labels
    static func compact(_ amount: Decimal, code: String) -> String {
        let symbol = CurrencyFormatter.symbol(for: code)
        let value = (amount as NSDecimalNumber).doubleValue
        switch value {
        case 1_000_000...: return "\(symbol)\(String(format: "%.1f", value / 1_000_000))M"
        case 1_000...:     return "\(symbol)\(String(format: "%.1f", value / 1_000))K"
        default:           return "\(symbol)\(String(format: "%.0f", value))"
        }
    }

    static func splitWholeFraction(_ amount: Decimal) -> (whole: String, fraction: String) {
        let nsNumber = amount as NSDecimalNumber
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        let formatted = formatter.string(from: nsNumber) ?? "0.00"
        let parts = formatted.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let whole = parts.first.map(String.init) ?? "0"
        let fraction = parts.count > 1 ? String(parts[1]) : "00"
        return (whole, fraction)
    }
}
