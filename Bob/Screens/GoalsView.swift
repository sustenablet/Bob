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

    private var goalsList: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                let activeGoals   = goals.filter { $0.isActive && !$0.isCompleted }
                let completedGoals = goals.filter { $0.isCompleted }
                let archivedGoals = goals.filter { !$0.isActive && !$0.isCompleted }

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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.bobInk3)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.top, Spacing.s)
    }
}

struct GoalCard: View {
    let goal: Goal
    let currencyCode: String
    var isCompleted: Bool = false
    
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
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.bobAccent)
                }
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