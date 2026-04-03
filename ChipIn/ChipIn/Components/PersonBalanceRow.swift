import SwiftUI

struct PersonBalanceRow: View {
    let personBalance: PersonBalance
    @State private var appeared = false

    private var isOwed: Bool { personBalance.net > 0 }
    private var color: Color { isOwed ? ChipInTheme.success : ChipInTheme.danger }
    private var label: String { isOwed ? "owes you" : "you owe" }
    private var name: String { personBalance.user.name }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ChipInTheme.avatarColor(for: name),
                                ChipInTheme.avatarColor(for: name).opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Text(String(name.prefix(1)).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ChipInTheme.label)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
            }

            Spacer()

            Text(abs(personBalance.net), format: .currency(code: "CAD"))
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
