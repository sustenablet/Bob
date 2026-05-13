import SwiftUI

struct PetCard: View {
    let score: PetHealthScore
    let petName: String
    let unlockedAchievements: [String]
    var statusLine: String? = nil
    var stateOverride: PetState? = nil
    var onTap: (() -> Void)? = nil

    private var displayState: PetState { stateOverride ?? score.state }

    var body: some View {
        Button { onTap?() } label: {
            HStack(spacing: Spacing.m) {
                MascotCharacterView(state: displayState, size: 72, unlockedAchievements: unlockedAchievements)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(petName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.bobInk)
                        Spacer()
                        Text("\(score.total)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(scoreColor)
                            .monospacedDigit()
                        Text("/ 100")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.bobInk3)
                    }

                    Text(moodLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bobInk2)

                    if let statusLine, !statusLine.isEmpty {
                        Text(statusLine)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.bobInk3)
                            .lineLimit(2)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.bobSurface2)
                                .frame(height: 5)
                            Capsule()
                                .fill(scoreColor)
                                .frame(width: geo.size.width * CGFloat(score.total) / 100.0, height: 5)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: score.total)
                        }
                    }
                    .frame(height: 5)

                    Text("Tap to see details")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.bobInk3)
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .glassEffect(in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var moodLabel: String {
        switch score.state {
        case .thriving:    return "Feeling fantastic!"
        case .content:     return "Doing well"
        case .neutral:     return "Getting by"
        case .worried:     return "A bit worried…"
        case .struggling:  return "Not great right now"
        case .sleeping:    return "Fast asleep…"
        case .celebrating: return "Celebrating!"
        }
    }

    private var scoreColor: Color {
        switch score.total {
        case 80...100: return Color.bobHex(0x00A87E)
        case 60..<80:  return Color.bobHex(0x1A73E8)
        case 40..<60:  return Color.bobInk2
        case 20..<40:  return Color.bobHex(0xFF8A65)
        default:       return Color.bobDebit
        }
    }
}
