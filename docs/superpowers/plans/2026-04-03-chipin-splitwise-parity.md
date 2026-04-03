# ChipIn — Beat Splitwise: Gen-Z UX + Feature Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ChipIn a premium Gen-Z iOS expense-splitting app that beats Splitwise with working receipt scanning, expense comments, quick-add, visual polish, and animated balances.

**Architecture:** Each feature is independently shippable — start with P0 (receipt scanning end-to-end), then P1 features (comments, animated home, quick-add), then P2 polish. All Supabase calls go through service structs; views stay thin.

**Tech Stack:** SwiftUI iOS 17+, `@Observable` macro, Supabase Swift 2.43.0 (explicit sub-module imports), ChipInTheme dark design tokens, UIKit haptics.

---

## File Map

**Modified:**
- `ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift` — wire receipt → ItemSplitView, auto-fill amount/title
- `ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift` — add item-split submit path, split calculation logic
- `ChipIn/ChipIn/Features/Expenses/ExpenseDetailView.swift` — add comment thread + edit sheet
- `ChipIn/ChipIn/Features/Home/HomeView.swift` — animated balance, settled state, swipe actions
- `ChipIn/ChipIn/Components/BalanceCard.swift` — glassmorphism + gradient
- `ChipIn/ChipIn/Components/PersonBalanceRow.swift` — gradient avatar, haptics, swipe actions
- `ChipIn/ChipIn/Services/ExpenseService.swift` — add `updateExpense()`, `calculateItemSplits()`

**Created:**
- `ChipIn/ChipIn/Services/CommentService.swift` — CRUD + Realtime for comments
- `ChipIn/ChipIn/Features/AddExpense/QuickAddView.swift` — 3-tap bottom sheet

---

## Task 1: Wire Receipt Scanning End-to-End (P0)

**Files:**
- Modify: `ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift`
- Modify: `ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift`

**Problem:** `ReceiptScannerView` correctly sets `vm.parsedReceipt` via binding, but `AddExpenseView` never observes it or shows `ItemSplitView`. Also, `vm.submit()` ignores item assignments even if they existed.

- [ ] **Step 1: Add `showItemSplit` state to AddExpenseView**

In `AddExpenseView.swift`, add one new `@State` variable after the existing ones:

```swift
@State private var showItemSplit = false
```

- [ ] **Step 2: Add `.onChange` for parsedReceipt and `.sheet` for ItemSplitView**

In `AddExpenseView.swift`, add two modifiers **after** the existing `.sheet(isPresented: $vm.showReceiptScanner)` block (before the closing brace of `NavigationStack`):

```swift
.onChange(of: vm.parsedReceipt) { _, receipt in
    guard let receipt else { return }
    // Auto-fill total and title if empty
    if vm.amount.isEmpty || vm.amount == "0.00" {
        vm.amount = "\(receipt.total)"
    }
    if vm.title.isEmpty {
        vm.title = "Receipt"
    }
    showItemSplit = true
}
.sheet(isPresented: $showItemSplit) {
    if var receipt = vm.parsedReceipt {
        let members = vm.context == .group ? groupMembers : coMembers
        ItemSplitView(receipt: Binding(
            get: { vm.parsedReceipt ?? receipt },
            set: { vm.parsedReceipt = $0 }
        ), groupMembers: members)
    }
}
```

- [ ] **Step 3: Add `calculateItemSplits` to ExpenseService**

In `ExpenseService.swift`, add this method after `calculateEqualSplits`:

```swift
/// Convert assigned receipt items into per-user splits.
/// Unassigned items fall back to equal split across all participants.
func calculateItemSplits(
    receipt: ParsedReceipt,
    participantIds: [UUID]
) -> [(userId: UUID, amount: Decimal)] {
    guard !participantIds.isEmpty else { return [] }

    var totals: [UUID: Decimal] = Dictionary(uniqueKeysWithValues: participantIds.map { ($0, Decimal(0)) })
    var unassignedTotal: Decimal = 0

    for item in receipt.items {
        let full = item.price + item.taxPortion
        if let owner = item.assignedTo, totals[owner] != nil {
            totals[owner]! += full
        } else {
            unassignedTotal += full
        }
    }

    // Spread unassigned evenly
    if unassignedTotal > 0 {
        let share = unassignedTotal / Decimal(participantIds.count)
        for id in participantIds {
            totals[id]! += share
        }
    }

    return participantIds.map { id in (userId: id, amount: totals[id] ?? 0) }
}
```

- [ ] **Step 4: Update `AddExpenseViewModel.submit()` to pass items and use item splits when receipt present**

Replace the `submit` method body in `AddExpenseViewModel.swift`:

```swift
func submit(paidBy: UUID) async -> Bool {
    error = nil
    guard !title.isEmpty, amountDecimal > 0 else {
        error = "Add a title and a valid amount."
        return false
    }

    if context == .friends {
        guard selectedUserIds.count >= 2 else {
            error = "Pick at least two people."
            return false
        }
        guard selectedUserIds.contains(paidBy) else {
            error = "Include yourself in the split."
            return false
        }
    } else {
        guard selectedGroupId != nil else { error = "Choose a group."; return false }
        guard !selectedUserIds.isEmpty else { error = "Select who is in this split."; return false }
    }

    isSubmitting = true
    defer { isSubmitting = false }
    do {
        let splits: [(userId: UUID, amount: Decimal)]
        var expenseItems: [NewExpenseItem] = []

        if let receipt = parsedReceipt {
            splits = service.calculateItemSplits(receipt: receipt, participantIds: selectedUserIds)
            expenseItems = receipt.items.compactMap { item in
                guard let owner = item.assignedTo else { return nil }
                return NewExpenseItem(
                    name: item.name,
                    price: item.price,
                    taxPortion: item.taxPortion,
                    assignedTo: owner
                )
            }
        } else {
            splits = service.calculateEqualSplits(amount: amountDecimal, userIds: selectedUserIds)
        }

        let gid: UUID? = context == .friends ? nil : selectedGroupId
        try await service.createExpense(
            groupId: gid,
            paidBy: paidBy,
            title: title,
            amount: amountDecimal,
            currency: currency,
            category: category.rawValue,
            splitType: parsedReceipt != nil ? .exact : splitType,
            splits: splits,
            isRecurring: isRecurring,
            recurrenceInterval: isRecurring ? recurrenceInterval : nil,
            items: expenseItems
        )
        SoundService.shared.play(.expenseAdd, haptic: .light)
        NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
        return true
    } catch {
        self.error = error.localizedDescription
        return false
    }
}
```

- [ ] **Step 5: Build and verify no errors**

```bash
cd /Users/deepak/Claude-projects/Splitwise && xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 6: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise && git add ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift ChipIn/ChipIn/Services/ExpenseService.swift && git commit -m "feat: wire receipt scanning end-to-end — ItemSplitView shows after scan, item splits saved"
```

---

## Task 2: Expense Comments (P1)

**Files:**
- Create: `ChipIn/ChipIn/Services/CommentService.swift`
- Modify: `ChipIn/ChipIn/Features/Expenses/ExpenseDetailView.swift`

- [ ] **Step 1: Create CommentService**

Create `ChipIn/ChipIn/Services/CommentService.swift`:

```swift
import Supabase
import Foundation

struct CommentService {
    func fetchComments(for expenseId: UUID) async throws -> [Comment] {
        try await supabase
            .from("comments")
            .select()
            .eq("expense_id", value: expenseId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func addComment(expenseId: UUID, userId: UUID, body: String) async throws -> Comment {
        struct Insert: Encodable {
            let expense_id: String
            let user_id: String
            let body: String
        }
        return try await supabase
            .from("comments")
            .insert(Insert(
                expense_id: expenseId.uuidString,
                user_id: userId.uuidString,
                body: body
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func deleteComment(id: UUID) async throws {
        try await supabase
            .from("comments")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
```

- [ ] **Step 2: Add comment section to ExpenseDetailView**

Add these state variables to `ExpenseDetailView` after `showDeleteConfirm`:

```swift
@State private var comments: [Comment] = []
@State private var commentUsers: [UUID: AppUser] = [:]
@State private var newComment = ""
@State private var isPostingComment = false
private let commentService = CommentService()
```

- [ ] **Step 3: Add `loadComments()` and `postComment()` private functions to ExpenseDetailView**

Add these after `loadSplits()`:

```swift
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
```

- [ ] **Step 4: Add comment section view to ExpenseDetailView body**

Add this VStack block in the body's main VStack, **after** the delete button block and **before** the closing `}` of the outer VStack:

```swift
// Comments section
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
                        HStack {
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

    // Input row
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
                    .foregroundStyle(newComment.trimmingCharacters(in: .whitespaces).isEmpty
                        ? ChipInTheme.tertiaryLabel : ChipInTheme.accent)
            }
            .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
    .padding(.horizontal, ChipInTheme.padding)
}
```

- [ ] **Step 5: Wire `.task` to also load comments**

Replace the existing `.task { await loadSplits() }` with:

```swift
.task {
    await loadSplits()
    await loadComments()
}
```

- [ ] **Step 6: Build and verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise && xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```

- [ ] **Step 7: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise && git add ChipIn/ChipIn/Services/CommentService.swift ChipIn/ChipIn/Features/Expenses/ExpenseDetailView.swift && git commit -m "feat: expense comments — thread view + post input on expense detail"
```

---

## Task 3: Animated BalanceCard + Settled State (P1)

**Files:**
- Modify: `ChipIn/ChipIn/Components/BalanceCard.swift`
- Modify: `ChipIn/ChipIn/Features/Home/HomeView.swift`

- [ ] **Step 1: Rewrite BalanceCard with glassmorphism + animated number**

Replace the entire contents of `ChipIn/ChipIn/Components/BalanceCard.swift`:

```swift
import SwiftUI

struct BalanceCard: View {
    let balance: Decimal

    @State private var displayBalance: Double = 0

    private var isOwed: Bool { balance >= 0 }
    private var color: Color { isOwed ? ChipInTheme.success : ChipInTheme.danger }
    private var label: String { isOwed ? "You're owed" : "You owe" }
    private var targetDouble: Double { NSDecimalNumber(decimal: abs(balance)).doubleValue }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if balance == 0 {
                HStack(spacing: 8) {
                    Text("🎉")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All settled up!")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(ChipInTheme.label)
                        Text("You're even with everyone")
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                    }
                }
            } else {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
                    .textCase(.uppercase)
                    .tracking(1)

                Text(displayBalance / 100, format: .currency(code: "CAD"))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText(value: displayBalance))
                    .animation(ChipInTheme.spring, value: displayBalance)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial)
        .background(
            LinearGradient(
                colors: [
                    color.opacity(0.18),
                    ChipInTheme.card
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .onAppear { animateIn() }
        .onChange(of: balance) { _, _ in animateIn() }
    }

    private func animateIn() {
        displayBalance = 0
        withAnimation(.easeOut(duration: 0.9)) {
            displayBalance = targetDouble * 100
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise && xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```

- [ ] **Step 3: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise && git add ChipIn/ChipIn/Components/BalanceCard.swift && git commit -m "feat: animated glassmorphism BalanceCard — count-up animation + all-settled state"
```

---

## Task 4: PersonBalanceRow — Gradient Avatar, Haptics, Swipe Actions (P1)

**Files:**
- Modify: `ChipIn/ChipIn/Components/PersonBalanceRow.swift`
- Modify: `ChipIn/ChipIn/Features/Home/HomeView.swift`

- [ ] **Step 1: Rewrite PersonBalanceRow with gradient avatar and spring entrance**

Replace the entire contents of `ChipIn/ChipIn/Components/PersonBalanceRow.swift`:

```swift
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
            // Gradient avatar
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
            withAnimation(ChipInTheme.spring.delay(0.05)) {
                appeared = true
            }
        }
    }
}
```

- [ ] **Step 2: Add swipe actions to the balance list in HomeView**

In `HomeView.swift`, find the `NavigationLink(destination: PersonDetailView(balance: pb))` block and wrap it with swipe actions. Replace:

```swift
NavigationLink(destination: PersonDetailView(balance: pb)) {
    PersonBalanceRow(personBalance: pb)
        .padding(.horizontal)
}
.buttonStyle(.plain)
```

With:

```swift
NavigationLink(destination: PersonDetailView(balance: pb)) {
    PersonBalanceRow(personBalance: pb)
        .padding(.horizontal)
}
.buttonStyle(.plain)
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    NavigationLink(destination: PersonDetailView(balance: pb)) {
        Label("Settle", systemImage: "checkmark.circle")
    }
    .tint(ChipInTheme.success)
}
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise && xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```

- [ ] **Step 4: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise && git add ChipIn/ChipIn/Components/PersonBalanceRow.swift ChipIn/ChipIn/Features/Home/HomeView.swift && git commit -m "feat: gradient avatars, spring entrance animations, swipe-to-settle on PersonBalanceRow"
```

---

## Task 5: Quick Add Bottom Sheet (P1)

**Files:**
- Create: `ChipIn/ChipIn/Features/AddExpense/QuickAddView.swift`
- Modify: `ChipIn/ChipIn/Features/Home/HomeView.swift`

**Goal:** 3-tap expense: amount → pick person → save. No group, no category picker.

- [ ] **Step 1: Create QuickAddView**

Create `ChipIn/ChipIn/Features/AddExpense/QuickAddView.swift`:

```swift
import SwiftUI

struct QuickAddView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @State private var amount = ""
    @State private var title = ""
    @State private var coMembers: [AppUser] = []
    @State private var selectedUserId: UUID?
    @State private var isSubmitting = false
    @State private var error: String?
    @FocusState private var amountFocused: Bool
    private let groupService = GroupService()
    private let expenseService = ExpenseService()

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    // Amount
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(amount.isEmpty ? ChipInTheme.tertiaryLabel : ChipInTheme.accent)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    // Description
                    TextField("What's this for?", text: $title)
                        .font(.title3)
                        .foregroundStyle(ChipInTheme.label)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Person picker
                    if !coMembers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(coMembers) { user in
                                    let selected = selectedUserId == user.id
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(selected
                                                    ? ChipInTheme.avatarColor(for: user.name)
                                                    : ChipInTheme.card)
                                                .frame(width: 52, height: 52)
                                            Text(String(user.name.prefix(1)).uppercased())
                                                .font(.headline.bold())
                                                .foregroundStyle(selected ? .white : ChipInTheme.secondaryLabel)
                                        }
                                        .overlay(
                                            Circle().stroke(
                                                selected ? ChipInTheme.accent : Color.clear,
                                                lineWidth: 2
                                            )
                                        )
                                        .scaleEffect(selected ? 1.1 : 1.0)
                                        .animation(ChipInTheme.spring, value: selected)

                                        Text(user.name.components(separatedBy: " ").first ?? user.name)
                                            .font(.caption2)
                                            .foregroundStyle(selected ? ChipInTheme.accent : ChipInTheme.tertiaryLabel)
                                    }
                                    .onTapGesture {
                                        selectedUserId = user.id
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(ChipInTheme.danger)
                    }

                    Spacer()

                    // Save button
                    Button {
                        Task { await save() }
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(.black)
                        } else {
                            Text("Split It")
                                .font(.headline)
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        (amount.isEmpty || selectedUserId == nil)
                            ? ChipInTheme.elevated
                            : ChipInTheme.accentGradient
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
                    .padding(.horizontal)
                    .disabled(amount.isEmpty || selectedUserId == nil || isSubmitting)
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await loadMembers() }
            .onAppear { amountFocused = true }
        }
    }

    private func loadMembers() async {
        guard let id = auth.currentUser?.id else { return }
        coMembers = (try? await groupService.fetchCoMembers(excludingSelf: id)) ?? []
    }

    private func save() async {
        guard let paidBy = auth.currentUser?.id,
              let otherId = selectedUserId,
              let amt = Decimal(string: amount), amt > 0 else {
            error = "Enter an amount and pick a person."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let expTitle = title.isEmpty ? "Quick split" : title
            let splits = expenseService.calculateEqualSplits(amount: amt, userIds: [paidBy, otherId])
            try await expenseService.createExpense(
                groupId: nil,
                paidBy: paidBy,
                title: expTitle,
                amount: amt,
                currency: "CAD",
                category: ExpenseCategory.other.rawValue,
                splitType: .equal,
                splits: splits,
                isRecurring: false,
                recurrenceInterval: nil
            )
            SoundService.shared.play(.expenseAdd, haptic: .light)
            NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Add `showQuickAdd` state and bottom sheet to HomeView**

In `HomeView.swift`, add a state variable at the top of the struct:

```swift
@State private var showQuickAdd = false
```

Add the sheet modifier before the final closing brace of `NavigationStack`:

```swift
.sheet(isPresented: $showQuickAdd) {
    QuickAddView()
        .environment(auth)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
```

- [ ] **Step 3: Add a Quick Add button to HomeView toolbar**

Replace `.toolbar(.hidden, for: .navigationBar)` in HomeView with:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            showQuickAdd = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Label("Quick Add", systemImage: "bolt.fill")
                .foregroundStyle(ChipInTheme.accent)
        }
    }
}
.toolbarBackground(ChipInTheme.background, for: .navigationBar)
.toolbarColorScheme(.dark, for: .navigationBar)
```

- [ ] **Step 4: Build and verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise && xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```

- [ ] **Step 5: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise && git add ChipIn/ChipIn/Features/AddExpense/QuickAddView.swift ChipIn/ChipIn/Features/Home/HomeView.swift && git commit -m "feat: quick-add bottom sheet — amount + person in 3 taps, no group required"
```

---

## Task 6: Expense Edit (P2)

**Files:**
- Modify: `ChipIn/ChipIn/Services/ExpenseService.swift`
- Modify: `ChipIn/ChipIn/Features/Expenses/ExpenseDetailView.swift`

- [ ] **Step 1: Add `updateExpense` to ExpenseService**

Add this method to `ExpenseService` after `deleteExpense`:

```swift
func updateExpense(id: UUID, title: String, amount: Decimal, currency: String, category: String) async throws {
    struct Update: Encodable {
        let title: String
        let total_amount: String
        let currency: String
        let category: String
    }
    try await supabase
        .from("expenses")
        .update(Update(
            title: title,
            total_amount: "\(amount)",
            currency: currency,
            category: category
        ))
        .eq("id", value: id.uuidString)
        .execute()
}
```

- [ ] **Step 2: Add edit state and sheet to ExpenseDetailView**

Add these state variables in `ExpenseDetailView` after `showDeleteConfirm`:

```swift
@State private var showEdit = false
@State private var editTitle = ""
@State private var editAmount = ""
@State private var editCategory = ExpenseCategory.food
@State private var isSavingEdit = false
```

- [ ] **Step 3: Add edit button to ExpenseDetailView toolbar and edit sheet**

Add a toolbar modifier (before `.task`) in `ExpenseDetailView`:

```swift
.toolbar {
    if expense.paidBy == auth.currentUser?.id {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Edit") {
                editTitle = expense.title
                editAmount = "\(expense.totalAmount)"
                editCategory = ExpenseCategory(rawValue: expense.category) ?? .food
                showEdit = true
            }
            .foregroundStyle(ChipInTheme.accent)
        }
    }
}
```

Add the edit sheet modifier after the delete confirmation dialog:

```swift
.sheet(isPresented: $showEdit) {
    NavigationStack {
        ZStack {
            ChipInTheme.background.ignoresSafeArea()
            VStack(spacing: 20) {
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
                            guard let amt = Decimal(string: editAmount), amt > 0 else { return }
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
```

- [ ] **Step 4: Build and verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise && xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```

- [ ] **Step 5: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise && git add ChipIn/ChipIn/Services/ExpenseService.swift ChipIn/ChipIn/Features/Expenses/ExpenseDetailView.swift && git commit -m "feat: edit expense title, amount, and category from detail view"
```

---

## Task 7: Gen-Z Visual Polish Pass (P2)

**Files:**
- Modify: `ChipIn/ChipIn/Features/Home/HomeView.swift`
- Modify: `ChipIn/ChipIn/Core/ChipInTheme.swift`

**Goal:** Spring animations on list items, haptics on key interactions, improved empty state.

- [ ] **Step 1: Add haptics to FloatingAddButton**

Read `ChipIn/ChipIn/Components/FloatingAddButton.swift`. Find the Button action and add haptic after it opens the sheet:

```swift
UIImpactFeedbackGenerator(style: .medium).impactOccurred()
```

- [ ] **Step 2: Add haptics to PersonBalanceRow tap in HomeView**

Already handled in Task 4 via `.onTapGesture` in QuickAddView. For the NavigationLink in HomeView, add an `.onTapGesture` that fires haptic before navigation:

In the `NavigationLink` wrapping `PersonBalanceRow`, add `.simultaneousGesture` on the link:

```swift
.simultaneousGesture(TapGesture().onEnded {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
})
```

- [ ] **Step 3: Animate the Balances list section appearance**

In `HomeView.swift`, add `@State private var balancesAppeared = false` to the view.

Wrap the `LazyVStack` of balances in a `VStack` with animation modifier:

```swift
.opacity(balancesAppeared ? 1 : 0)
.offset(y: balancesAppeared ? 0 : 16)
.animation(ChipInTheme.spring.delay(0.15), value: balancesAppeared)
.onAppear { balancesAppeared = true }
```

- [ ] **Step 4: Improve empty state with gradient illustration**

Replace the `emptyActivityPlaceholder` computed property in `HomeView.swift`:

```swift
private var emptyActivityPlaceholder: some View {
    VStack(spacing: 20) {
        ZStack {
            Circle()
                .fill(ChipInTheme.accentGradient)
                .frame(width: 80, height: 80)
                .opacity(0.15)
            Text("💸")
                .font(.system(size: 40))
        }
        VStack(spacing: 6) {
            Text("You're all clear!")
                .font(.title3.weight(.bold))
                .foregroundStyle(ChipInTheme.label)
            Text("Add an expense with the + button, or use Quick Add (⚡️) to split in 3 taps.")
                .font(.subheadline)
                .foregroundStyle(ChipInTheme.secondaryLabel)
                .multilineTextAlignment(.center)
        }
    }
    .frame(maxWidth: .infinity)
    .padding(32)
    .background(ChipInTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .padding(.horizontal)
}
```

- [ ] **Step 5: Build and verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise && xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```

- [ ] **Step 6: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise && git add ChipIn/ChipIn/Features/Home/HomeView.swift ChipIn/ChipIn/Components/FloatingAddButton.swift && git commit -m "feat: gen-z polish — spring animations, haptics, gradient empty state"
```

---

## Task 8: Push to GitHub

- [ ] **Step 1: Push all commits**

```bash
cd /Users/deepak/Claude-projects/Splitwise && git push origin main
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] P0 Receipt scanning end-to-end → Task 1
- [x] P1 Expense comments → Task 2
- [x] P1 Animated balance / settled state → Task 3
- [x] P1 Swipe actions on PersonBalanceRow → Task 4
- [x] P1 Quick Add flow → Task 5
- [x] P2 Expense edit → Task 6
- [x] P2 Gen-Z visual polish → Tasks 3, 4, 7
- [x] `calculateItemSplits` for receipt-based unequal splits → Task 1
- [x] `CommentService` real data (no mocks) → Task 2

**Type consistency check:**
- `ParsedReceipt` / `ParsedReceipt.Item` — used in Tasks 1 (ViewModel), 1 (ExpenseService). Both reference `item.price`, `item.taxPortion`, `item.assignedTo` — matches `ReceiptService.swift` definition ✓
- `NewExpenseItem` — defined in `ExpenseService.swift:5-10`, used in Task 1 ViewModel — field names match ✓
- `Comment` — `expenseId`, `userId`, `body`, `createdAt` — used in Task 2 CommentService and ExpenseDetailView — matches `Comment.swift` ✓
- `PersonBalance` — `net`, `user.name`, `user.id` — used in Tasks 3, 4 — matches existing usage in HomeView ✓
- `SplitType.exact` — needs to exist in `SplitType` enum used in Task 1. Check `ChipIn/ChipIn/Models/Expense.swift` before implementing Task 1 — if `.exact` is missing, use `.equal` as fallback.

**No placeholders:** All steps have complete code.
