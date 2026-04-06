import SwiftUI

private struct OnboardingPage {
    let systemImage: String
    /// When set, shows this asset (app icon) instead of the SF Symbol — welcome screen only.
    let logoAssetName: String?
    let imageColor: Color
    let gradientColors: [Color]
    let title: String
    let body: String
}

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var page = 0
    @State private var selectedCurrency = "CAD"
    @AppStorage("defaultCurrency") private var defaultCurrency = "CAD"

    private let currencies = ["CAD", "USD", "EUR", "GBP", "AUD", "INR", "JPY", "MXN"]

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "circle.fill",
            logoAssetName: "ChipInLogo",
            imageColor: Color(red: 1.0, green: 0.55, blue: 0.26),
            gradientColors: [Color(red: 0.12, green: 0.10, blue: 0.08), Color(red: 0.08, green: 0.06, blue: 0.04)],
            title: "Welcome to ChipIn",
            body: "Split expenses with your friends and roommates — no awkward IOUs, ever."
        ),
        OnboardingPage(
            systemImage: "person.2.circle.fill",
            logoAssetName: nil,
            imageColor: Color(red: 0.24, green: 0.71, blue: 0.64),
            gradientColors: [Color(red: 0.06, green: 0.14, blue: 0.12), Color(red: 0.04, green: 0.08, blue: 0.08)],
            title: "Split in 3 Taps",
            body: "Hit +, enter an amount, pick your friends. ChipIn does the math."
        ),
        OnboardingPage(
            systemImage: "camera.viewfinder",
            logoAssetName: nil,
            imageColor: Color(red: 0.38, green: 0.60, blue: 1.0),
            gradientColors: [Color(red: 0.06, green: 0.08, blue: 0.18), Color(red: 0.04, green: 0.05, blue: 0.10)],
            title: "Scan Any Receipt",
            body: "Point your camera at any bill. AI reads every item so you can assign dishes to people in seconds."
        ),
        OnboardingPage(
            systemImage: "arrow.left.arrow.right.circle.fill",
            logoAssetName: nil,
            imageColor: Color(red: 1.0, green: 0.76, blue: 0.18),
            gradientColors: [Color(red: 0.14, green: 0.12, blue: 0.04), Color(red: 0.08, green: 0.06, blue: 0.02)],
            title: "Settle via Interac",
            body: "One tap opens your bank app with the amount and email pre-filled. Settling up has never been faster."
        ),
        OnboardingPage(
            systemImage: "globe.americas.fill",
            logoAssetName: nil,
            imageColor: Color(red: 0.78, green: 0.44, blue: 1.0),
            gradientColors: [Color(red: 0.10, green: 0.06, blue: 0.18), Color(red: 0.06, green: 0.03, blue: 0.10)],
            title: "What's your currency?",
            body: "All amounts are converted to your home currency automatically."
        ),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: pages[page].gradientColors,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: page)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button("Skip") {
                            withAnimation(ChipInTheme.spring) { page = pages.count - 1 }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.trailing, 24)
                        .padding(.top, 56)
                    } else {
                        Color.clear.frame(height: 56 + 22)
                    }
                }

                Spacer()

                // `Group` must be SwiftUI.Group — `Models/Group` (Codable) shadows it otherwise.
                SwiftUI.Group {
                    if let logo = pages[page].logoAssetName {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 160, height: 160)
                            Image(logo)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 112, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(pages[page].imageColor.opacity(0.18))
                                .frame(width: 140, height: 140)
                            Circle()
                                .fill(pages[page].imageColor.opacity(0.10))
                                .frame(width: 180, height: 180)
                            Image(systemName: pages[page].systemImage)
                                .font(.system(size: 70, weight: .medium))
                                .foregroundStyle(pages[page].imageColor)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                .padding(.bottom, 36)

                VStack(spacing: 14) {
                    Text(pages[page].title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.25), value: page)

                    Text(pages[page].body)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .animation(.easeInOut(duration: 0.25), value: page)
                }

                if page == pages.count - 1 {
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                    .colorScheme(.dark)
                }

                Spacer()

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? .white : .white.opacity(0.3))
                            .frame(width: i == page ? 20 : 6, height: 6)
                            .animation(ChipInTheme.spring, value: page)
                    }
                }
                .padding(.bottom, 28)

                Button {
                    if page < pages.count - 1 {
                        withAnimation(ChipInTheme.spring) { page += 1 }
                    } else {
                        defaultCurrency = selectedCurrency
                        isComplete = true
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Let's go →" : "Next")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(pages[page].imageColor)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { v in
                    if v.translation.width < -50, page < pages.count - 1 {
                        withAnimation(ChipInTheme.spring) { page += 1 }
                    } else if v.translation.width > 50, page > 0 {
                        withAnimation(ChipInTheme.spring) { page -= 1 }
                    }
                }
        )
    }
}
