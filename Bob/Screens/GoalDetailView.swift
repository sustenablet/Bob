import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let goal: Goal
    let currencyCode: String

    @State private var showAddContribution = false
    @State private var showEditGoal = false

    // Contributions newest-first for display; oldest-first for analytics
    private var contributions: [GoalContribution] {
        (goal.contributions ?? []).sorted { $0.date > $1.date }
    }

    private var contributionsOldestFirst: [GoalContribution] {
        (goal.contributions ?? []).sorted { $0.date < $1.date }
    }

    // MARK: – Analytics

    private static let monthKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    /// Contributions grouped by "yyyy-MM", sorted oldest → newest
    private var monthlyData: [(month: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for c in contributions {
            let key = Self.monthKeyFormatter.string(from: c.date)
            dict[key, default: 0] += c.amount
        }
        return dict.map { (month: $0.key, amount: $0.value) }
            .sorted { $0.month < $1.month }
    }

    /// Months elapsed since the first contribution (minimum 1)
    private var monthsActive: Int {
        guard let first = contributionsOldestFirst.first else { return 1 }
        let months = Calendar.current.dateComponents([.month], from: first.date, to: Date()).month ?? 0
        return max(months, 1)
    }

    private var monthlyAverage: Decimal {
        guard !contributions.isEmpty else { return 0 }
        return goal.totalSaved / Decimal(monthsActive)
    }

    private var remaining: Decimal {
        max(goal.targetAmount - goal.totalSaved, 0)
    }

    private var projectedCompletionDate: Date? {
        guard monthlyAverage > 0, remaining > 0 else { return nil }
        let monthsNeeded = Int(ceil(Double((remaining / monthlyAverage) as NSDecimalNumber)))
        return Calendar.current.date(byAdding: .month, value: monthsNeeded, to: Date())
    }

    private var isOnTrack: Bool {
        guard let projected = projectedCompletionDate else { return goal.isCompleted }
        return projected <= goal.deadline
    }

    private var monthsToDeadline: Int {
        max(Calendar.current.dateComponents([.month], from: Date(), to: goal.deadline).month ?? 0, 1)
    }

    /// Extra per month needed on top of current pace to hit deadline on time
    private var extraNeededPerMonth: Decimal? {
        guard !goal.isCompleted, !isOnTrack, monthlyAverage > 0, remaining > 0 else { return nil }
        let needed = remaining / Decimal(monthsToDeadline)
        return needed > monthlyAverage ? needed - monthlyAverage : nil
    }

    // MARK: – Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bobBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.l) {
                        heroSection
                        progressSection
                        statsRow
                        paceAlertView
                        if !monthlyData.isEmpty { chartSection }
                        if !goal.isCompleted { addContributionButton }
                        historySection
                    }
                    .padding(.horizontal, Spacing.pageMargin)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle(goal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.bobInk2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showEditGoal = true } label: {
                            Label("Edit Goal", systemImage: "pencil")
                        }
                        if goal.isActive {
                            Button(role: .destructive) {
                                goal.isActive = false
                                try? modelContext.save()
                                dismiss()
                            } label: {
                                Label("Archive Goal", systemImage: "archivebox")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.bobInk)
                    }
                }
            }
            .sheet(isPresented: $showAddContribution) {
                AddContributionSheet(goal: goal, currencyCode: currencyCode)
            }
            .sheet(isPresented: $showEditGoal) {
                AddGoalSheet(currencyCode: currencyCode, goalToEdit: goal)
            }
        }
    }

    // MARK: – Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Text(goal.emoji)
                .font(.system(size: 80))
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text(CurrencyFormatter.string(goal.totalSaved, code: currencyCode))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color.bobInk)
                    .contentTransition(.numericText())

                HStack(spacing: 4) {
                    Text("of")
                        .foregroundStyle(Color.bobInk3)
                    Text(CurrencyFormatter.string(goal.targetAmount, code: currencyCode))
                        .foregroundStyle(Color.bobInk2)
                        .fontWeight(.medium)
                }
                .font(.system(size: 16))
            }

            if goal.isCompleted {
                Label("Goal Completed!", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.bobAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.bobAccent.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Progress bar with milestones

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Progress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                Spacer()
                Text("\(Int(goal.progress * 100))% saved")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.bobInk2)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.bobHairline)
                        .frame(height: 12)

                    // Fill with gradient
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.bobAccent.opacity(0.65), Color.bobAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(goal.progress, 1.0), height: 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: goal.progress)

                    // Milestone markers at 25 / 50 / 75 %
                    ForEach([0.25, 0.50, 0.75], id: \.self) { pct in
                        let reached = goal.progress >= pct
                        ZStack {
                            Circle()
                                .fill(reached ? Color.bobAccent : Color.bobBackground)
                                .frame(width: 18, height: 18)
                            Circle()
                                .stroke(reached ? Color.bobAccent : Color.bobHairline, lineWidth: 1.5)
                                .frame(width: 18, height: 18)
                            if reached {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(.white)
                            }
                        }
                        .offset(x: geo.size.width * pct - 9, y: 0)
                    }
                }
            }
            .frame(height: 18)

            // Saved / Remaining row
            HStack {
                Label(CurrencyFormatter.string(goal.totalSaved, code: currencyCode), systemImage: "checkmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bobAccent)
                Spacer()
                if remaining > 0 {
                    Label(CurrencyFormatter.string(remaining, code: currencyCode) + " to go", systemImage: "flag")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bobInk2)
                }
            }
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – 3-stat row

    private var statsRow: some View {
        HStack(spacing: Spacing.s) {
            statTile(
                icon: "arrow.up.circle.fill",
                iconColor: Color.bobAccent,
                value: monthlyAverage > 0
                    ? CurrencyFormatter.string(monthlyAverage, code: currencyCode)
                    : "—",
                label: "Monthly avg"
            )

            statTile(
                icon: projectedIcon,
                iconColor: projectedIconColor,
                value: projectedLabel,
                label: "Projected"
            )

            statTile(
                icon: "calendar",
                iconColor: deadlineIconColor,
                value: deadlineValue,
                label: goal.isCompleted ? "Completed" : "Days left"
            )
        }
    }

    private var projectedIcon: String {
        if goal.isCompleted { return "checkmark.circle.fill" }
        if projectedCompletionDate == nil { return "clock" }
        return isOnTrack ? "clock.fill" : "exclamationmark.circle.fill"
    }

    private var projectedIconColor: Color {
        if goal.isCompleted { return .bobAccent }
        if projectedCompletionDate == nil { return .bobInk3 }
        return isOnTrack ? .bobAccent : .bobDebit
    }

    private var projectedLabel: String {
        if goal.isCompleted { return "Done!" }
        guard let d = projectedCompletionDate else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM yy"
        return f.string(from: d)
    }

    private var deadlineValue: String {
        if goal.isCompleted { return "✓" }
        return goal.daysLeft > 0 ? "\(goal.daysLeft)d" : "Overdue"
    }

    private var deadlineIconColor: Color {
        if goal.isCompleted { return .bobAccent }
        return goal.daysLeft == 0 ? .bobDebit : .bobInk2
    }

    private func statTile(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.bobInk)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.bobInk2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: – Pace alert

    @ViewBuilder
    private var paceAlertView: some View {
        if let extra = extraNeededPerMonth {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.bobDebit)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Behind pace")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bobInk)
                    Text("Save \(CurrencyFormatter.string(extra, code: currencyCode)) more/month to hit your deadline")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bobInk2)
                }

                Spacer()
            }
            .padding(Spacing.m)
            .background(Color.bobDebit.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.bobDebit.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: – Contribution bar chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Monthly Contributions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                Spacer()
                Text("Last \(min(monthlyData.count, 6)) months")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bobInk2)
            }

            ContributionBarChart(data: monthlyData, currencyCode: currencyCode)
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – CTA

    private var addContributionButton: some View {
        Button {
            showAddContribution = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Add Contribution")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Color.bobAccent)
            .clipShape(Capsule())
        }
        .buttonStyle(ScalePress())
    }

    // MARK: – History list

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("All Contributions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bobInk)
                Spacer()
                if !contributions.isEmpty {
                    Text("\(contributions.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bobInk2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.bobHairline)
                        .clipShape(Capsule())
                }
            }

            if contributions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.bobInk3)
                    Text("No contributions yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.bobInk2)
                    Text("Tap \"Add Contribution\" to record your first deposit")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bobInk2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(contributions.enumerated()), id: \.element.id) { idx, c in
                        contributionRow(c)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteContribution(c)
                                } label: {
                                    Label("Delete Contribution", systemImage: "trash")
                                }
                            }
                        if idx < contributions.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(Color.bobSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.bobHairline, lineWidth: 1)
                )
            }
        }
    }

    private func contributionRow(_ c: GoalContribution) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.bobAccent.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: c.isAutoSurplus ? "arrow.triangle.2.circlepath" : "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bobAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(c.note?.isEmpty == false ? c.note! : "Contribution")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.bobInk)
                Text(relativeDate(c.date))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bobInk2)
            }

            Spacer()

            Text("+\(CurrencyFormatter.string(c.amount, code: currencyCode))")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.bobAccent)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, 14)
    }

    private func deleteContribution(_ c: GoalContribution) {
        goal.contributions?.removeAll { $0.id == c.id }
        modelContext.delete(c)
        try? modelContext.save()
        HapticManager.warning()
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

// MARK: – Contribution bar chart

private struct ContributionBarChart: View {
    let data: [(month: String, amount: Decimal)]
    let currencyCode: String

    private var display: [(month: String, amount: Decimal)] {
        Array(data.suffix(6))
    }

    private var maxAmount: Decimal {
        display.map { $0.amount }.max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(display, id: \.month) { item in
                VStack(spacing: 6) {
                    // Value label on tallest bar
                    if item.amount == (display.map { $0.amount }.max() ?? 0) {
                        Text(CurrencyFormatter.compact(item.amount, code: currencyCode))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.bobAccent)
                    } else {
                        Color.clear.frame(height: 14)
                    }

                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [Color.bobAccent.opacity(0.5), Color.bobAccent],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: barHeight(for: item.amount))

                    Text(monthLabel(for: item.month))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.bobInk2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    private func barHeight(for amount: Decimal) -> CGFloat {
        guard maxAmount > 0 else { return 4 }
        return max(CGFloat(Double((amount / maxAmount) as NSDecimalNumber)) * 72, 6)
    }

    private func monthLabel(for key: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: key) else { return key }
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
}

// MARK: – Button style

private struct ScalePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Goal.self, GoalContribution.self, configurations: config)

    let goal = Goal(
        name: "Emergency Fund",
        emoji: "🏠",
        targetAmount: 5000,
        deadline: Calendar.current.date(byAdding: .month, value: 6, to: Date())!
    )
    container.mainContext.insert(goal)

    let c1 = GoalContribution(amount: 500, date: Calendar.current.date(byAdding: .month, value: -2, to: Date())!)
    let c2 = GoalContribution(amount: 300, date: Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
    let c3 = GoalContribution(amount: 450, date: Date())
    c1.goal = goal; c2.goal = goal; c3.goal = goal
    container.mainContext.insert(c1)
    container.mainContext.insert(c2)
    container.mainContext.insert(c3)

    return GoalDetailView(goal: goal, currencyCode: "USD")
        .modelContainer(container)
}
