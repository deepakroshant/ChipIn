import SwiftUI

struct PersonBalanceRow: View {
    let personBalance: PersonBalance

    private var isOwed: Bool { personBalance.net > 0 }
    private var color: Color { isOwed ? ChipInTheme.success : ChipInTheme.danger }
    private var label: String { isOwed ? "owes you" : "you owe" }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(personBalance.user.name.prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(ChipInTheme.label)
                .frame(width: 42, height: 42)
                .background(ChipInTheme.avatarColor(for: personBalance.user.name).opacity(0.25))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(personBalance.user.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ChipInTheme.label)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
            }

            Spacer()

            Text(abs(personBalance.net), format: .currency(code: "CAD"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
    }
}
