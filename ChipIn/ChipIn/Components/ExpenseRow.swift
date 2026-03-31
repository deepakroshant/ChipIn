import SwiftUI

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            Text(ExpenseCategory(rawValue: expense.category)?.emoji ?? "📦")
                .font(.title2)
                .frame(width: 42, height: 42)
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(expense.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(expense.cadAmount, format: .currency(code: "CAD"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color(hex: "#F97316"))
        }
        .padding(.vertical, 4)
    }
}
