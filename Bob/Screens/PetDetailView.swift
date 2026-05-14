import SwiftUI

struct PetDetailView: View {
    let score: PetHealthScore
    let petName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bobBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // Creature display
                        VStack(spacing: Spacing.m) {
                            MascotCharacterView(
                                state: score.state,
                                size: 110
                            )

                            VStack(spacing: 4) {
                                Text(petName)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color.bobInk)
                                Text(stateDescription)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.bobInk2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 280)
                            }
                        }
                        .padding(.top, Spacing.l)

                        if let nextMilestoneText {
                            insightCard(nextMilestoneText)
                        }

                        // Score breakdown
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("HEALTH BREAKDOWN")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.bobInk2)
                                .tracking(0.8)
                                .padding(.horizontal, Spacing.pageMargin)

                            VStack(spacing: 0) {
                                scoreRow(
                                    label: "Budget",
                                    detail: budgetDetail,
                                    points: score.budgetPoints,
                                    maxPoints: 70,
                                    icon: "chart.bar.fill",
                                    color: budgetColor
                                )
                                Divider().background(Color.bobHairline).padding(.leading, 56)

                                scoreRow(
                                    label: "Savings Goals",
                                    detail: savingsDetail,
                                    points: score.savingsPoints,
                                    maxPoints: 30,
                                    icon: "target",
                                    color: Color.bobHex(0xBA68C8)
                                )
                            }
                            .background(Color.bobSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                    .stroke(Color.bobHairline, lineWidth: 0.5)
                            )
                            .padding(.horizontal, Spacing.pageMargin)
                        }

                        // Total score ring
                        VStack(spacing: Spacing.s) {
                            ZStack {
                                Circle()
                                    .stroke(Color.bobSurface2, lineWidth: 10)
                                    .frame(width: 100, height: 100)
                                Circle()
                                    .trim(from: 0, to: CGFloat(score.total) / 100)
                                    .stroke(totalScoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                    .frame(width: 100, height: 100)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: score.total)
                                VStack(spacing: 0) {
                                    Text("\(score.total)")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(Color.bobInk)
                                        .monospacedDigit()
                                    Text("/ 100")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.bobInk2)
                                }
                            }
                            Text("Overall Health Score")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.bobInk2)
                        }
                        .padding(.bottom, Spacing.xxl)
                    }
                }
            }
            .navigationTitle("\(petName)'s Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.bobAccent)
                }
            }
        }
    }

    private func insightCard(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.bobAccent)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.bobInk2)
            Spacer()
        }
        .padding(Spacing.m)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(Color.bobHairline, lineWidth: 1))
        .padding(.horizontal, Spacing.pageMargin)
    }

    // MARK: – Score row

    private func scoreRow(label: String, detail: String, points: Int, maxPoints: Int, icon: String, color: Color) -> some View {
        HStack(spacing: Spacing.m) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.bobInk)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bobInk2)
            }

            Spacer()

            Text("\(points)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text("/ \(maxPoints)")
                .font(.system(size: 12))
                .foregroundStyle(Color.bobInk3)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
    }

    // MARK: – Computed labels

    private var stateDescription: String {
        switch score.state {
        case .thriving:   return "Everything is looking great — keep it up!"
        case .content:    return "Things are going well. Nice work."
        case .neutral:    return "Doing okay. A few things to work on."
        case .worried:    return "A little stressed. Check your budget or goals."
        case .struggling: return "Feeling rough. Your finances need some attention."
        case .sleeping:   return "Waiting for you to come back…"
        case .celebrating: return "Just unlocked something — woo!"
        }
    }

    private var budgetDetail: String {
        let pct = Int(Double(score.budgetPoints) / 40.0 * 100)
        if score.budgetPoints == 20 { return "No budget set" }
        return "\(pct)% of budget remaining"
    }

    private var savingsDetail: String {
        if score.savingsPoints == 10 { return "No active goals" }
        let pct = Int(Double(score.savingsPoints) / 20.0 * 100)
        return "\(pct)% of goals on track"
    }

    private var budgetColor: Color {
        switch score.budgetPoints {
        case 28...40: return Color.bobGreen
        case 12..<28: return Color.bobHex(0xFF8A65)
        default:      return Color.bobDebit
        }
    }

    private var totalScoreColor: Color {
        switch score.total {
        case 80...100: return Color.bobHex(0x00A87E)
        case 60..<80:  return Color.bobHex(0x1A73E8)
        case 40..<60:  return Color.bobInk2
        case 20..<40:  return Color.bobHex(0xFF8A65)
        default:       return Color.bobDebit
        }
    }

    private var nextMilestoneText: String? {
        "Your companion responds to budget room and savings progress."
    }
}
