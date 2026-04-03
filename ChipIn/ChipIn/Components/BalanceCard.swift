import SwiftUI

struct BalanceCard: View {
    let balance: Decimal

    @State private var displayBalance: Double = 0

    private var isOwed: Bool { balance >= 0 }
    private var color: Color { isOwed ? ChipInTheme.success : ChipInTheme.danger }
    private var label: String { isOwed ? "You're owed" : "You owe" }
    private var targetDouble: Double { NSDecimalNumber(decimal: abs(balance)).doubleValue }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if balance == 0 {
                HStack(spacing: 10) {
                    Text("🎉").font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All settled up!")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(ChipInTheme.label)
                        Text("You're even with everyone")
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                    }
                }
            } else {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
                    .textCase(.uppercase)
                    .tracking(1)

                Text(displayBalance / 100, format: .currency(code: "CAD"))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText(value: displayBalance))
                    .animation(ChipInTheme.spring, value: displayBalance)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [color.opacity(0.18), ChipInTheme.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .onAppear { animateIn() }
        .onChange(of: balance) { _, _ in animateIn() }
    }

    private func animateIn() {
        displayBalance = 0
        withAnimation(.easeOut(duration: 0.85)) {
            displayBalance = targetDouble * 100
        }
    }
}
