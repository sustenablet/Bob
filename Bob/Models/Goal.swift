import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "🎯"
    var targetAmount: Decimal = Decimal(1000)
    var deadline: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    var createdAt: Date = Date()
    var isActive: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \GoalContribution.goal)
    var contributions: [GoalContribution]? = []

    init(
        name: String,
        emoji: String = "🎯",
        targetAmount: Decimal,
        deadline: Date
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.targetAmount = targetAmount
        self.deadline = deadline
        self.createdAt = Date()
        self.isActive = true
        self.contributions = []
    }

    var totalSaved: Decimal {
        (contributions ?? []).reduce(.zero) { $0 + $1.amount }
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        let ratio = (totalSaved as NSDecimalNumber).doubleValue /
                    (targetAmount as NSDecimalNumber).doubleValue
        return min(max(ratio, 0), 1)
    }

    var isCompleted: Bool { totalSaved >= targetAmount }

    var daysLeft: Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        return max(days, 0)
    }
}

@Model
final class GoalContribution {
    var id: UUID = UUID()
    var amount: Decimal = Decimal.zero
    var date: Date = Date()
    var note: String?
    var isAutoSurplus: Bool = false
    var goal: Goal?

    init(amount: Decimal, date: Date = Date(), note: String? = nil, isAutoSurplus: Bool = false) {
        self.id = UUID()
        self.amount = amount
        self.date = date
        self.note = note
        self.isAutoSurplus = isAutoSurplus
    }
}
