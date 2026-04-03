import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var page = 0

    private let pages: [(emoji: String, title: String, body: String)] = [
        ("⚡️", "Split in 3 taps", "Hit the bolt button, enter an amount, tap a friend. Done."),
        ("📸", "Scan any receipt", "AI reads every item. Assign dishes to people in seconds."),
        ("💸", "Settle via Interac", "One tap opens your bank or pre-fills an email transfer.")
    ]

    var body: some View {
        ZStack {
            ChipInTheme.background.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 20) {
                            Text(pages[i].emoji).font(.system(size: 80))
                            Text(pages[i].title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(ChipInTheme.label)
                                .multilineTextAlignment(.center)
                            Text(pages[i].body)
                                .font(.body).foregroundStyle(ChipInTheme.secondaryLabel)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Circle()
                            .fill(i == page ? ChipInTheme.accent : ChipInTheme.elevated)
                            .frame(width: i == page ? 10 : 6, height: i == page ? 10 : 6)
                            .animation(ChipInTheme.spring, value: page)
                    }
                }

                Spacer()

                Button {
                    if page < pages.count - 1 {
                        withAnimation(ChipInTheme.spring) { page += 1 }
                    } else {
                        UserDefaults.standard.set(true, forKey: "onboardingComplete")
                        isComplete = true
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Get Started" : "Next")
                        .font(.headline).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding()
                        .background(ChipInTheme.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}
