import SwiftUI
import SwiftData

struct MoreView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: [SortDescriptor(\Expense.date, order: .reverse),
                  SortDescriptor(\Expense.createdAt, order: .reverse)])
    private var allExpenses: [Expense]
    @Query(sort: \BudgetSettings.monthlyBudget) private var settingsList: [BudgetSettings]

    @AppStorage("userName") private var userName: String = ""
    private var currencyCode: String { settingsList.first?.currencyCode ?? "USD" }
    private var activeGoals: [Goal] { goals.filter { $0.isActive && !$0.isCompleted } }
    private var totalThisMonth: Decimal {
        let b = MonthSummary.currentMonthBounds()
        return allExpenses
            .filter { $0.kind == .expense && $0.date >= b.start && $0.date <= b.end }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bobBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        profileHeader
                        statsStrip
                        myAppSection
                        preferencesSection
                        appInfoSection
                    }
                    .padding(.horizontal, Spacing.pageMargin)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, 120)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: – Profile header

    private var profileHeader: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.bobAccent.opacity(0.2))
                    .frame(width: 56, height: 56)
                Text(avatarLetter)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.bobAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(userName.isEmpty ? "Hey there" : "Hey, \(firstName)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.bobInk)
                Text("Your financial hub")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bobInk2)
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private var avatarLetter: String {
        userName.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "B"
    }

    private var firstName: String {
        userName.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? userName
    }

    // MARK: – Stats strip

    private var statsStrip: some View {
        HStack(spacing: 10) {
            moreStatTile(
                value: "\(allExpenses.count)",
                label: "Transactions",
                icon: "list.bullet.rectangle",
                color: Color.bobChartBlue
            )
            moreStatTile(
                value: "\(activeGoals.count)",
                label: "Active Goals",
                icon: "target",
                color: Color.bobAccent
            )
            moreStatTile(
                value: CurrencyFormatter.compact(totalThisMonth, code: currencyCode),
                label: "This Month",
                icon: "calendar",
                color: Color.bobGreen
            )
        }
    }

    private func moreStatTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.bobInk)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.bobInk2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.bobSurface.opacity(0.8))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }
        }
    }

    // MARK: – My App section

    private var myAppSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("MY APP")

            VStack(spacing: 0) {
                NavigationLink(destination: GoalsView()) {
                    moreRow(
                        icon: "target",
                        iconColor: Color.bobAccent,
                        label: "Savings Goals",
                        badge: activeGoals.isEmpty ? nil : "\(activeGoals.count)"
                    )
                }
                .buttonStyle(.plain)

                divider

                NavigationLink(destination: TransactionsListView()) {
                    moreRow(
                        icon: "list.bullet.rectangle",
                        iconColor: Color.bobChartBlue,
                        label: "All Transactions",
                        badge: allExpenses.isEmpty ? nil : "\(allExpenses.count)"
                    )
                }
                .buttonStyle(.plain)
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.bobSurface.opacity(0.8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: – Preferences section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("PREFERENCES")

            VStack(spacing: 0) {
                NavigationLink(destination: SettingsView()) {
                    moreRow(
                        icon: "gearshape.fill",
                        iconColor: Color.bobInk2,
                        label: "Settings",
                        badge: nil
                    )
                }
                .buttonStyle(.plain)
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.bobSurface.opacity(0.8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: – App info

    private var appInfoSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.bobAccent)
            Text("Bob")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.bobInk)
            Text("Personal finance, simplified")
                .font(.system(size: 12))
                .foregroundStyle(Color.bobInk3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: – Helpers

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 56)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.bobInk2)
            .tracking(0.8)
            .padding(.horizontal, 2)
    }

    private func moreRow(icon: String, iconColor: Color, label: String, badge: String?) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.bobInk)

            Spacer()

            if let badge = badge {
                Text(badge)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.bobSurface2)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bobInk3)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
