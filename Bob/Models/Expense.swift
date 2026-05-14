import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID = UUID()
    var amount: Decimal = Decimal.zero
    var date: Date = Date()
    var note: String?
    var merchant: String?
    var iconSymbol: String?
    var category: ExpenseCategory?
    var createdAt: Date = Date()
    var kindRaw: String = TransactionKind.expense.rawValue

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(
        amount: Decimal,
        date: Date = Date(),
        note: String? = nil,
        merchant: String? = nil,
        iconSymbol: String? = nil,
        category: ExpenseCategory? = nil,
        kind: TransactionKind = .expense
    ) {
        self.id = UUID()
        self.amount = amount
        self.date = date
        self.note = note
        self.merchant = merchant
        self.iconSymbol = iconSymbol
        self.category = category
        self.createdAt = Date()
        self.kindRaw = kind.rawValue
    }
}
