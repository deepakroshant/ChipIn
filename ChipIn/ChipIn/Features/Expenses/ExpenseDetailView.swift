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
    @State private var showEdit = false
    @State private var editTitle = ""
    @State private var editAmount = ""
    @State private var editCategory = ExpenseCategory.other
    @State private var isSavingEdit = false
    @State private var comments: [Comment] = []
    @State private var commentUsers: [UUID: AppUser] = [:]
    @State private var newComment = ""
    @State private var isPostingComment = false
    private let service = ExpenseService()
    private let commentService = CommentService()

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

                // Comments section
                commentsSection

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
        .toolbar {
            if expense.paidBy == auth.currentUser?.id {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        editTitle = expense.title
                        editAmount = "\(expense.totalAmount)"
                        editCategory = ExpenseCategory(rawValue: expense.category) ?? .other
                        showEdit = true
                    }
                    .foregroundStyle(ChipInTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showEdit) { editSheet }
        .task {
            await loadSplits()
            await loadComments()
        }
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

    private var editSheet: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    TextField("Title", text: $editTitle)
                        .foregroundStyle(ChipInTheme.label)
                        .padding(16)
                        .background(ChipInTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    TextField("Amount", text: $editAmount)
                        .keyboardType(.decimalPad)
                        .foregroundStyle(ChipInTheme.label)
                        .padding(16)
                        .background(ChipInTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Picker("Category", selection: $editCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Text("\(cat.emoji) \(cat.rawValue)").tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(ChipInTheme.accent)
                    .padding(16)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEdit = false }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSavingEdit {
                        ProgressView().tint(ChipInTheme.accent)
                    } else {
                        Button("Save") {
                            Task {
                                isSavingEdit = true
                                defer { isSavingEdit = false }
                                guard let amt = Decimal(string: editAmount), amt > 0, !editTitle.isEmpty else { return }
                                try? await service.updateExpense(
                                    id: expense.id,
                                    title: editTitle,
                                    amount: amt,
                                    currency: expense.currency,
                                    category: editCategory.rawValue
                                )
                                NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
                                showEdit = false
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(ChipInTheme.accent)
                    }
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comments")
                .font(.footnote.uppercaseSmallCaps())
                .foregroundStyle(ChipInTheme.tertiaryLabel)
                .padding(.horizontal, ChipInTheme.padding)

            if !comments.isEmpty {
                LazyVStack(spacing: 0) {
                    ForEach(comments) { comment in
                        let name = commentUsers[comment.userId]?.name ?? "?"
                        HStack(alignment: .top, spacing: 10) {
                            Text(String(name.prefix(1)).uppercased())
                                .font(.caption.bold())
                                .foregroundStyle(ChipInTheme.label)
                                .frame(width: 30, height: 30)
                                .background(ChipInTheme.avatarColor(for: name).opacity(0.25))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(name).font(.caption.weight(.semibold)).foregroundStyle(ChipInTheme.label)
                                    Text(comment.createdAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(ChipInTheme.tertiaryLabel)
                                }
                                Text(comment.body)
                                    .font(.subheadline)
                                    .foregroundStyle(ChipInTheme.secondaryLabel)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, ChipInTheme.padding)
                        .padding(.vertical, 10)
                        if comment.id != comments.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(ChipInTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
                .padding(.horizontal, ChipInTheme.padding)
            }

            HStack(spacing: 10) {
                TextField("Add a comment…", text: $newComment)
                    .padding(10)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(ChipInTheme.label)
                if isPostingComment {
                    ProgressView().tint(ChipInTheme.accent)
                } else {
                    Button {
                        Task { await postComment() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(
                                newComment.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? ChipInTheme.tertiaryLabel : ChipInTheme.accent
                            )
                    }
                    .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal, ChipInTheme.padding)
        }
    }

    private func loadComments() async {
        do {
            comments = try await commentService.fetchComments(for: expense.id)
            let ids = Set(comments.map(\.userId))
            if !ids.isEmpty {
                let users: [AppUser] = try await supabase
                    .from("users").select()
                    .in("id", values: ids.map(\.uuidString))
                    .execute().value
                commentUsers = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
            }
        } catch { /* silent */ }
    }

    private func postComment() async {
        let body = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let userId = auth.currentUser?.id else { return }
        isPostingComment = true
        defer { isPostingComment = false }
        do {
            let comment = try await commentService.addComment(expenseId: expense.id, userId: userId, body: body)
            commentUsers[userId] = auth.currentUser
            comments.append(comment)
            newComment = ""
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch { /* silent */ }
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
