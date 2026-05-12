import Foundation

struct AchievementDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String    // SF Symbol name

    static let all: [AchievementDefinition] = [
        .init(id: "first_tx",      name: "First Step",        description: "Log your first transaction",        icon: "star.fill"),
        .init(id: "tx_10",         name: "Getting Started",   description: "Log 10 transactions",               icon: "list.bullet"),
        .init(id: "tx_50",         name: "Dedicated",         description: "Log 50 transactions",               icon: "flame.fill"),
        .init(id: "tx_100",        name: "Century",           description: "Log 100 transactions",              icon: "trophy.fill"),
        .init(id: "streak_7",      name: "Week Warrior",      description: "Keep a 7-day logging streak",       icon: "bolt.fill"),
        .init(id: "streak_30",     name: "Month Master",      description: "Keep a 30-day logging streak",      icon: "crown.fill"),
        .init(id: "first_goal",    name: "Dream Big",         description: "Create your first savings goal",    icon: "target"),
        .init(id: "goal_complete", name: "Nailed It",         description: "Complete a savings goal",           icon: "checkmark.seal.fill"),
        .init(id: "budget_hero",   name: "Budget Hero",       description: "Stay under budget for a full month", icon: "shield.fill"),
    ]

    static func find(_ id: String) -> AchievementDefinition? {
        all.first { $0.id == id }
    }
}
