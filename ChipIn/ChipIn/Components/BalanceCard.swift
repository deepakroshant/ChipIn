import SwiftUI

struct BalanceCard: View {
    let balance: Decimal

    private var isOwed: Bool { balance >= 0 }
    private var color: Color { isOwed ? ChipInTheme.success : ChipInTheme.danger }
    private var label: String { isOwed ? "You're owed" : "You owe" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(ChipInTheme.secondaryLabel)
                .textCase(.uppercase)
                .tracking(1)

            Text(abs(balance), format: .currency(code: "CAD"))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
