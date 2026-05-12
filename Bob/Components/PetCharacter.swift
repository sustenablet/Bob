import SwiftUI

struct PetCharacter: View {
    let state: PetState
    var size: CGFloat = 80
    var unlockedAchievements: [String] = []

    @State private var bounceOffset: CGFloat = 0
    @State private var breathScale: CGFloat = 1.0
    @State private var jitterOffset: CGFloat = 0
    @State private var blinkClosed = false
    @State private var blinkTask: Task<Void, Never>? = nil
    @State private var zzzTask: Task<Void, Never>? = nil
    @State private var celebrateScale: CGFloat = 1.0
    @State private var zzzOpacity: Double = 0
    @State private var zzzOffset: CGFloat = 0
    @State private var confettiVisible = false

    var body: some View {
        ZStack {
            // Confetti (celebrating only)
            if confettiVisible {
                ConfettiBurst(size: size)
            }

            // Creature body
            ZStack {
                creatureBody
                    .offset(y: bounceOffset)
                    .scaleEffect(breathScale * celebrateScale)
                    .offset(x: jitterOffset)

                // Accessories stacked on top
                accessoryLayer
                    .offset(y: bounceOffset)
                    .scaleEffect(breathScale * celebrateScale)
            }

            // Sleeping ZZZ
            if state == .sleeping {
                Text("z z z")
                    .font(.system(size: size * 0.14, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
                    .opacity(zzzOpacity)
                    .offset(x: size * 0.3, y: -size * 0.3 + zzzOffset)
            }
        }
        .frame(width: size * 1.4, height: size * 1.4)
        .onChange(of: state, initial: true) { _, newState in
            stopAllAnimations()
            startAnimations(for: newState)
        }
    }

    // MARK: – Body drawing

    private var creatureBody: some View {
        ZStack {
            // Main body ellipse
            Ellipse()
                .fill(bodyColor)
                .frame(width: size * 0.78, height: size * 0.88)

            // Cheeks (thriving / content only)
            if state == .thriving || state == .content {
                HStack(spacing: size * 0.34) {
                    Circle()
                        .fill(Color.pink.opacity(0.25))
                        .frame(width: size * 0.18, height: size * 0.18)
                    Circle()
                        .fill(Color.pink.opacity(0.25))
                        .frame(width: size * 0.18, height: size * 0.18)
                }
                .offset(y: size * 0.12)
            }

            // Eyes
            HStack(spacing: size * 0.18) {
                eyeView(isLeft: true)
                eyeView(isLeft: false)
            }
            .offset(y: -size * 0.06)

            // Brows
            HStack(spacing: size * 0.18) {
                browView(isLeft: true)
                browView(isLeft: false)
            }
            .offset(y: -size * 0.22)

            // Mouth
            mouthPath
                .offset(y: size * 0.22)
        }
    }

    private var bodyColor: Color {
        switch state {
        case .thriving:    return Color.bobHex(0xC8F0D8)
        case .content:     return Color.bobHex(0xDFF0FF)
        case .neutral:     return Color.bobHex(0xEEEEEE)
        case .worried:     return Color.bobHex(0xFFF3CC)
        case .struggling:  return Color.bobHex(0xFFDDDD)
        case .sleeping:    return Color.bobHex(0xE8E8F0)
        case .celebrating: return Color.bobHex(0xFFF3B0)
        }
    }

    // MARK: – Eyes

    @ViewBuilder
    private func eyeView(isLeft: Bool) -> some View {
        let eyeSize = size * 0.17
        ZStack {
            // White sclera
            Circle()
                .fill(Color.white)
                .frame(width: eyeSize, height: eyeSize)

            switch state {
            case .thriving, .celebrating:
                // Star pupils
                Image(systemName: "star.fill")
                    .font(.system(size: eyeSize * 0.55))
                    .foregroundStyle(Color.bobInk)

            case .sleeping:
                // Closed arc
                Path { p in
                    p.addArc(center: CGPoint(x: eyeSize / 2, y: eyeSize / 2),
                             radius: eyeSize * 0.35,
                             startAngle: .degrees(0),
                             endAngle: .degrees(180),
                             clockwise: false)
                }
                .stroke(Color.bobInk, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: eyeSize, height: eyeSize)

            case .struggling:
                // Downward arc pupils (sad eyes)
                ZStack {
                    if !blinkClosed {
                        Circle()
                            .fill(Color.bobInk)
                            .frame(width: eyeSize * 0.5, height: eyeSize * 0.5)
                            .offset(y: eyeSize * 0.08)
                    }
                }

            default:
                // Normal round pupils, with blink
                if !blinkClosed {
                    Circle()
                        .fill(Color.bobInk)
                        .frame(width: eyeSize * 0.55, height: eyeSize * 0.55)
                }
            }
        }
    }

    // MARK: – Brows

    @ViewBuilder
    private func browView(isLeft: Bool) -> some View {
        let w = size * 0.15
        let h: CGFloat = 2.5
        let angle: Double = {
            switch state {
            case .worried:    return isLeft ?  15 : -15
            case .struggling: return isLeft ?  20 : -20
            default:          return 0
            }
        }()
        Capsule()
            .fill(Color.bobInk.opacity(0.7))
            .frame(width: w, height: h)
            .rotationEffect(.degrees(angle))
    }

    // MARK: – Mouth

    private var mouthPath: some View {
        let w = size * 0.28
        let h = size * 0.1

        return Canvas { ctx, _ in
            var path = Path()
            switch state {
            case .thriving, .celebrating:
                // Big smile
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(to: CGPoint(x: w, y: 0),
                                  control: CGPoint(x: w / 2, y: h * 1.6))
            case .content:
                // Gentle smile
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(to: CGPoint(x: w, y: 0),
                                  control: CGPoint(x: w / 2, y: h * 0.9))
            case .neutral, .sleeping:
                // Flat line
                path.move(to: CGPoint(x: 0, y: h * 0.2))
                path.addLine(to: CGPoint(x: w, y: h * 0.2))
            case .worried:
                // Slight frown
                path.move(to: CGPoint(x: 0, y: h * 0.5))
                path.addQuadCurve(to: CGPoint(x: w, y: h * 0.5),
                                  control: CGPoint(x: w / 2, y: -h * 0.4))
            case .struggling:
                // Deeper frown
                path.move(to: CGPoint(x: 0, y: h))
                path.addQuadCurve(to: CGPoint(x: w, y: h),
                                  control: CGPoint(x: w / 2, y: -h * 0.6))
            }
            ctx.stroke(path,
                       with: .color(Color.bobInk.opacity(0.8)),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
        .frame(width: w, height: h * 2)
    }

    // MARK: – Accessories

    @ViewBuilder
    private var accessoryLayer: some View {
        ZStack {
            // Crown (streak_30 / Month Master)
            if unlockedAchievements.contains("streak_30") {
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.22))
                    .foregroundStyle(Color.bobHex(0xFFCC00))
                    .offset(y: -size * 0.52)
            } else if unlockedAchievements.contains("streak_7") {
                // Star (streak_7)
                Image(systemName: "star.fill")
                    .font(.system(size: size * 0.18))
                    .foregroundStyle(Color.bobHex(0xFFCC00))
                    .offset(y: -size * 0.52)
            }

            // Shield badge (budget_hero)
            if unlockedAchievements.contains("budget_hero") {
                Image(systemName: "shield.fill")
                    .font(.system(size: size * 0.16))
                    .foregroundStyle(Color.bobHex(0x1A73E8))
                    .offset(x: size * 0.32, y: size * 0.05)
            }

            // Gold coin (goal_complete)
            if unlockedAchievements.contains("goal_complete") {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: size * 0.16))
                    .foregroundStyle(Color.bobHex(0xFFAA00))
                    .offset(x: -size * 0.36, y: size * 0.1)
            }

            // Laurel (tx_100)
            if unlockedAchievements.contains("tx_100") {
                Image(systemName: "laurel.leading")
                    .font(.system(size: size * 0.14))
                    .foregroundStyle(Color.bobHex(0x588157))
                    .offset(x: -size * 0.42, y: -size * 0.12)
            }
        }
    }

    // MARK: – Animation control

    private func stopAllAnimations() {
        blinkTask?.cancel()
        blinkTask = nil
        zzzTask?.cancel()
        zzzTask = nil
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            bounceOffset = 0
            breathScale = 1.0
            jitterOffset = 0
            zzzOpacity = 0
            zzzOffset = 0
            confettiVisible = false
            celebrateScale = 1.0
            blinkClosed = false
        }
    }

    private func startAnimations(for newState: PetState) {
        switch newState {
        case .thriving:
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                bounceOffset = -6
            }

        case .content:
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breathScale = 1.025
            }
            scheduleBlink()

        case .neutral:
            scheduleBlink()

        case .worried:
            withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                jitterOffset = 3
            }

        case .struggling:
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathScale = 0.97
            }

        case .sleeping:
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breathScale = 1.02
            }
            animateZzz()

        case .celebrating:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                celebrateScale = 1.2
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.15)) {
                celebrateScale = 1.0
            }
            withAnimation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true).delay(0.1)) {
                bounceOffset = -10
            }
            confettiVisible = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                await MainActor.run { confettiVisible = false }
            }
        }
    }

    private func scheduleBlink() {
        blinkTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.5...5.0)))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    withAnimation(.linear(duration: 0.08)) { blinkClosed = true }
                }
                try? await Task.sleep(for: .seconds(0.12))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    withAnimation(.linear(duration: 0.08)) { blinkClosed = false }
                }
            }
        }
    }

    private func animateZzz() {
        zzzTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    zzzOffset = 0
                    zzzOpacity = 0
                }
                try? await Task.sleep(for: .seconds(0.3))
                await MainActor.run {
                    withAnimation(.easeOut(duration: 1.8)) {
                        zzzOpacity = 0.7
                        zzzOffset = -size * 0.25
                    }
                }
                try? await Task.sleep(for: .seconds(1.8))
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.4)) { zzzOpacity = 0 }
                }
                try? await Task.sleep(for: .seconds(1.0))
            }
        }
    }
}

// MARK: – Confetti burst

private struct ConfettiBurst: View {
    let size: CGFloat
    @State private var particles: [ConfettiParticle] = ConfettiParticle.generate(count: 12)

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: 6, height: 6)
                    .offset(x: p.x, y: p.y)
                    .opacity(p.opacity)
            }
        }
        .onAppear {
            for i in particles.indices {
                withAnimation(.easeOut(duration: 0.9).delay(Double(i) * 0.04)) {
                    particles[i].x = particles[i].targetX
                    particles[i].y = particles[i].targetY
                    particles[i].opacity = 0
                }
            }
        }
        .frame(width: size * 1.4, height: size * 1.4)
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    var x: CGFloat = 0
    var y: CGFloat = 0
    var opacity: Double = 1
    let targetX: CGFloat
    let targetY: CGFloat

    static func generate(count: Int) -> [ConfettiParticle] {
        let colors: [Color] = [.yellow, .orange, .pink, .green, .blue, .purple]
        return (0..<count).map { i in
            let angle = Double(i) / Double(count) * 2 * .pi
            let dist = CGFloat.random(in: 28...52)
            return ConfettiParticle(
                color: colors[i % colors.count],
                targetX: cos(angle) * dist,
                targetY: sin(angle) * dist
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            PetCharacter(state: .thriving, size: 70)
            PetCharacter(state: .content, size: 70)
            PetCharacter(state: .neutral, size: 70)
        }
        HStack(spacing: 20) {
            PetCharacter(state: .worried, size: 70)
            PetCharacter(state: .struggling, size: 70)
            PetCharacter(state: .sleeping, size: 70)
        }
        PetCharacter(state: .celebrating, size: 70)
    }
    .padding()
    .background(Color.bobBackground)
}
