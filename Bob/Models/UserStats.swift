import Foundation
import SwiftData

@Model
final class UserStats {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastLogDate: Date? = nil        // calendar-day normalised (midnight)
    var totalLogged: Int = 0            // all-time transactions logged via the app
    var earnedAchievementIDs: [String] = []

    init() {}
}
