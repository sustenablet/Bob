import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query private var statsList: [UserStats]
    @Environment(\.dismiss) private var dismiss

    private var stats: UserStats? { statsList.first }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bobBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.l) {
                        streakSummary
                        achievementGrid
                    }
                    .padding(.horizontal, Spacing.pageMargin)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.bobAccent)
                }
            }
        }
    }

    // MARK: – Streak summary card

    private var streakSummary: some View {
        HStack(spacing: 0) {
            streakStat(value: stats?.currentStreak ?? 0, label: "Current streak", emoji: "🔥")
            Divider().frame(height: 40).padding(.horizontal, Spacing.m)
            streakStat(value: stats?.longestStreak ?? 0, label: "Longest streak", emoji: "⚡")
            Divider().frame(height: 40).padding(.horizontal, Spacing.m)
            streakStat(value: stats?.totalLogged ?? 0, label: "Total logged", emoji: "📋")
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(Color.bobHairline, lineWidth: 1))
    }

    private func streakStat(value: Int, label: String, emoji: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(emoji).font(.system(size: 16))
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.bobInk)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.bobInk2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Achievement grid

    private var achievementGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("BADGES")
                .eyebrow()

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AchievementDefinition.all) { achievement in
                    achievementCard(achievement)
                }
            }
        }
    }

    private func achievementCard(_ achievement: AchievementDefinition) -> some View {
        let isUnlocked = stats?.earnedAchievementIDs.contains(achievement.id) ?? false

        return VStack(spacing: Spacing.s) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? Color.bobAccent : Color.bobSurface3)
                        .frame(width: 52, height: 52)
                    Image(systemName: achievement.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isUnlocked ? .white : Color.bobInk3)
                }

                if isUnlocked {
                    ZStack {
                        Circle().fill(Color.bobGreen).frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: -4)
                }
            }

            VStack(spacing: 3) {
                Text(achievement.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isUnlocked ? Color.bobInk : Color.bobInk3)
                    .multilineTextAlignment(.center)
                Text(achievement.description)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.bobInk3)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity)
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(
                    isUnlocked ? Color.bobAccent.opacity(0.2) : Color.bobHairline,
                    style: StrokeStyle(lineWidth: 1, dash: isUnlocked ? [] : [4, 3])
                )
        )
    }
}
