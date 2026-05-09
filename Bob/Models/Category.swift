import Foundation
import SwiftData

@Model
final class ExpenseCategory {
    var id: UUID = UUID()
    var name: String = ""
    var sfSymbol: String = "circle"
    var sortOrder: Int = 0
    var kindRaw: String = TransactionKind.expense.rawValue

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense]? = []

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String, sfSymbol: String, sortOrder: Int, kind: TransactionKind = .expense) {
        self.id = UUID()
        self.name = name
        self.sfSymbol = sfSymbol
        self.sortOrder = sortOrder
        self.kindRaw = kind.rawValue
        self.expenses = []
    }
}

extension ExpenseCategory {
    static let defaultsExpense: [(name: String, symbol: String)] = [
        ("Food", "fork.knife"),
        ("Groceries", "cart"),
        ("Transport", "car"),
        ("Shopping", "bag"),
        ("Bills", "doc.text"),
        ("Entertainment", "music.note"),
        ("Health", "heart"),
        ("Other", "circle.dashed")
    ]

    static let defaultsIncome: [(name: String, symbol: String)] = [
        ("Salary", "dollarsign.circle"),
        ("Gift", "gift"),
        ("Refund", "arrow.uturn.backward"),
        ("Bonus", "star"),
        ("Other", "circle.dashed")
    ]
}
