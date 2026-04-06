import SwiftUI

struct ExpenseRow: View {
    let expense: Expense
    var onDelete: (() -> Void)? = nil

    @AppStorage("hideBalances") private var hideBalances = false

    var body: some View {
        NavigationLink(destination: ExpenseDetailView(expense: expense)) {
            HStack(spacing: 12) {
                Text(ExpenseCategory(rawValue: expense.category)?.emoji ?? "📦")
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(ChipInTheme.surfaceContainerHighest)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ChipInTheme.label)
                    Text(expense.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(ChipInTheme.onSurfaceVariant)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(BalancePrivacy.currency(expense.cadAmount, code: "CAD", hidden: hideBalances))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ChipInTheme.accent)
                    if expense.currency != "CAD", !hideBalances {
                        Text("\(expense.currency) \(expense.totalAmount, format: .number.precision(.fractionLength(2)))")
                            .font(.caption2)
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(ChipInTheme.card.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
