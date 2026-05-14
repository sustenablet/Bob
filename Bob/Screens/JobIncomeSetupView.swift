import SwiftUI
import SwiftData

struct JobIncomeSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JobIncomeProfile.createdAt) private var profiles: [JobIncomeProfile]

    private var profile: JobIncomeProfile? { profiles.first }
    private let weekdayRows: [(name: String, enabled: ReferenceWritableKeyPath<JobIncomeProfile, Bool>, hours: ReferenceWritableKeyPath<JobIncomeProfile, Double>)] = [
        ("Monday", \.mondayEnabled, \.mondayHours),
        ("Tuesday", \.tuesdayEnabled, \.tuesdayHours),
        ("Wednesday", \.wednesdayEnabled, \.wednesdayHours),
        ("Thursday", \.thursdayEnabled, \.thursdayHours),
        ("Friday", \.fridayEnabled, \.fridayHours),
        ("Saturday", \.saturdayEnabled, \.saturdayHours),
        ("Sunday", \.sundayEnabled, \.sundayHours)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                setupCard
                weeklySummaryCard
            }
            .padding(.horizontal, Spacing.pageMargin)
            .padding(.top, Spacing.m)
            .padding(.bottom, 40)
        }
        .background(Color.bobBackground.ignoresSafeArea())
        .navigationTitle("Job Income")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: ensureProfile)
    }

    private var setupCard: some View {
        VStack(spacing: 0) {
            rowTitle("Hourly Rate")
            HStack {
                Text("$")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
                TextField(
                    "0.00",
                    value: bindingHourlyRate,
                    format: .number.precision(.fractionLength(0...2))
                )
                .keyboardType(.decimalPad)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.bobInk)
                Spacer()
            }
            .padding(.horizontal, Spacing.m)
            .padding(.bottom, 12)

            divider

            rowTitle("Pay Cycle")
            Picker("", selection: bindingPayCycle) {
                ForEach(JobPayCycle.allCases) { cycle in
                    Text(cycle.label).tag(cycle)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.m)
            .padding(.bottom, 14)

            divider

            rowTitle("Workdays & Hours")
            VStack(spacing: 10) {
                ForEach(weekdayRows, id: \.name) { row in
                    dayRow(name: row.name, enabledPath: row.enabled, hoursPath: row.hours)
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.bottom, Spacing.m)
        }
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.bobHairline, lineWidth: 1))
    }

    private var weeklySummaryCard: some View {
        let weeklyHours = profile?.weeklyHours ?? 0
        let weeklyIncome = profile?.weeklyIncome ?? 0
        let cycle = profile?.payCycle ?? .weekly
        let projected: Decimal = {
            switch cycle {
            case .weekly: return weeklyIncome
            case .biweekly: return weeklyIncome * 2
            case .monthly: return weeklyIncome * Decimal(4.3333)
            }
        }()

        return VStack(alignment: .leading, spacing: 8) {
            Text("Projected Income")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
            Text(CurrencyFormatter.string(projected, code: "USD"))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.bobInk)
                .monospacedDigit()
            Text("\(String(format: "%.1f", weeklyHours)) hrs/week · \(cycle.label.lowercased()) payout")
                .font(.system(size: 13))
                .foregroundStyle(Color.bobInk2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.bobHairline, lineWidth: 1))
    }

    private func dayRow(name: String, enabledPath: ReferenceWritableKeyPath<JobIncomeProfile, Bool>, hoursPath: ReferenceWritableKeyPath<JobIncomeProfile, Double>) -> some View {
        HStack(spacing: 10) {
            Toggle(name, isOn: bindingBool(enabledPath))
                .toggleStyle(.switch)
                .tint(Color.bobAccent)
                .font(.system(size: 14, weight: .medium))

            Spacer()

            Stepper(
                value: bindingHours(hoursPath),
                in: 0...16,
                step: 0.5
            ) {
                Text("\(String(format: "%.1f", profile?[keyPath: hoursPath] ?? 0))h")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
                    .frame(width: 48, alignment: .trailing)
            }
            .labelsHidden()
            .disabled(!(profile?[keyPath: enabledPath] ?? false))
        }
    }

    private var bindingHourlyRate: Binding<Decimal> {
        Binding(
            get: { profile?.hourlyRate ?? 0 },
            set: { value in
                profile?.hourlyRate = max(value, 0)
                try? modelContext.save()
            }
        )
    }

    private var bindingPayCycle: Binding<JobPayCycle> {
        Binding(
            get: { profile?.payCycle ?? .weekly },
            set: { value in
                profile?.payCycle = value
                try? modelContext.save()
            }
        )
    }

    private func bindingBool(_ path: ReferenceWritableKeyPath<JobIncomeProfile, Bool>) -> Binding<Bool> {
        Binding(
            get: { profile?[keyPath: path] ?? false },
            set: { value in
                profile?[keyPath: path] = value
                try? modelContext.save()
            }
        )
    }

    private func bindingHours(_ path: ReferenceWritableKeyPath<JobIncomeProfile, Double>) -> Binding<Double> {
        Binding(
            get: { profile?[keyPath: path] ?? 0 },
            set: { value in
                profile?[keyPath: path] = max(value, 0)
                try? modelContext.save()
            }
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.bobHairline)
            .frame(height: 1)
            .padding(.bottom, 10)
    }

    private func rowTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bobInk2)
                .textCase(.uppercase)
                .tracking(0.7)
            Spacer()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func ensureProfile() {
        guard profiles.isEmpty else { return }
        modelContext.insert(JobIncomeProfile())
        try? modelContext.save()
    }
}

