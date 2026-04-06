import SwiftUI

struct BalanceCard: View {
    let balance: Decimal
    var onRequest: (() -> Void)? = nil

    @AppStorage("hideBalances") private var hideBalances = false
    @State private var displayBalance: Double = 0

    private var isOwed: Bool { balance >= 0 }
    private var amountColor: Color { balance == 0 ? ChipInTheme.label : (isOwed ? ChipInTheme.success : ChipInTheme.accent) }
    private var statusLine: String {
        if balance == 0 { return "You're even with everyone" }
        return isOwed ? "You're owed" : "You owe"
    }
    private var targetDouble: Double { NSDecimalNumber(decimal: abs(balance)).doubleValue }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(ChipInTheme.accent.opacity(0.35))
                    .frame(width: 160, height: 160)
                    .blur(radius: 40)
                    .offset(x: 80, y: -70)
                Circle()
                    .fill(ChipInTheme.success.opacity(0.22))
                    .frame(width: 140, height: 140)
                    .blur(radius: 36)
                    .offset(x: -50, y: 60)

                VStack(alignment: .leading, spacing: 8) {
                    if balance == 0 {
                        HStack(spacing: 10) {
                            Text("🎉").font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("All settled up!")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(ChipInTheme.label)
                                Text(statusLine)
                                    .font(.caption)
                                    .foregroundStyle(ChipInTheme.onSurfaceVariant)
                            }
                        }
                    } else {
                        Text("Total net balance")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ChipInTheme.onSurfaceVariant)
                            .textCase(.uppercase)
                            .tracking(2)

                        if hideBalances {
                            Text(BalancePrivacy.masked)
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .foregroundStyle(amountColor)
                        } else {
                            Text(displayBalance / 100, format: .currency(code: "CAD"))
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .foregroundStyle(amountColor)
                                .contentTransition(.numericText(value: displayBalance))
                                .animation(ChipInTheme.spring, value: displayBalance)
                        }

                        Text(statusLine)
                            .font(.subheadline)
                            .foregroundStyle(ChipInTheme.onSurfaceVariant)
                    }
                }
                .padding(ChipInTheme.cardPadding)
            }

            if balance != 0, let onRequest {
                Button(action: onRequest) {
                    Text("Request")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ChipInTheme.ctaGradient)
                        .foregroundStyle(ChipInTheme.onPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: ChipInTheme.accent.opacity(0.28), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, ChipInTheme.cardPadding)
                .padding(.bottom, ChipInTheme.cardPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ChipInTheme.surfaceContainerHighest.opacity(0.85)
        )
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear { animateIn() }
        .onChange(of: balance) { _, _ in animateIn() }
        .onChange(of: hideBalances) { _, hidden in
            if !hidden { animateIn() }
        }
    }

    private func animateIn() {
        guard !hideBalances else {
            displayBalance = targetDouble * 100
            return
        }
        displayBalance = 0
        withAnimation(.easeOut(duration: 0.85)) {
            displayBalance = targetDouble * 100
        }
    }
}
