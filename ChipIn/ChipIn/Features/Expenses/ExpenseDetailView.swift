import SwiftUI
import Supabase
import PostgREST

struct ExpenseDetailView: View {
    let expense: Expense
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @State private var splits: [ExpenseSplit] = []
    @State private var splitUsers: [UUID: AppUser] = [:]
    @State private var isLoading = false
    @State private var showDeleteConfirm = false
    private let service = ExpenseService()

    private var categoryEmoji: String {
        ExpenseCategory(rawValue: expense.category)?.emoji ?? "📦"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card
                VStack(spacing: 10) {
                    Text(categoryEmoji)
                        .font(.system(size: 48))
                    Text(expense.title)
                        .font(.title2.bold())
                        .foregroundStyle(ChipInTheme.label)
                        .multilineTextAlignment(.center)
                    Text(expense.totalAmount, format: .currency(code: expense.currency))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(ChipInTheme.accent)
                    Text(expense.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(ChipInTheme.tertiaryLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(ChipInTheme.cardPadding)
                .chipInCard()
                .padding(.horizontal, ChipInTheme.padding)

                // Splits breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("Split Breakdown")
                        .font(.footnote.uppercaseSmallCaps())
                        .foregroundStyle(ChipInTheme.tertiaryLabel)
                        .padding(.horizontal, ChipInTheme.padding)

                    if isLoading {
                        ProgressView().tint(ChipInTheme.accent)
                            .frame(maxWidth: .infinity).padding()
                    } else if splits.isEmpty {
                        Text("No split data")
                            .font(.subheadline)
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(splits) { split in
                                let name = splitUsers[split.userId]?.name ?? "Unknown"
                                HStack(spacing: 12) {
                                    Text(String(name.prefix(1)).uppercased())
                                        .font(.subheadline.bold())
                                        .foregroundStyle(ChipInTheme.label)
                                        .frame(width: 36, height: 36)
                                        .background(ChipInTheme.avatarColor(for: name).opacity(0.25))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(ChipInTheme.label)
                                        Text(split.isSettled ? "Settled ✓" : "Owes")
                                            .font(.caption)
                                            .foregroundStyle(split.isSettled ? ChipInTheme.success : ChipInTheme.secondaryLabel)
                                    }

                                    Spacer()

                                    Text(split.owedAmount, format: .currency(code: expense.currency))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(split.isSettled ? ChipInTheme.tertiaryLabel : ChipInTheme.label)
                                }
                                .padding(.horizontal, ChipInTheme.padding)
                                .padding(.vertical, 10)

                                if split.id != splits.last?.id {
                                    Divider().padding(.leading, 60)
                                }
                            }
                        }
                        .background(ChipInTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
                        .padding(.horizontal, ChipInTheme.padding)
                    }
                }

                // Delete button — only for the payer
                if expense.paidBy == auth.currentUser?.id {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Expense", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ChipInTheme.danger.opacity(0.15))
                            .foregroundStyle(ChipInTheme.danger)
                            .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                    }
                    .padding(.horizontal, ChipInTheme.padding)
                }
            }
            .padding(.top, ChipInTheme.padding)
            .padding(.bottom, 32)
        }
        .background(ChipInTheme.background.ignoresSafeArea())
        .navigationTitle("Expense")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .task { await loadSplits() }
        .confirmationDialog("Delete this expense?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await service.deleteExpense(id: expense.id)
                    NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the expense and all splits. Cannot be undone.")
        }
    }

    private func loadSplits() async {
        isLoading = true
        defer { isLoading = false }
        do {
            splits = try await supabase
                .from("expense_splits")
                .select()
                .eq("expense_id", value: expense.id.uuidString)
                .execute()
                .value
            let ids = splits.map { $0.userId.uuidString }
            if !ids.isEmpty {
                let users: [AppUser] = try await supabase
                    .from("users")
                    .select()
                    .in("id", values: ids)
                    .execute()
                    .value
                splitUsers = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
            }
        } catch {
            // splits just won't show
        }
    }
}
