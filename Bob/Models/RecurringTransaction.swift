import Foundation
import SwiftData

enum RecurringFrequency: String, Codable {
    case weekly
    case biweekly
    case monthly
    case yearly
}

enum RecurringKind: String, Codable {
    case income
    case expense
}

@Model
final class RecurringTransaction {
    var id: UUID = UUID()
    var name: String
    var amount: Decimal
    var kind: RecurringKind
    var frequency: RecurringFrequency
    var startDate: Date
    var nextDueDate: Date
    var iconSymbol: String?
    var category: ExpenseCategory?
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(
        name: String,
        amount: Decimal,
        kind: RecurringKind,
        frequency: RecurringFrequency,
        startDate: Date = Date(),
        iconSymbol: String? = nil,
        category: ExpenseCategory? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.kind = kind
        self.frequency = frequency
        self.startDate = startDate
        self.nextDueDate = Self.calculateNextDueDate(from: startDate, frequency: frequency)
        self.iconSymbol = iconSymbol
        self.category = category
        self.isActive = true
        self.createdAt = Date()
    }

    static func calculateNextDueDate(from date: Date, frequency: RecurringFrequency) -> Date {
        let cal = Calendar.current
        switch frequency {
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biweekly:
            return cal.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            return cal.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }

    func advanceToNextDueDate() {
        nextDueDate = Self.calculateNextDueDate(from: nextDueDate, frequency: frequency)
    }
}
