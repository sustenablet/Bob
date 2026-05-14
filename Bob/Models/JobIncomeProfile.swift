import Foundation
import SwiftData

enum JobPayCycle: String, Codable, CaseIterable, Identifiable {
    case weekly
    case biweekly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly: return "Monthly"
        }
    }
}

@Model
final class JobIncomeProfile {
    var id: UUID = UUID()
    var hourlyRate: Decimal = 0
    var payCycleRaw: String = JobPayCycle.weekly.rawValue
    var mondayEnabled: Bool = true
    var tuesdayEnabled: Bool = true
    var wednesdayEnabled: Bool = true
    var thursdayEnabled: Bool = true
    var fridayEnabled: Bool = true
    var saturdayEnabled: Bool = false
    var sundayEnabled: Bool = false
    var mondayHours: Double = 8
    var tuesdayHours: Double = 8
    var wednesdayHours: Double = 8
    var thursdayHours: Double = 8
    var fridayHours: Double = 8
    var saturdayHours: Double = 0
    var sundayHours: Double = 0
    var createdAt: Date = Date()

    var payCycle: JobPayCycle {
        get { JobPayCycle(rawValue: payCycleRaw) ?? .weekly }
        set { payCycleRaw = newValue.rawValue }
    }

    init() {
        self.id = UUID()
    }

    var weeklyHours: Double {
        (mondayEnabled ? mondayHours : 0) +
        (tuesdayEnabled ? tuesdayHours : 0) +
        (wednesdayEnabled ? wednesdayHours : 0) +
        (thursdayEnabled ? thursdayHours : 0) +
        (fridayEnabled ? fridayHours : 0) +
        (saturdayEnabled ? saturdayHours : 0) +
        (sundayEnabled ? sundayHours : 0)
    }

    var weeklyIncome: Decimal {
        hourlyRate * Decimal(weeklyHours)
    }
}

