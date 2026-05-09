import Foundation
import SwiftData

@Model
final class BudgetSettings {
    var monthlyBudget: Decimal = Decimal(2000)
    var currencyCode: String = "USD"
    var weekStartsOnMonday: Bool = false

    init(
        monthlyBudget: Decimal = Decimal(2000),
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        weekStartsOnMonday: Bool = false
    ) {
        self.monthlyBudget = monthlyBudget
        self.currencyCode = currencyCode
        self.weekStartsOnMonday = weekStartsOnMonday
    }
}
