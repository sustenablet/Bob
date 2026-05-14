import SwiftUI

struct PetCharacter: View {
    let state: PetState
    var size: CGFloat = 80

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
    @State private var handLift: CGFloat = 0
    @State private var legSpread: CGFloat = 0
    @State private var bodyTilt: Double = 0
    @State private var eyeDrift: CGFloat = 0

    var body: some View {
        ZStack {
            if confettiVisible {
                ConfettiBurst(size: size)
            }

            frogBody
                .offset(y: bounceOffset)
                .scaleEffect(breathScale * celebrateScale)
                .offset(x: jitterOffset)
                .rotationEffect(.degrees(bodyTilt))

            if state == .sleeping {
                Text("z z z")
                    .font(.system(size: size * 0.14, weight: .semibold))
                    .foregroundStyle(Color.bobInk2)
                    .opacity(zzzOpacity)
                    .offset(x: size * 0.34, y: -size * 0.48 + zzzOffset)
            }
        }
        .frame(width: size * 1.55, height: size * 1.6)
        .drawingGroup()
        .onChange(of: state, initial: true) { _, newState in
            stopAllAnimations()
            startAnimations(for: newState)
        }
    }

    private var frogBody: some View {
        ZStack {
            shadowLayer
            legsLayer
            armsLayer
            torsoLayer
            faceLayer
        }
    }

    private var shadowLayer: some View {
        Ellipse()
            .fill(Color.black.opacity(0.1))
            .frame(width: size * 0.92, height: size * 0.18)
            .blur(radius: 6)
            .offset(y: size * 0.56)
    }

    private var torsoLayer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [bodyHighlightColor, bodyColor, bodyShadeColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.86, height: size * 0.94)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [bellyTopColor, bellyBottomColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.48, height: size * 0.58)
                .offset(y: size * 0.16)

            frogSpots
        }
        .offset(y: size * 0.06)
    }

    private var frogSpots: some View {
        ZStack {
            Circle()
                .fill(spotColor.opacity(0.6))
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: -size * 0.2, y: -size * 0.02)
            Circle()
                .fill(spotColor.opacity(0.45))
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: size * 0.22, y: size * 0.08)
            Circle()
                .fill(spotColor.opacity(0.35))
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(x: size * 0.14, y: -size * 0.18)
        }
    }

    private var legsLayer: some View {
        ZStack {
            frogLeg(isLeft: true)
            frogLeg(isLeft: false)
        }
        .offset(y: size * 0.31)
    }

    private func frogLeg(isLeft: Bool) -> some View {
        let direction: CGFloat = isLeft ? -1 : 1
        return ZStack {
            Ellipse()
                .fill(bodyShadeColor)
                .frame(width: size * 0.28, height: size * 0.2)
                .rotationEffect(.degrees(Double(direction) * (25 + legRotation)))
                .offset(x: direction * size * 0.22, y: size * 0.03)

            Ellipse()
                .fill(bodyColor)
                .frame(width: size * 0.26, height: size * 0.16)
                .rotationEffect(.degrees(Double(direction) * (10 + legRotation * 0.6)))
                .offset(x: direction * size * 0.3, y: size * 0.12)

            frogFoot(isLeft: isLeft)
                .offset(x: direction * (size * 0.35 + legSpread), y: size * 0.17)
        }
    }

    private func frogFoot(isLeft: Bool) -> some View {
        let direction: CGFloat = isLeft ? -1 : 1
        return ZStack {
            Ellipse()
                .fill(bodyHighlightColor)
                .frame(width: size * 0.18, height: size * 0.1)
            HStack(spacing: size * 0.01) {
                toePad
                toePad
                toePad
            }
            .offset(y: size * 0.04)
        }
        .rotationEffect(.degrees(Double(direction) * -8))
    }

    private var toePad: some View {
        Circle()
            .fill(bellyTopColor.opacity(0.95))
            .frame(width: size * 0.04, height: size * 0.04)
    }

    private var armsLayer: some View {
        ZStack {
            frogArm(isLeft: true)
            frogArm(isLeft: false)
        }
        .offset(y: size * 0.03)
    }

    private func frogArm(isLeft: Bool) -> some View {
        let direction: CGFloat = isLeft ? -1 : 1
        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(bodyShadeColor)
                .frame(width: size * 0.16, height: size * 0.34)
                .rotationEffect(.degrees(Double(direction) * handAngle))
                .offset(x: direction * size * 0.34, y: handLift)

            frogHand
                .offset(x: direction * size * 0.39, y: size * 0.12 + handLift)
        }
    }

    private var frogHand: some View {
        HStack(spacing: size * 0.015) {
            Circle().fill(bellyTopColor).frame(width: size * 0.035, height: size * 0.035)
            Circle().fill(bellyTopColor).frame(width: size * 0.035, height: size * 0.035)
            Circle().fill(bellyTopColor).frame(width: size * 0.035, height: size * 0.035)
        }
    }

    private var faceLayer: some View {
        ZStack {
            eyeBumps
            cheeks
            brows
            eyes
            noseDots
            mouthView
        }
        .offset(y: -size * 0.1)
    }

    private var eyeBumps: some View {
        HStack(spacing: size * 0.22) {
            eyeBump
            eyeBump
        }
        .offset(y: -size * 0.19)
    }

    private var eyeBump: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [bodyHighlightColor, bodyColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.28, height: size * 0.28)
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                .frame(width: size * 0.28, height: size * 0.28)
        }
    }

    @ViewBuilder
    private var cheeks: some View {
        if state == .thriving || state == .content || state == .celebrating {
            HStack(spacing: size * 0.35) {
                Circle()
                    .fill(Color.pink.opacity(0.22))
                    .frame(width: size * 0.16, height: size * 0.16)
                Circle()
                    .fill(Color.pink.opacity(0.22))
                    .frame(width: size * 0.16, height: size * 0.16)
            }
            .offset(y: size * 0.07)
        }
    }

    private var brows: some View {
        HStack(spacing: size * 0.26) {
            brow(isLeft: true)
            brow(isLeft: false)
        }
        .offset(y: -size * 0.24)
    }

    private func brow(isLeft: Bool) -> some View {
        let angle: Double = {
            switch state {
            case .worried: return isLeft ? 14 : -14
            case .struggling: return isLeft ? 20 : -20
            default: return 0
            }
        }()

        return Capsule()
            .fill(Color.bobInk.opacity(0.7))
            .frame(width: size * 0.14, height: size * 0.025)
            .rotationEffect(.degrees(angle))
    }

    private var eyes: some View {
        HStack(spacing: size * 0.22) {
            eyeView
            eyeView
        }
        .offset(x: eyeDrift, y: -size * 0.14)
    }

    @ViewBuilder
    private var eyeView: some View {
        let eyeSize = size * 0.17
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: eyeSize, height: eyeSize)

            switch state {
            case .thriving, .celebrating:
                Image(systemName: "star.fill")
                    .font(.system(size: eyeSize * 0.52))
                    .foregroundStyle(Color.bobInk)
            case .sleeping:
                Path { path in
                    path.move(to: CGPoint(x: eyeSize * 0.18, y: eyeSize * 0.56))
                    path.addQuadCurve(
                        to: CGPoint(x: eyeSize * 0.82, y: eyeSize * 0.56),
                        control: CGPoint(x: eyeSize * 0.5, y: eyeSize * 0.22)
                    )
                }
                .stroke(Color.bobInk, style: StrokeStyle(lineWidth: 2.1, lineCap: .round))
                .frame(width: eyeSize, height: eyeSize)
            default:
                if blinkClosed {
                    Capsule()
                        .fill(Color.bobInk)
                        .frame(width: eyeSize * 0.62, height: eyeSize * 0.08)
                } else {
                    Circle()
                        .fill(Color.bobInk)
                        .frame(
                            width: state == .struggling ? eyeSize * 0.42 : eyeSize * 0.52,
                            height: state == .struggling ? eyeSize * 0.42 : eyeSize * 0.52
                        )
                        .offset(y: state == .struggling ? eyeSize * 0.08 : 0)
                }
            }
        }
    }

    private var noseDots: some View {
        HStack(spacing: size * 0.05) {
            Circle().fill(Color.bobInk.opacity(0.42)).frame(width: size * 0.018, height: size * 0.018)
            Circle().fill(Color.bobInk.opacity(0.42)).frame(width: size * 0.018, height: size * 0.018)
        }
        .offset(y: -size * 0.01)
    }

    private var mouthView: some View {
        FrogMouthShape(state: state)
            .stroke(Color.bobInk.opacity(0.82), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            .frame(width: size * 0.33, height: size * 0.15)
            .offset(y: size * 0.14)
    }

    private var bodyColor: Color {
        switch state {
        case .thriving: return Color.bobHex(0x79C77B)
        case .content: return Color.bobHex(0x8DC68A)
        case .neutral: return Color.bobHex(0x97B48C)
        case .worried: return Color.bobHex(0xA9AF76)
        case .struggling: return Color.bobHex(0x9B9687)
        case .sleeping: return Color.bobHex(0x8F9CAD)
        case .celebrating: return Color.bobHex(0x8BCF67)
        }
    }

    private var bodyHighlightColor: Color {
        switch state {
        case .thriving: return Color.bobHex(0xA9E4A4)
        case .content: return Color.bobHex(0xB5DDAE)
        case .neutral: return Color.bobHex(0xB9C8AE)
        case .worried: return Color.bobHex(0xC3C783)
        case .struggling: return Color.bobHex(0xB4A99D)
        case .sleeping: return Color.bobHex(0xB1BACC)
        case .celebrating: return Color.bobHex(0xC3EA8C)
        }
    }

    private var bodyShadeColor: Color {
        switch state {
        case .thriving: return Color.bobHex(0x4F9953)
        case .content: return Color.bobHex(0x638F5E)
        case .neutral: return Color.bobHex(0x647667)
        case .worried: return Color.bobHex(0x878754)
        case .struggling: return Color.bobHex(0x766E66)
        case .sleeping: return Color.bobHex(0x69758A)
        case .celebrating: return Color.bobHex(0x67AF45)
        }
    }

    private var bellyTopColor: Color {
        switch state {
        case .struggling: return Color.bobHex(0xEFE1D4)
        case .sleeping: return Color.bobHex(0xF0E6DE)
        default: return Color.bobHex(0xF6E8D6)
        }
    }

    private var bellyBottomColor: Color {
        switch state {
        case .struggling: return Color.bobHex(0xDFC9B5)
        case .sleeping: return Color.bobHex(0xDED3C7)
        default: return Color.bobHex(0xE8D0B3)
        }
    }

    private var spotColor: Color {
        switch state {
        case .thriving, .celebrating: return Color.bobHex(0x4C8A4E)
        case .content: return Color.bobHex(0x5A8153)
        case .neutral: return Color.bobHex(0x68745C)
        case .worried: return Color.bobHex(0x87814C)
        case .struggling: return Color.bobHex(0x6D645D)
        case .sleeping: return Color.bobHex(0x6D788B)
        }
    }

    private var legRotation: CGFloat {
        switch state {
        case .celebrating, .thriving: return 8
        case .worried: return -3
        case .struggling: return -5
        default: return 0
        }
    }

    private var handAngle: Double {
        switch state {
        case .celebrating: return 30
        case .thriving: return 18
        case .worried: return 8
        case .struggling: return 4
        default: return 12
        }
    }

    private func stopAllAnimations() {
        blinkTask?.cancel()
        blinkTask = nil
        zzzTask?.cancel()
        zzzTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            bounceOffset = 0
            breathScale = 1.0
            jitterOffset = 0
            zzzOpacity = 0
            zzzOffset = 0
            confettiVisible = false
            celebrateScale = 1.0
            blinkClosed = false
            handLift = 0
            legSpread = 0
            bodyTilt = 0
            eyeDrift = 0
        }
    }

    private func startAnimations(for newState: PetState) {
        switch newState {
        case .thriving:
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                bounceOffset = -7
                handLift = -3
                bodyTilt = -2
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                legSpread = 4
                eyeDrift = 2
            }
            scheduleBlink()

        case .content:
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathScale = 1.028
                handLift = -1
            }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                eyeDrift = 1.5
            }
            scheduleBlink()

        case .neutral:
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                breathScale = 1.012
                bodyTilt = 1.2
            }
            scheduleBlink()

        case .worried:
            withAnimation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true)) {
                jitterOffset = 2.5
                eyeDrift = -2
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                handLift = 3
                bodyTilt = -1.5
            }
            scheduleBlink()

        case .struggling:
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathScale = 0.975
                handLift = 4
            }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                bodyTilt = -3
            }
            scheduleBlink()

        case .sleeping:
            withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
                breathScale = 1.025
                handLift = 2
            }
            animateZzz()

        case .celebrating:
            withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) {
                celebrateScale = 1.18
                handLift = -10
                legSpread = 10
            }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.56).delay(0.14)) {
                celebrateScale = 1.0
                handLift = -2
            }
            withAnimation(.easeInOut(duration: 0.45).repeatCount(4, autoreverses: true)) {
                bounceOffset = -12
                bodyTilt = 4
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
                try? await Task.sleep(for: .seconds(Double.random(in: 2.3...4.8)))
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

private struct FrogMouthShape: Shape {
    let state: PetState

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch state {
        case .thriving, .celebrating:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY - rect.height * 0.05))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.05),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )
        case .content:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.48)
            )
        case .neutral, .sleeping:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.08))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + rect.height * 0.08))
        case .worried:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.12))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY + rect.height * 0.12),
                control: CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.4)
            )
        case .struggling:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.08))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.08),
                control: CGPoint(x: rect.midX, y: rect.minY)
            )
        }

        return path
    }
}

private struct ConfettiBurst: View {
    let size: CGFloat
    @State private var particles: [ConfettiParticle] = ConfettiParticle.generate(count: 14)

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(particle.color)
                    .frame(width: 7, height: 7)
                    .rotationEffect(.degrees(particle.rotation))
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }
        }
        .onAppear {
            for index in particles.indices {
                withAnimation(.easeOut(duration: 0.9).delay(Double(index) * 0.035)) {
                    particles[index].x = particles[index].targetX
                    particles[index].y = particles[index].targetY
                    particles[index].opacity = 0
                    particles[index].rotation = 180
                }
            }
        }
        .frame(width: size * 1.55, height: size * 1.6)
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    var x: CGFloat = 0
    var y: CGFloat = 0
    var opacity: Double = 1
    var rotation: Double = 0
    let targetX: CGFloat
    let targetY: CGFloat

    static func generate(count: Int) -> [ConfettiParticle] {
        let colors: [Color] = [.yellow, .orange, .pink, .green, .blue, .mint]
        return (0..<count).map { index in
            let angle = Double(index) / Double(count) * 2 * .pi
            let distance = CGFloat.random(in: 28...56)
            return ConfettiParticle(
                color: colors[index % colors.count],
                targetX: cos(angle) * distance,
                targetY: sin(angle) * distance
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            PetCharacter(state: .thriving, size: 80)
            PetCharacter(state: .content, size: 80)
            PetCharacter(state: .neutral, size: 80)
        }
        HStack(spacing: 20) {
            PetCharacter(state: .worried, size: 80)
            PetCharacter(state: .struggling, size: 80)
            PetCharacter(state: .sleeping, size: 80)
        }
        PetCharacter(state: .celebrating, size: 80)
    }
    .padding()
    .background(Color.bobBackground)
}
