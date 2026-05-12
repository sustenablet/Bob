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
    let budgetPoints: Int    // 0–40
    let savingsPoints: Int   // 0–20
    let streakPoints: Int    // 0–20
    let achievementPoints: Int // 0–20

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
        hasGoals: Bool,
        streakDays: Int,
        achievementsEarned: Int,
        totalAchievements: Int
    ) -> PetHealthScore {
        // Budget (40 pts): proportional to how far under budget; 20 pts if no budget set
        let budgetPoints: Int
        if hasBudget {
            budgetPoints = max(0, Int((1.0 - min(budgetUsage, 1.0)) * 40))
        } else {
            budgetPoints = 20
        }

        // Savings (20 pts): proportional to avg goal progress; 10 pts if no goals
        let savingsPoints: Int
        if hasGoals {
            savingsPoints = Int(min(savingsProgress, 1.0) * 20)
        } else {
            savingsPoints = 10
        }

        // Streak (20 pts): capped at 30 days
        let streakPoints = min(streakDays, 30) * 20 / 30

        // Achievements (20 pts)
        let achievementPoints: Int
        if totalAchievements > 0 {
            achievementPoints = achievementsEarned * 20 / totalAchievements
        } else {
            achievementPoints = 0
        }

        let total = budgetPoints + savingsPoints + streakPoints + achievementPoints
        return PetHealthScore(
            total: total,
            budgetPoints: budgetPoints,
            savingsPoints: savingsPoints,
            streakPoints: streakPoints,
            achievementPoints: achievementPoints
        )
    }
}
