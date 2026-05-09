import Foundation
import SwiftData

@Model
final class QuickAddTemplate {
    var id: UUID = UUID()
    var name: String
    var amount: Decimal
    var kind: TransactionKind
    var category: ExpenseCategory?
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(
        name: String,
        amount: Decimal,
        kind: TransactionKind,
        category: ExpenseCategory? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.kind = kind
        self.category = category
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}