import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @AppStorage("petName") private var petName: String = "Buddy"
    @State private var petNameInput: String = ""
    @FocusState private var namingFieldFocused: Bool

    private let totalPages = 5
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Track every\npenny",
            subtitle: "Log income and expenses in seconds. Know exactly where your money goes.",
            icon: "arrow.up.arrow.down.circle.fill",
            accent: Color.bobHex(0x588157),
            bgAccent: Color.bobHex(0x588157).opacity(0.08)
        ),
        OnboardingPage(
            title: "Budget with\nconfidence",
            subtitle: "Set a monthly budget and get alerted before you overspend. Stay in control.",
            icon: "chart.bar.fill",
            accent: Color.bobHex(0x1A73E8),
            bgAccent: Color.bobHex(0x1A73E8).opacity(0.08)
        ),
        OnboardingPage(
            title: "Save toward\nyour dreams",
            subtitle: "Create savings goals and track your progress month by month.",
            icon: "target",
            accent: Color.bobHex(0xBA68C8),
            bgAccent: Color.bobHex(0xBA68C8).opacity(0.08)
        ),
        OnboardingPage(
            title: "See the full\npicture",
            subtitle: "Beautiful charts that reveal your spending patterns and financial trends.",
            icon: "chart.pie.fill",
            accent: Color.bobHex(0xFF8A65),
            bgAccent: Color.bobHex(0xFF8A65).opacity(0.08)
        )
    ]

    var body: some View {
        ZStack {
            Color.bobBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button("Skip") { isPresented = false }
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bobInk2)
                            .padding(.trailing, Spacing.pageMargin)
                            .padding(.top, 16)
                    }
                }
                .frame(height: 44)

                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { idx in
                        pageView(pages[idx]).tag(idx)
                    }
                    // Pet naming page (index 4)
                    petNamingPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                Spacer()

                // Dots + CTA
                VStack(spacing: 32) {
                    pageIndicator

                    if currentPage < totalPages - 1 {
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Continue")
                                    .font(.system(size: 17, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(currentPage < pages.count ? pages[currentPage].accent : Color.bobHex(0x588157))
                            .clipShape(Capsule())
                        }
                    } else {
                        Button {
                            let name = petNameInput.trimmingCharacters(in: .whitespaces)
                            petName = name.isEmpty ? "Buddy" : name
                            isPresented = false
                        } label: {
                            Text("Meet \(petNameInput.trimmingCharacters(in: .whitespaces).isEmpty ? "Buddy" : petNameInput.trimmingCharacters(in: .whitespaces))!")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.bobHex(0x588157))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, Spacing.pageMargin)
                .padding(.bottom, 48)
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 40) {
            // Icon
            ZStack {
                Circle()
                    .fill(page.bgAccent)
                    .frame(width: 140, height: 140)
                Circle()
                    .stroke(page.accent.opacity(0.2), lineWidth: 1)
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(page.accent)
            }

            // Text
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.bobInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text(page.subtitle)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.bobInk2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, Spacing.pageMargin)
    }

    private var pageIndicator: some View {
        let accent: Color = currentPage < pages.count ? pages[currentPage].accent : Color.bobHex(0x588157)
        return HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { idx in
                Capsule()
                    .fill(idx == currentPage ? accent : Color.bobHairline)
                    .frame(width: idx == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            }
        }
    }

    private var petNamingPage: some View {
        VStack(spacing: 40) {
            PetCharacter(state: .neutral, size: 110)

            VStack(spacing: 16) {
                Text("Meet your\ncompanion")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.bobInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("This little creature will reflect your financial health. Give them a name!")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.bobInk2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .lineSpacing(3)

                TextField("e.g. Budgie, Penny, Kip…", text: $petNameInput)
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .padding(.horizontal, Spacing.m)
                    .background(Color.bobSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.input))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.input)
                            .stroke(Color.bobHairline, lineWidth: 1)
                    )
                    .focused($namingFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { namingFieldFocused = false }
                    .frame(maxWidth: 280)
            }
        }
        .padding(.horizontal, Spacing.pageMargin)
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let bgAccent: Color
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
