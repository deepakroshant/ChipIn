import SwiftUI

struct ExpenseRow: View {
    let expense: Expense
    var onDelete: (() -> Void)? = nil

    var body: some View {
        NavigationLink(destination: ExpenseDetailView(expense: expense)) {
            HStack(spacing: 12) {
                Text(ExpenseCategory(rawValue: expense.category)?.emoji ?? "📦")
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(ChipInTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(ChipInTheme.label)
                    Text(expense.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(expense.cadAmount, format: .currency(code: "CAD"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(ChipInTheme.accent)
                    if expense.currency != "CAD" {
                        Text("\(expense.currency) \(expense.totalAmount, format: .number.precision(.fractionLength(2)))")
                            .font(.caption2)
                            .foregroundStyle(ChipInTheme.tertiaryLabel)
                    }
                }
            }
            .padding(.vertical, 4)
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
