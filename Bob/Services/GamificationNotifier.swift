import Foundation

extension Notification.Name {
    static let bobAchievementsUnlocked = Notification.Name("bob.achievementsUnlocked")
}

enum GamificationNotifier {
    private static let idsKey = "ids"

    static func postAchievementsUnlocked(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        NotificationCenter.default.post(
            name: .bobAchievementsUnlocked,
            object: nil,
            userInfo: [idsKey: ids]
        )
    }

    static func achievementIDs(from notification: Notification) -> [String] {
        notification.userInfo?[idsKey] as? [String] ?? []
    }
}
