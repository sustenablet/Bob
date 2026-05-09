import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]

    @State private var showAddGoal = false
    @State private var selectedGoal: Goal?
    @State private var addContributionGoal: Goal?
    @State private var showArchived = false
    @State private var showCompleted = false

    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }

    // Urgency-sorted active goals: At Risk → Behind → On Track → by daysLeft
    private var activeGoals: [Goal] {
        goals.filter { $0.isActive && !$0.isCompleted }.sorted { a, b in
            let rankA = healthRank(a); let rankB = healthRank(b)
            if rankA != rankB { return rankA < rankB }
            return a.daysLeft < b.daysLeft
        }
    }

    private var completedGoals: [Goal] { goals.filter { $0.isCompleted } }
    private var archivedGoals: [Goal] { goals.filter { !$0.isActive && !$0.isCompleted } }

    private func healthRank(_ goal: Goal) -> Int {
        let (_, _, status) = goalHealth(goal)
        switch status {
        case "atRisk":    return 0
        case "behind":    return 1
        case "onTrack":   return 2
        default:          return 3
        }
    }

    // Returns (label, color, statusKey)
    private func goalHealth(_ goal: Goal) -> (String, Color, String) {
        if goal.isCompleted { return ("Completed", .bobAccent, "completed") }
        if Date() > goal.deadline { return ("Overdue", .bobDebit, "atRisk") }
        let contribs = goal.contributions ?? []
        guard !contribs.isEmpty else { return ("No saves yet", .bobInk3, "noSaves") }
        let cal = Calendar.current
        let monthsActive = max(cal.dateComponents([.month], from: goal.createdAt, to: Date()).month ?? 1, 1)
        let avg = goal.totalSaved / Decimal(monthsActive)
        let remaining = max(goal.targetAmount - goal.totalSaved, 0)
        guard avg > 0 else { return ("At Risk", .bobDebit, "atRisk") }
        let monthsNeeded = Int(ceil(Double((remaining / avg) as NSDecimalNumber)))
        let monthsLeft = max(cal.dateComponents([.month], from: Date(), to: goal.deadline).month ?? 0, 0)
        if monthsNeeded <= monthsLeft { return ("On Track", .bobAccent, "onTrack") }
        if monthsNeeded <= monthsLeft + 3 { return ("Behind", Color.bobHex(0xF59E0B), "behind") }
        return ("At Risk", .bobDebit, "atRisk")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bobBackground.ignoresSafeArea()
                if goals.isEmpty { emptyState } else { goalsList }
            }
            .navigationTitle("Savings Goals")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.bobBackground, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddGoal = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.bobInk)
                    }
                }
            }
            .sheet(isPresented: $showAddGoal) { AddGoalSheet(currencyCode: currencyCode) }
            .sheet(item: $selectedGoal) { goal in GoalDetailView(goal: goal, currencyCode: currencyCode) }
            .sheet(item: $addContributionGoal) { goal in AddContributionSheet(goal: goal, currencyCode: currencyCode) }
        }
    }

    // MARK: – Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Color.bobAccent.opacity(0.1)).frame(width: 100, height: 100)
                Image(systemName: "target").font(.system(size: 40, weight: .light)).foregroundStyle(Color.bobAccent)
            }
            VStack(spacing: 8) {
                Text("No savings goals yet")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.bobInk)
                Text("Create a goal to start tracking\nyour savings progress")
                    .font(.bobBody).foregroundStyle(Color.bobInk2).multilineTextAlignment(.center)
            }
            Button { showAddGoal = true } label: {
                HStack(spacing: 8) { Image(systemName: "plus"); Text("Create Goal") }
                    .font(.bobBodyMed).foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Color.bobAccent).clipShape(Capsule())
            }
            Spacer()
        }.padding()
    }

    // MARK: – Goals list

    private var goalsList: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                // Hero summary
                if !activeGoals.isEmpty { goalsHero }

                // Active goals
                if !activeGoals.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        sectionHeader("Active — \(activeGoals.count)")
                        ForEach(activeGoals) { goal in
                            GoalCard(
                                goal: goal,
                                currencyCode: currencyCode,
                                health: goalHealth(goal),
                                onTap: { selectedGoal = goal },
                                onAdd: { addContributionGoal = goal }
                            )
                        }
                    }
                }

                // Completed (collapsible)
                if !completedGoals.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Button { withAnimation { showCompleted.toggle() } } label: {
                            HStack {
                                sectionHeader("Completed — \(completedGoals.count)")
                                Spacer()
                                Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.bobInk3)
                            }
                        }.buttonStyle(.plain)

                        if showCompleted {
                            ForEach(completedGoals) { goal in
                                GoalCard(
                                    goal: goal,
                                    currencyCode: currencyCode,
                                    health: goalHealth(goal),
                                    onTap: { selectedGoal = goal },
                                    onAdd: nil
                                )
                            }
                        }
                    }
                }

                // Archived (collapsible)
                if !archivedGoals.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Button { withAnimation { showArchived.toggle() } } label: {
                            HStack {
                                sectionHeader("Archived — \(archivedGoals.count)")
                                Spacer()
                                Image(systemName: showArchived ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.bobInk3)
                            }
                        }.buttonStyle(.plain)

                        if showArchived {
                            ForEach(archivedGoals) { goal in
                                GoalCard(
                                    goal: goal,
                                    currencyCode: currencyCode,
                                    health: goalHealth(goal),
                                    onTap: { selectedGoal = goal },
                                    onAdd: nil
                                ).opacity(0.55)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.top, Spacing.m)
            .padding(.bottom, 120)
        }
    }

    // MARK: – Goals hero

    private var goalsHero: some View {
        let totalSaved  = activeGoals.reduce(Decimal(0)) { $0 + $1.totalSaved }
        let totalTarget = activeGoals.reduce(Decimal(0)) { $0 + $1.targetAmount }
        let progress    = totalTarget > 0 ? min(Double((totalSaved / totalTarget) as NSDecimalNumber), 1.0) : 0
        let remaining   = totalTarget - totalSaved
        let onTrack     = activeGoals.filter { goalHealth($0).2 == "onTrack" }.count
        let behind      = activeGoals.filter { goalHealth($0).2 == "behind" || goalHealth($0).2 == "atRisk" }.count

        return VStack(spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Savings")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bobInk2)
                    Text(CurrencyFormatter.string(totalSaved, code: currencyCode))
                        .font(.system(size: 28, weight: .bold)).foregroundStyle(Color.bobInk)
                    Text(CurrencyFormatter.string(remaining, code: currencyCode) + " remaining")
                        .font(.system(size: 13)).foregroundStyle(Color.bobInk3)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.bobHairline, lineWidth: 8).frame(width: 68, height: 68)
                    Circle().trim(from: 0, to: progress)
                        .stroke(Color.bobAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 68, height: 68)
                        .animation(.spring(response: 0.6), value: progress)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Color.bobInk)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.bobHairline).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(Color.bobAccent)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
            HStack(spacing: 16) {
                if onTrack > 0 {
                    Label("\(onTrack) on track", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bobAccent)
                }
                if behind > 0 {
                    Label("\(behind) at risk", systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bobDebit)
                }
                Spacer()
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bobHairline, lineWidth: 1))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.bobInk2)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

// MARK: – Goal Card (redesigned with circular ring)

struct GoalCard: View {
    let goal: Goal
    let currencyCode: String
    let health: (label: String, color: Color, status: String)
    let onTap: () -> Void
    let onAdd: (() -> Void)?

    private var ringProgress: Double { min(goal.progress, 1.0) }
    private var remaining: Decimal { max(goal.targetAmount - goal.totalSaved, 0) }

    private var cardBackground: Color {
        health.color.opacity(0.04)
    }

    private var projectedLabel: String? {
        let contribs = goal.contributions ?? []
        guard !contribs.isEmpty else { return nil }
        let cal = Calendar.current
        let monthsActive = max(cal.dateComponents([.month], from: goal.createdAt, to: Date()).month ?? 1, 1)
        let avg = goal.totalSaved / Decimal(monthsActive)
        guard avg > 0, remaining > 0 else { return nil }
        let monthsNeeded = Int(ceil(Double((remaining / avg) as NSDecimalNumber)))
        guard let projected = cal.date(byAdding: .month, value: monthsNeeded, to: Date()) else { return nil }
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        return f.string(from: projected)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 14) {
                // Top row: emoji + name + add button
                HStack(alignment: .center) {
                    Text(goal.emoji).font(.system(size: 24))
                    Text(goal.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bobInk)
                        .lineLimit(1)
                    Spacer()
                    if let add = onAdd {
                        Button(action: add) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                                Text("Add").font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.bobAccent)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.bobAccent.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Middle: ring + stats
                HStack(spacing: 16) {
                    // Circular progress ring
                    ZStack {
                        Circle().stroke(Color.bobHairline, lineWidth: 7).frame(width: 72, height: 72)
                        Circle().trim(from: 0, to: ringProgress)
                            .stroke(health.color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 72, height: 72)
                            .animation(.spring(response: 0.5), value: ringProgress)
                        VStack(spacing: 0) {
                            Text("\(Int(ringProgress * 100))%")
                                .font(.system(size: 14, weight: .bold)).foregroundStyle(Color.bobInk)
                        }
                    }

                    // Amount stats
                    VStack(alignment: .leading, spacing: 5) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(CurrencyFormatter.string(goal.totalSaved, code: currencyCode))
                                .font(.system(size: 20, weight: .bold)).foregroundStyle(Color.bobInk)
                            Text("of \(CurrencyFormatter.string(goal.targetAmount, code: currencyCode))")
                                .font(.system(size: 12)).foregroundStyle(Color.bobInk3)
                        }
                        if remaining > 0 {
                            Text(CurrencyFormatter.string(remaining, code: currencyCode) + " to go")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bobInk2)
                            let monthsLeft = max(Calendar.current.dateComponents([.month], from: Date(), to: goal.deadline).month ?? 1, 1)
                            let neededPerMonth = remaining / Decimal(monthsLeft)
                            Text("Save \(CurrencyFormatter.compact(neededPerMonth, code: currencyCode))/mo to reach goal")
                                .font(.system(size: 11)).foregroundStyle(Color.bobInk3)
                        }
                    }
                    Spacer()
                }

                // Bottom row: health badge + projected + days left
                HStack(spacing: 8) {
                    // Health badge
                    HStack(spacing: 4) {
                        Image(systemName: healthIcon).font(.system(size: 10, weight: .bold))
                        Text(health.label).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(health.color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(health.color.opacity(0.12))
                    .clipShape(Capsule())

                    if let proj = projectedLabel {
                        Text("·").foregroundStyle(Color.bobInk3)
                        Text(proj).font(.system(size: 11)).foregroundStyle(Color.bobInk3)
                    }

                    Spacer()

                    let isOverdue = !goal.isCompleted && Date() > goal.deadline
                    if !goal.isCompleted {
                        Text(isOverdue ? "Overdue" : "\(goal.daysLeft)d left")
                            .font(.system(size: 11, weight: isOverdue ? .semibold : .regular))
                            .foregroundStyle(isOverdue ? Color.bobDebit : Color.bobInk3)
                    }
                }
            }
            .padding(Spacing.m)
            .background(cardBackground)
            .background(Color.bobSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(health.color.opacity(health.status == "onTrack" ? 0.2 : health.status == "noSaves" ? 0 : 0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(GoalCardPressStyle())
    }

    private var healthIcon: String {
        switch health.status {
        case "completed": return "checkmark.circle.fill"
        case "onTrack":   return "checkmark.circle"
        case "behind":    return "exclamationmark.circle"
        case "atRisk":    return "exclamationmark.circle.fill"
        default:          return "clock"
        }
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
