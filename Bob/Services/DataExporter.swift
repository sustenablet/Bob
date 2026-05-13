import Foundation

enum DataExporter {
    static func exportExpensesToCSV(_ expenses: [Expense], currencyCode: String) -> String {
        var csv = "Date,Type,Category,Amount,Merchant,Note\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for expense in expenses {
            let date = dateFormatter.string(from: expense.date)
            let type = expense.kind == .income ? "Income" : "Expense"
            let category = expense.category?.name ?? "Other"
            let amount = "\(expense.amount)"
            let merchant = expense.merchant ?? ""
            let note = (expense.note ?? "").replacingOccurrences(of: ",", with: ";")
            
            csv += "\(date),\(type),\(category),\(amount),\(merchant),\(note)\n"
        }
        
        return csv
    }
    
    static func exportGoalsToCSV(_ goals: [Goal], currencyCode: String) -> String {
        var csv = "Name,Emoji,Target Amount,Saved Amount,Progress %,Deadline,Status\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for goal in goals {
            let name = goal.name.replacingOccurrences(of: ",", with: ";")
            let emoji = goal.iconName
            let target = "\(goal.targetAmount)"
            let saved = "\(goal.totalSaved)"
            let progress = "\(Int(goal.progress * 100))"
            let deadline = dateFormatter.string(from: goal.deadline)
            let status = goal.isCompleted ? "Completed" : "Active"
            
            csv += "\(name),\(emoji),\(target),\(saved),\(progress),\(deadline),\(status)\n"
        }
        
        return csv
    }
    
    static func exportRecurringToCSV(_ recurrings: [RecurringTransaction], currencyCode: String) -> String {
        var csv = "Name,Type,Frequency,Amount,Next Due,Status\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for recurring in recurrings {
            let name = recurring.name.replacingOccurrences(of: ",", with: ";")
            let type = recurring.kind == .income ? "Income" : "Expense"
            let frequency = recurring.frequency.rawValue
            let amount = "\(recurring.amount)"
            let nextDue = dateFormatter.string(from: recurring.nextDueDate)
            let status = recurring.isActive ? "Active" : "Paused"
            
            csv += "\(name),\(type),\(frequency),\(amount),\(nextDue),\(status)\n"
        }
        
        return csv
    }
}