import Foundation
import SwiftData

@MainActor
final class GamificationService {
    static let shared = GamificationService()
    private init() {}

    // MARK: – Streak

    /// Updates the logging streak for today. Call this once per new transaction save.
    /// Returns true if the streak count changed.
    @discardableResult
    func updateStreak(stats: UserStats) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        stats.totalLogged += 1

        guard let last = stats.lastLogDate else {
            stats.currentStreak = 1
            stats.longestStreak = max(stats.longestStreak, 1)
            stats.lastLogDate = today
            return true
        }

        let lastDay = Calendar.current.startOfDay(for: last)

        if lastDay == today {
            // Already logged today — no streak change
            return false
        }

        let daysBetween = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0

        if daysBetween == 1 {
            stats.currentStreak += 1
        } else {
            stats.currentStreak = 1
        }

        stats.longestStreak = max(stats.longestStreak, stats.currentStreak)
        stats.lastLogDate = today
        return true
    }

    // MARK: – Achievements

    /// Checks which achievements are newly unlocked and appends them to stats.
    /// Returns the IDs of newly unlocked achievements so the UI can celebrate.
    func checkAchievements(
        stats: UserStats,
        allExpenses: [Expense],
        goals: [Goal],
        budget: BudgetSettings?
    ) -> [String] {
        var newlyUnlocked: [String] = []

        func unlock(_ id: String) {
            guard !stats.earnedAchievementIDs.contains(id) else { return }
            stats.earnedAchievementIDs.append(id)
            newlyUnlocked.append(id)
        }

        let totalExpenses = allExpenses.count

        // Transaction count milestones
        if totalExpenses >= 1   { unlock("first_tx") }
        if totalExpenses >= 10  { unlock("tx_10") }
        if totalExpenses >= 50  { unlock("tx_50") }
        if totalExpenses >= 100 { unlock("tx_100") }

        // Streak milestones
        if stats.currentStreak >= 7  { unlock("streak_7") }
        if stats.currentStreak >= 30 { unlock("streak_30") }

        // Goal milestones
        if !goals.isEmpty { unlock("first_goal") }
        if goals.contains(where: { $0.isCompleted }) { unlock("goal_complete") }

        // Budget hero — stayed under budget last completed month
        if let budget = budget, budget.monthlyBudget > 0 {
            let cal = Calendar.current
            guard let prevMonthStart = cal.date(byAdding: .month, value: -1, to: cal.startOfDay(for: Date())),
                  let monthInterval = cal.dateInterval(of: .month, for: prevMonthStart)
            else { return newlyUnlocked }

            let prevMonthSpend = allExpenses
                .filter { $0.kind == .expense && $0.date >= monthInterval.start && $0.date < monthInterval.end }
                .reduce(Decimal.zero) { $0 + $1.amount }

            if prevMonthSpend > 0 && prevMonthSpend < budget.monthlyBudget {
                unlock("budget_hero")
            }
        }

        return newlyUnlocked
    }
}
