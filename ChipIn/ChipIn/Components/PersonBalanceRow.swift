import SwiftUI

struct PersonBalanceRow: View {
    let personBalance: PersonBalance
    @AppStorage("hideBalances") private var hideBalances = false
    @State private var appeared = false

    private var isOwed: Bool { personBalance.net > 0 }
    private var color: Color { isOwed ? ChipInTheme.success : ChipInTheme.danger }
    private var label: String { isOwed ? "owes you" : "you owe" }
    private var displayName: String { personBalance.user.displayName }
    private var avatarKey: String { personBalance.user.id.uuidString }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ChipInTheme.avatarColor(for: avatarKey),
                                ChipInTheme.avatarColor(for: avatarKey).opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ChipInTheme.label)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
            }

            Spacer()

            Text(BalancePrivacy.currency(abs(personBalance.net), code: "CAD", hidden: hideBalances))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
        }
        .padding(.vertical, 6)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 20)
        .onAppear {
            withAnimation(ChipInTheme.spring.delay(0.05)) { appeared = true }
        }
    }
}
