import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]
    
    @State private var showAddGoal = false
    @State private var selectedGoal: Goal?
    
    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.bobBackground.ignoresSafeArea()
                
                if goals.isEmpty {
                    emptyState
                } else {
                    goalsList
                }
            }
            .navigationTitle("Savings Goals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.bobInk)
                    }
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalSheet(currencyCode: currencyCode)
            }
            .sheet(item: $selectedGoal) { goal in
                GoalDetailView(goal: goal, currencyCode: currencyCode)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundStyle(Color.bobInk3)
            
            VStack(spacing: 8) {
                Text("No savings goals yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                
                Text("Create your first goal to start\ntracking your savings progress")
                    .font(.bobBody)
                    .foregroundStyle(Color.bobInk2)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showAddGoal = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Create Goal")
                }
                .font(.bobBodyMed)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.bobAccent)
                .clipShape(Capsule())
            }
            
            Spacer()
        }
        .padding()
    }
    
    @State private var showArchived = false

    // MARK: – Goal health helpers

    private func goalHealth(_ goal: Goal) -> (label: String, color: Color, icon: String) {
        if goal.isCompleted { return ("Completed", .bobAccent, "checkmark.circle.fill") }
        guard !goal.contributions!.isEmpty else { return ("No contributions", .bobInk3, "clock") }
        let cal = Calendar.current
        let monthsActive = max(cal.dateComponents([.month], from: goal.createdAt, to: Date()).month ?? 1, 1)
        let avg = goal.totalSaved / Decimal(monthsActive)
        let remaining = max(goal.targetAmount - goal.totalSaved, 0)
        guard avg > 0 else { return ("At Risk", .bobDebit, "exclamationmark.circle.fill") }
        let monthsNeeded = Int(ceil(Double((remaining / avg) as NSDecimalNumber)))
        let monthsLeft = max(cal.dateComponents([.month], from: Date(), to: goal.deadline).month ?? 0, 0)
        if monthsNeeded <= monthsLeft { return ("On Track", .bobAccent, "checkmark.circle") }
        if monthsNeeded <= monthsLeft + 3 { return ("Behind", Color.bobHex(0xF59E0B), "exclamationmark.circle") }
        return ("At Risk", .bobDebit, "exclamationmark.circle.fill")
    }

    private var goalsList: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                let activeGoals   = goals.filter { $0.isActive && !$0.isCompleted }
                let completedGoals = goals.filter { $0.isCompleted }
                let archivedGoals = goals.filter { !$0.isActive && !$0.isCompleted }

                // Summary card
                if activeGoals.count >= 2 {
                    goalsSummaryCard(activeGoals: activeGoals)
                }

                if !activeGoals.isEmpty {
                    sectionHeader("Active — \(activeGoals.count)")
                    ForEach(activeGoals) { goal in
                        Button { selectedGoal = goal } label: {
                            GoalCard(goal: goal, currencyCode: currencyCode)
                        }
                        .buttonStyle(GoalCardPressStyle())
                    }
                }

                if !completedGoals.isEmpty {
                    sectionHeader("Completed — \(completedGoals.count)")
                    ForEach(completedGoals) { goal in
                        Button { selectedGoal = goal } label: {
                            GoalCard(goal: goal, currencyCode: currencyCode, isCompleted: true)
                        }
                        .buttonStyle(GoalCardPressStyle())
                    }
                }

                if !archivedGoals.isEmpty {
                    Button {
                        withAnimation { showArchived.toggle() }
                    } label: {
                        HStack {
                            Text("Archived — \(archivedGoals.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.bobInk2)
                                .textCase(.uppercase)
                                .tracking(0.6)
                            Spacer()
                            Image(systemName: showArchived ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.bobInk3)
                        }
                        .padding(.top, Spacing.xs)
                    }
                    .buttonStyle(.plain)

                    if showArchived {
                        ForEach(archivedGoals) { goal in
                            Button { selectedGoal = goal } label: {
                                GoalCard(goal: goal, currencyCode: currencyCode)
                                    .opacity(0.6)
                            }
                            .buttonStyle(GoalCardPressStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.top, Spacing.m)
            .padding(.bottom, 100)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
        }
        .padding(.top, Spacing.xs)
    }

    private func goalsSummaryCard(activeGoals: [Goal]) -> some View {
        let totalSaved = activeGoals.reduce(Decimal(0)) { $0 + $1.totalSaved }
        let totalTarget = activeGoals.reduce(Decimal(0)) { $0 + $1.targetAmount }
        let avgProgress = totalTarget > 0 ? Double((totalSaved / totalTarget) as NSDecimalNumber) : 0
        let remaining = totalTarget - totalSaved

        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(activeGoals.count) active goals")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bobInk2)
                    Text(CurrencyFormatter.string(totalSaved, code: currencyCode) + " saved")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(Color.bobInk)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.bobHairline, lineWidth: 6).frame(width: 52, height: 52)
                    Circle().trim(from: 0, to: avgProgress)
                        .stroke(Color.bobAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 52, height: 52)
                    Text("\(Int(avgProgress * 100))%")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Color.bobInk)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.bobHairline).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(Color.bobAccent)
                        .frame(width: geo.size.width * min(avgProgress, 1.0), height: 6)
                }
            }
            .frame(height: 6)
            HStack {
                Text(CurrencyFormatter.string(remaining, code: currencyCode) + " remaining across all goals")
                    .font(.system(size: 12)).foregroundStyle(Color.bobInk3)
                Spacer()
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bobHairline, lineWidth: 1))
    }
}

struct GoalCard: View {
    let goal: Goal
    let currencyCode: String
    var isCompleted: Bool = false
    
    private var healthBadge: some View {
        let (label, color, icon) = health
        return HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(label).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var health: (label: String, color: Color, icon: String) {
        if goal.isCompleted { return ("Completed", .bobAccent, "checkmark.circle.fill") }
        if Date() > goal.deadline { return ("Overdue", .bobDebit, "exclamationmark.circle.fill") }
        let contribs = goal.contributions ?? []
        guard !contribs.isEmpty else { return ("No saves yet", .bobInk3, "clock") }
        let cal = Calendar.current
        let monthsActive = max(cal.dateComponents([.month], from: goal.createdAt, to: Date()).month ?? 1, 1)
        let avg = goal.totalSaved / Decimal(monthsActive)
        let remaining = max(goal.targetAmount - goal.totalSaved, 0)
        guard avg > 0 else { return ("At Risk", .bobDebit, "exclamationmark.circle.fill") }
        let monthsNeeded = Int(ceil(Double((remaining / avg) as NSDecimalNumber)))
        let monthsLeft = max(cal.dateComponents([.month], from: Date(), to: goal.deadline).month ?? 0, 0)
        if monthsNeeded <= monthsLeft { return ("On Track", .bobAccent, "checkmark.circle") }
        if monthsNeeded <= monthsLeft + 3 { return ("Behind", Color.bobHex(0xF59E0B), "exclamationmark.circle") }
        return ("At Risk", .bobDebit, "exclamationmark.circle.fill")
    }

    private func isOverdue(_ goal: Goal) -> Bool {
        !goal.isCompleted && Date() > goal.deadline
    }

    private func goalSubtitle(for goal: Goal) -> String {
        if goal.isCompleted { return "Completed!" }
        if isOverdue(goal) { return "Overdue" }
        return "\(goal.daysLeft) days left"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(goal.emoji)
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bobInk)
                        .lineLimit(1)
                    
                    Text(goalSubtitle(for: goal))
                        .font(.system(size: 13))
                        .foregroundStyle(goal.isCompleted ? Color.bobAccent : (isOverdue(goal) ? Color.bobDebit : Color.bobInk3))
                }
                
                Spacer()

                // Health badge
                healthBadge
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(CurrencyFormatter.string(goal.totalSaved, code: currencyCode))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.bobInk)
                    
                    Text("of \(CurrencyFormatter.string(goal.targetAmount, code: currencyCode))")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bobInk3)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.bobHairline)
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isCompleted ? Color.bobAccent : Color.bobAccent.opacity(0.8))
                            .frame(width: geo.size.width * min(goal.progress, 1.0), height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            if goal.progress > 0 && !isCompleted {
                HStack {
                    Text("\(Int(goal.progress * 100))% saved")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.bobInk3)
                    
                    Spacer()
                    
                    Text("\(CurrencyFormatter.string(goal.targetAmount - goal.totalSaved, code: currencyCode)) to go")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bobInk3)
                }
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.bobHairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct GoalCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    GoalsView()
        .modelContainer(for: [Goal.self, GoalContribution.self, BudgetSettings.self], inMemory: true)
}