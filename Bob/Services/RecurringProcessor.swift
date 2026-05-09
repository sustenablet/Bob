import Foundation
import SwiftData

@MainActor
final class RecurringProcessor {
    static let shared = RecurringProcessor()
    
    private init() {}
    
    @discardableResult
    func processDueRecurrings(context: ModelContext) -> [Expense] {
        var createdExpenses: [Expense] = []
        
        let now = Date()
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate<RecurringTransaction> { rec in
                rec.isActive && rec.nextDueDate <= now
            }
        )
        
        guard let recurrings = try? context.fetch(descriptor) else { return [] }
        
        for var recurring in recurrings {
            // Catch up all missed periods, not just one
            while recurring.nextDueDate <= now {
                let expense = Expense(
                    amount: recurring.amount,
                    date: recurring.nextDueDate,
                    note: "Auto: \(recurring.name)",
                    merchant: nil,
                    category: recurring.category,
                    kind: recurring.kind == .income ? .income : .expense
                )
                context.insert(expense)
                createdExpenses.append(expense)
                recurring.advanceToNextDueDate()
            }
        }
        
        try? context.save()
        return createdExpenses
    }
    
}