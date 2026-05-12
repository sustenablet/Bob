import SwiftUI

struct AchievementBanner: View {
    let achievementID: String
    var onDismiss: () -> Void

    @State private var timer: Timer? = nil

    private var achievement: AchievementDefinition? { AchievementDefinition.find(achievementID) }

    var body: some View {
        VStack(spacing: 0) {
            if let achievement {
                HStack(spacing: Spacing.m) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: achievement.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Achievement Unlocked")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .tracking(0.5)
                        Text(achievement.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Button {
                        timer?.invalidate()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.vertical, Spacing.m)
                .background(Color.bobAccent)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0, bottomLeadingRadius: 20,
                        bottomTrailingRadius: 20, topTrailingRadius: 0
                    )
                )
                .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onAppear {
            HapticManager.success()
            timer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
                onDismiss()
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}
