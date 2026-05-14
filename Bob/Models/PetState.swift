import Foundation

enum PetState: Equatable {
    case thriving
    case content
    case neutral
    case worried
    case struggling
    case sleeping
    case celebrating
}

struct PetHealthScore {
    let total: Int           // 0–100
    let budgetPoints: Int    // 0–70
    let savingsPoints: Int   // 0–30

    var state: PetState {
        switch total {
        case 80...100: return .thriving
        case 60..<80:  return .content
        case 40..<60:  return .neutral
        case 20..<40:  return .worried
        default:       return .struggling
        }
    }

    static func compute(
        budgetUsage: Double,    // monthSpend / monthlyBudget; 0 if no budget set
        hasBudget: Bool,
        savingsProgress: Double, // avg across active goals; 0–1+
        hasGoals: Bool
    ) -> PetHealthScore {
        // Budget (70 pts): proportional to how far under budget; neutral if no budget set.
        let budgetPoints: Int
        if hasBudget {
            budgetPoints = max(0, Int((1.0 - min(budgetUsage, 1.0)) * 70))
        } else {
            budgetPoints = 35
        }

        // Savings (30 pts): proportional to avg goal progress; neutral if no goals.
        let savingsPoints: Int
        if hasGoals {
            savingsPoints = Int(min(savingsProgress, 1.0) * 30)
        } else {
            savingsPoints = 15
        }

        let total = budgetPoints + savingsPoints
        return PetHealthScore(
            total: total,
            budgetPoints: budgetPoints,
            savingsPoints: savingsPoints
        )
    }
}
