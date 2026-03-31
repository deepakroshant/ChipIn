import SwiftUI

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
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

            Text(expense.cadAmount, format: .currency(code: "CAD"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(ChipInTheme.accent)
        }
        .padding(.vertical, 4)
    }
}
