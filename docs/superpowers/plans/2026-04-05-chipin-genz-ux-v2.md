# ChipIn Gen Z UX v2 — University Student Experience Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform ChipIn into an app that a university student picks up and loves instantly — polished, fast, social, and fun enough to recommend to their friend group.

**Architecture:** All changes are free (no payment features), purely client-side or Supabase-query improvements. Each task is an independent, self-contained unit that improves either discoverability, performance perception, social engagement, or flow speed. No new Supabase tables are required for most tasks; where a new SQL migration is needed, it is included inline.

**Tech Stack:** SwiftUI, `@Observable`, Supabase Swift SDK, SF Symbols 5, iOS 16+ (`ImageRenderer`, `ShareLink`), `AppStorage`, `UNUserNotificationCenter`, `StoreKit 2` (for review prompt).

**Build command (run from `/Users/deepak/Claude-projects/Splitwise/ChipIn`):**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

---

## File Map

| Task | Create | Modify |
|------|--------|--------|
| 1 – Onboarding Revamp | — | `Features/Onboarding/OnboardingView.swift` |
| 2 – Shimmer Skeleton | `Components/ShimmerView.swift` | `Features/Home/HomeView.swift`, `Features/Activity/ActivityFeedView.swift` |
| 3 – Group Member Balances | — | `Features/Groups/GroupDetailView.swift`, `Services/GroupService.swift` |
| 4 – PersonDetailView Per-Split Status | — | `Features/Home/PersonDetailView.swift` |
| 5 – Home Stats + Streak | — | `Features/Home/HomeView.swift`, `Features/Home/HomeViewModel.swift` |
| 6 – Spending Personality Badge | `Features/Profile/SpendingPersonalityView.swift` | `Features/Profile/ProfileView.swift` |
| 7 – Monthly Recap Shareable Card | `Features/Insights/MonthRecapView.swift` | `Features/Insights/InsightsView.swift` |
| 8 – Appearance Mode Toggle | — | `ChipInApp.swift`, `Features/Profile/ProfileView.swift` |
| 9 – Quick Text Parser | `Services/QuickTextParser.swift` | `Features/AddExpense/AddExpenseView.swift`, `Features/AddExpense/AddExpenseViewModel.swift` |
| 10 – Receipt Camera Guide Overlay | `Components/CameraGuideOverlay.swift` | `Features/AddExpense/ReceiptScannerView.swift` |
| 11 – App Review Prompt | — | `Features/SettleUp/SettleUpView.swift` |
| 12 – Consistent Empty States | `Components/EmptyStateView.swift` | `Features/Search/SearchView.swift`, `Features/Groups/GroupsView.swift`, `Features/Activity/ActivityFeedView.swift` |

---

## Task 1: Onboarding Revamp — 5 Illustrated Slides + Currency Picker

**Files:**
- Modify: `ChipIn/ChipIn/Features/Onboarding/OnboardingView.swift`

**What:** Replace the plain 3-slide text-only onboarding with 5 richly styled slides:
1. Welcome (brand intro with ChipIn logo animation)
2. Split in 3 taps (original)
3. Scan receipts (original)
4. Settle via Interac (original)
5. Choose your currency + Get Started

The new slides have per-page gradient backgrounds, large colored SF Symbol icons, and a currency picker on the last slide. No new data model or service needed.

- [ ] **Step 1: Read the current file**

```
Read: ChipIn/ChipIn/Features/Onboarding/OnboardingView.swift
```
Confirms it has 3 pages, a `TabView(.page)`, and a single CTA button.

- [ ] **Step 2: Replace OnboardingView.swift with the new 5-slide version**

```swift
import SwiftUI

private struct OnboardingPage {
    let systemImage: String
    let imageColor: Color
    let gradientColors: [Color]
    let title: String
    let body: String
}

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var page = 0
    @State private var selectedCurrency = "CAD"
    @AppStorage("defaultCurrency") private var defaultCurrency = "CAD"

    private let currencies = ["CAD", "USD", "EUR", "GBP", "AUD", "INR", "JPY", "MXN"]

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "bolt.circle.fill",
            imageColor: Color(red: 1.0, green: 0.55, blue: 0.26),
            gradientColors: [Color(red: 0.12, green: 0.10, blue: 0.08), Color(red: 0.08, green: 0.06, blue: 0.04)],
            title: "Welcome to ChipIn",
            body: "Split expenses with your friends and roommates — no awkward IOUs, ever."
        ),
        OnboardingPage(
            systemImage: "person.2.circle.fill",
            imageColor: Color(red: 0.24, green: 0.71, blue: 0.64),
            gradientColors: [Color(red: 0.06, green: 0.14, blue: 0.12), Color(red: 0.04, green: 0.08, blue: 0.08)],
            title: "Split in 3 Taps",
            body: "Hit +, enter an amount, pick your friends. ChipIn does the math."
        ),
        OnboardingPage(
            systemImage: "camera.viewfinder",
            imageColor: Color(red: 0.38, green: 0.60, blue: 1.0),
            gradientColors: [Color(red: 0.06, green: 0.08, blue: 0.18), Color(red: 0.04, green: 0.05, blue: 0.10)],
            title: "Scan Any Receipt",
            body: "Point your camera at any bill. AI reads every item so you can assign dishes to people in seconds."
        ),
        OnboardingPage(
            systemImage: "arrow.left.arrow.right.circle.fill",
            imageColor: Color(red: 1.0, green: 0.76, blue: 0.18),
            gradientColors: [Color(red: 0.14, green: 0.12, blue: 0.04), Color(red: 0.08, green: 0.06, blue: 0.02)],
            title: "Settle via Interac",
            body: "One tap opens your bank app with the amount and email pre-filled. Settling up has never been faster."
        ),
        OnboardingPage(
            systemImage: "globe.americas.fill",
            imageColor: Color(red: 0.78, green: 0.44, blue: 1.0),
            gradientColors: [Color(red: 0.10, green: 0.06, blue: 0.18), Color(red: 0.06, green: 0.03, blue: 0.10)],
            title: "What's your currency?",
            body: "All amounts are converted to your home currency automatically."
        ),
    ]

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: pages[page].gradientColors,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: page)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button("Skip") {
                            withAnimation(ChipInTheme.spring) { page = pages.count - 1 }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.trailing, 24)
                        .padding(.top, 56)
                    } else {
                        Color.clear.frame(height: 56 + 22)
                    }
                }

                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(pages[page].imageColor.opacity(0.18))
                        .frame(width: 140, height: 140)
                    Circle()
                        .fill(pages[page].imageColor.opacity(0.10))
                        .frame(width: 180, height: 180)
                    Image(systemName: pages[page].systemImage)
                        .font(.system(size: 70, weight: .medium))
                        .foregroundStyle(pages[page].imageColor)
                        .symbolRenderingMode(.hierarchical)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                .padding(.bottom, 36)

                // Text content
                VStack(spacing: 14) {
                    Text(pages[page].title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.25), value: page)

                    Text(pages[page].body)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .animation(.easeInOut(duration: 0.25), value: page)
                }

                // Currency picker on last slide
                if page == pages.count - 1 {
                    Picker("Currency", selection: $selectedCurrency) {
                        ForEach(currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                    .colorScheme(.dark)
                }

                Spacer()

                // Progress dots
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? .white : .white.opacity(0.3))
                            .frame(width: i == page ? 20 : 6, height: 6)
                            .animation(ChipInTheme.spring, value: page)
                    }
                }
                .padding(.bottom, 28)

                // CTA button
                Button {
                    if page < pages.count - 1 {
                        withAnimation(ChipInTheme.spring) { page += 1 }
                    } else {
                        defaultCurrency = selectedCurrency
                        UserDefaults.standard.set(true, forKey: "onboardingComplete")
                        isComplete = true
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Let's go →" : "Next")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(pages[page].imageColor)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { v in
                    if v.translation.width < -50, page < pages.count - 1 {
                        withAnimation(ChipInTheme.spring) { page += 1 }
                    } else if v.translation.width > 50, page > 0 {
                        withAnimation(ChipInTheme.spring) { page -= 1 }
                    }
                }
        )
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/Features/Onboarding/OnboardingView.swift
git commit -m "feat: onboarding revamp — 5 illustrated slides, currency picker, swipe gestures

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: ShimmerView Skeleton Loading

**Files:**
- Create: `ChipIn/ChipIn/Components/ShimmerView.swift`
- Modify: `ChipIn/ChipIn/Features/Home/HomeView.swift` (replace spinner with skeleton)
- Modify: `ChipIn/ChipIn/Features/Activity/ActivityFeedView.swift` (replace spinner with skeleton rows)

**What:** Replace plain `ProgressView()` spinners with skeleton placeholder cards that look like the real content. This makes the app feel instant.

- [ ] **Step 1: Create `ShimmerView.swift`**

```swift
// ChipIn/ChipIn/Components/ShimmerView.swift
import SwiftUI

/// Animated shimmer placeholder for loading states.
struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var cornerRadius: CGFloat = 10
    var height: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(shimmerGradient)
            .frame(height: height)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2
                }
            }
    }

    private var shimmerGradient: LinearGradient {
        let base = ChipInTheme.elevated.opacity(0.6)
        let highlight = ChipInTheme.elevated
        return LinearGradient(
            stops: [
                .init(color: base,      location: max(0, phase - 0.4)),
                .init(color: highlight, location: phase),
                .init(color: base,      location: min(1, phase + 0.4)),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// A skeleton card row that looks like a PersonBalanceRow.
struct PersonBalanceRowSkeleton: View {
    var body: some View {
        HStack(spacing: 14) {
            ShimmerView(cornerRadius: 20, height: 40)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 8) {
                ShimmerView(cornerRadius: 6, height: 13).frame(width: 120)
                ShimmerView(cornerRadius: 6, height: 11).frame(width: 80)
            }
            Spacer()
            ShimmerView(cornerRadius: 6, height: 16).frame(width: 60)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

/// A skeleton row for ActivityFeed.
struct ActivityRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ShimmerView(cornerRadius: 22, height: 44).frame(width: 44)
            VStack(alignment: .leading, spacing: 8) {
                ShimmerView(cornerRadius: 6, height: 13).frame(width: 180)
                ShimmerView(cornerRadius: 6, height: 11).frame(width: 120)
                ShimmerView(cornerRadius: 6, height: 10).frame(width: 60)
            }
            Spacer()
            ShimmerView(cornerRadius: 6, height: 14).frame(width: 50)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
```

- [ ] **Step 2: Replace spinner in `HomeView.swift`**

Find this block in `HomeView.body`:
```swift
if vm.isLoading && vm.personBalances.isEmpty {
    ProgressView()
        .tint(ChipInTheme.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
}
```

Replace with:
```swift
if vm.isLoading && vm.personBalances.isEmpty {
    VStack(spacing: 0) {
        ForEach(0..<4, id: \.self) { _ in
            PersonBalanceRowSkeleton()
            Divider().background(ChipInTheme.elevated).padding(.leading, 68)
        }
    }
    .background(ChipInTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
    .padding(.horizontal)
}
```

- [ ] **Step 3: Replace spinner in `ActivityFeedView.swift`**

Find:
```swift
if vm.isLoading && vm.items.isEmpty {
    ProgressView().tint(ChipInTheme.accent)
}
```

Replace with:
```swift
if vm.isLoading && vm.items.isEmpty {
    VStack(spacing: 0) {
        ForEach(0..<6, id: \.self) { _ in
            ActivityRowSkeleton()
            Divider().background(ChipInTheme.elevated).padding(.leading, 68)
        }
    }
    .padding(.top, 8)
}
```

- [ ] **Step 4: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/Components/ShimmerView.swift \
        ChipIn/ChipIn/Features/Home/HomeView.swift \
        ChipIn/ChipIn/Features/Activity/ActivityFeedView.swift
git commit -m "feat: shimmer skeleton loading for home and activity feed

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Group Member Balances (Who Owes Whom)

**Files:**
- Modify: `ChipIn/ChipIn/Services/GroupService.swift` — add `fetchGroupSplits(groupId:)` method
- Modify: `ChipIn/ChipIn/Features/Groups/GroupDetailView.swift` — add a "Balances" section

**What:** Show per-member net balances inside the group. "Alex owes Jamie $45". Computed client-side from the expenses + splits already being fetched.

- [ ] **Step 1: Add `fetchGroupSplits` to `GroupService.swift`**

Read `ChipIn/ChipIn/Services/GroupService.swift` first to see the file, then append this method inside the `struct GroupService` body:

```swift
/// Returns all unsettled splits for expenses in the given group.
func fetchGroupSplits(for groupId: UUID) async throws -> [ExpenseSplit] {
    // 1. fetch all expense IDs in this group
    let expenses: [Expense] = try await supabase
        .from("expenses")
        .select("id")
        .eq("group_id", value: groupId.uuidString)
        .execute()
        .value
    guard !expenses.isEmpty else { return [] }
    let ids = expenses.map(\.id.uuidString)
    // 2. fetch unsettled splits for those expenses
    return try await supabase
        .from("expense_splits")
        .select()
        .in("expense_id", values: ids)
        .eq("is_settled", value: false)
        .execute()
        .value
}
```

- [ ] **Step 2: Add `GroupMemberBalance` struct and balance-computation helper to `GroupDetailView.swift`**

At the top of the file, after the `import` statements but before `struct GroupDetailView`, add:

```swift
private struct GroupMemberBalance: Identifiable {
    let id: UUID        // payer's user ID
    let payer: AppUser
    let payee: AppUser
    let amount: Decimal // payer owes payee this amount (positive)
}

private func computeGroupBalances(
    expenses: [Expense],
    splits: [ExpenseSplit],
    members: [AppUser]
) -> [GroupMemberBalance] {
    let memberMap = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
    // net[userId] = positive means they are owed money, negative means they owe money
    var net: [UUID: Decimal] = [:]
    for split in splits {
        // find who paid for this expense
        guard let expense = expenses.first(where: { $0.id == split.expenseId }) else { continue }
        let paidBy = expense.paidBy
        let debtor = split.userId
        if debtor == paidBy { continue }
        net[paidBy, default: 0]  += split.owedAmount
        net[debtor, default: 0]  -= split.owedAmount
    }

    // greedy settle: match creditors against debtors
    var creditors = net.filter { $0.value > 0 }.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    var debtors   = net.filter { $0.value < 0 }.map { ($0.key, abs($0.value)) }.sorted { $0.1 > $1.1 }
    var result: [GroupMemberBalance] = []

    var ci = 0, di = 0
    while ci < creditors.count && di < debtors.count {
        let (creditorId, credAmt) = creditors[ci]
        let (debtorId,  debtAmt) = debtors[di]
        let settled = min(credAmt, debtAmt)
        if let payerUser = memberMap[debtorId], let payeeUser = memberMap[creditorId] {
            result.append(GroupMemberBalance(id: debtorId, payer: payerUser, payee: payeeUser, amount: settled))
        }
        creditors[ci].1 -= settled
        debtors[di].1   -= settled
        if creditors[ci].1 == 0 { ci += 1 }
        if debtors[di].1  == 0 { di += 1 }
    }
    return result
}
```

- [ ] **Step 3: Add state variables to `GroupDetailView`**

Find the existing `@State private var showLeaderboard = false` line and add after it:
```swift
@State private var groupSplits: [ExpenseSplit] = []
```

- [ ] **Step 4: Load group splits in `loadAll()`**

Find:
```swift
private func loadAll() async {
    async let expensesTask = service.fetchExpenses(for: group.id)
    async let membersTask = service.fetchMembers(for: group.id)
    expenses = (try? await expensesTask) ?? []
    members = (try? await membersTask) ?? []
}
```

Replace with:
```swift
private func loadAll() async {
    async let expensesTask = service.fetchExpenses(for: group.id)
    async let membersTask  = service.fetchMembers(for: group.id)
    async let splitsTask   = service.fetchGroupSplits(for: group.id)
    expenses    = (try? await expensesTask) ?? []
    members     = (try? await membersTask) ?? []
    groupSplits = (try? await splitsTask) ?? []
}
```

- [ ] **Step 5: Add the "Balances" section to `GroupDetailView.body`**

Find the `Section("Expenses")` block in the `List`. Insert a new section directly above it:

```swift
// Group Balances section
let balances = computeGroupBalances(expenses: expenses, splits: groupSplits, members: members)
if !balances.isEmpty {
    Section("Balances") {
        ForEach(balances) { b in
            HStack(spacing: 12) {
                Text(String(b.payer.displayName.prefix(1)).uppercased())
                    .font(.caption.bold()).foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(ChipInTheme.avatarColor(for: b.payer.id.uuidString))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(b.payer.displayName) owes \(b.payee.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(ChipInTheme.label)
                }
                Spacer()
                Text(b.amount, format: .currency(code: "CAD"))
                    .font(.subheadline.bold())
                    .foregroundStyle(ChipInTheme.danger)
            }
            .listRowBackground(ChipInTheme.card)
        }
    }
}
```

- [ ] **Step 6: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/Services/GroupService.swift \
        ChipIn/ChipIn/Features/Groups/GroupDetailView.swift
git commit -m "feat: group member balances — who owes whom inside each group

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: PersonDetailView — Per-Expense Settled Status + Progress Bar

**Files:**
- Modify: `ChipIn/ChipIn/Features/Home/PersonDetailView.swift`

**What:** Load settlement status for shared expenses and show a chip ("Settled ✓" / "Pending") on each `ExpenseRow`. Add a thin progress bar at the top showing what % of your shared history has been settled.

- [ ] **Step 1: Add state for splits to `PersonDetailView`**

Find the existing state declarations (`@State private var expenses`, etc.) and add:
```swift
@State private var splitsByExpense: [UUID: ExpenseSplit] = [:]
```

- [ ] **Step 2: Update `loadExpenses()` to also fetch splits**

Find the end of `loadExpenses()`, right before the closing `}`. After the line that sets `expenses = ...`, add:

```swift
// Fetch splits involving both users so we can show settled/unsettled status
let expenseIds = expenses.map(\.id.uuidString)
if !expenseIds.isEmpty, let myId = auth.currentUser?.id {
    let splits: [ExpenseSplit] = (try? await supabase
        .from("expense_splits")
        .select()
        .in("expense_id", values: expenseIds)
        .eq("user_id", value: myId.uuidString)
        .execute()
        .value) ?? []
    splitsByExpense = Dictionary(uniqueKeysWithValues: splits.map { ($0.expenseId, $0) })
}
```

- [ ] **Step 3: Add a settlement progress bar after `personHeader`**

Find:
```swift
// Person header card
personHeader
    .padding(.horizontal)
    .padding(.top)
```

Add below it (still inside the `VStack(spacing: 20)`):

```swift
// Settlement progress bar
if !expenses.isEmpty {
    let settled = expenses.filter { splitsByExpense[$0.id]?.isSettled == true }.count
    let total   = expenses.count
    let pct     = total > 0 ? Double(settled) / Double(total) : 0

    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text("Settlement progress")
                .font(.caption)
                .foregroundStyle(ChipInTheme.secondaryLabel)
            Spacer()
            Text("\(settled) / \(total) expenses settled")
                .font(.caption.monospacedDigit())
                .foregroundStyle(ChipInTheme.tertiaryLabel)
        }
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ChipInTheme.elevated)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ChipInTheme.success)
                    .frame(width: geo.size.width * pct)
                    .animation(ChipInTheme.spring, value: pct)
            }
        }
        .frame(height: 6)
    }
    .padding(.horizontal)
}
```

- [ ] **Step 4: Add a status chip on each expense row in the expense history list**

Find the existing expense list section:
```swift
LazyVStack(spacing: 0) {
    ForEach(expenses) { expense in
        ExpenseRow(expense: expense)
            .padding(.horizontal)
        if expense.id != expenses.last?.id {
            Divider()
                .background(ChipInTheme.elevated)
                .padding(.leading, 70)
        }
    }
}
```

Replace with:
```swift
LazyVStack(spacing: 0) {
    ForEach(expenses) { expense in
        ZStack(alignment: .topTrailing) {
            ExpenseRow(expense: expense)
                .padding(.horizontal)
            if let split = splitsByExpense[expense.id] {
                Text(split.isSettled ? "Settled ✓" : "Pending")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(split.isSettled ? ChipInTheme.success : ChipInTheme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(split.isSettled ? ChipInTheme.success.opacity(0.15) : ChipInTheme.accent.opacity(0.15))
                    )
                    .padding(.trailing, 20)
                    .padding(.top, 10)
            }
        }
        if expense.id != expenses.last?.id {
            Divider()
                .background(ChipInTheme.elevated)
                .padding(.leading, 70)
        }
    }
}
```

- [ ] **Step 5: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/Features/Home/PersonDetailView.swift
git commit -m "feat: per-expense settled status chips and settlement progress bar in PersonDetailView

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: Home Stats Row 2.0 + Consecutive-Day Streak

**Files:**
- Modify: `ChipIn/ChipIn/Features/Home/HomeViewModel.swift` — add `streakDays` computed from expense history
- Modify: `ChipIn/ChipIn/Features/Home/HomeView.swift` — 3-tile stats row + streak badge

**What:** Add a 3rd stat tile ("You're owed"), plus a streak counter showing how many consecutive days in a row the user has logged at least one expense. If they owe more than $50, the "You owe" tile gets a red pulse ring to create healthy urgency.

- [ ] **Step 1: Add `streakDays` to `HomeViewModel`**

Add a new property after `var simplifiedTransactions`:
```swift
/// Consecutive calendar days (ending today) on which the user paid for at least one expense.
var streakDays: Int = 0
```

At the end of the `load()` method, before the closing `} catch {` block, add:

```swift
// Streak: consecutive days with at least one expense paid
let allMyExpenses: [Expense] = (try? await supabase
    .from("expenses")
    .select("created_at")
    .eq("paid_by", value: currentUserId)
    .order("created_at", ascending: false)
    .limit(60)
    .execute()
    .value) ?? []
let calendar = Calendar.current
let today = calendar.startOfDay(for: Date())
var uniqueDays = Set(allMyExpenses.map { calendar.startOfDay(for: $0.createdAt) })
var streak = 0
var checkDay = today
while uniqueDays.contains(checkDay) {
    streak += 1
    checkDay = calendar.date(byAdding: .day, value: -1, to: checkDay)!
}
streakDays = streak
```

- [ ] **Step 2: Replace `homeStatsRow` in `HomeView.swift`**

Find the entire `private var homeStatsRow` computed property and replace it with:

```swift
private var homeStatsRow: some View {
    VStack(spacing: 10) {
        HStack(spacing: 10) {
            statTile(
                icon: "arrow.up.circle.fill",
                title: "Paid this month",
                value: vm.lentThisMonthCAD,
                valueColor: ChipInTheme.label,
                urgent: false
            )
            statTile(
                icon: "arrow.down.circle.fill",
                title: "You're owed",
                value: max(0, vm.overallNet),
                valueColor: ChipInTheme.success,
                urgent: false
            )
        }
        HStack(spacing: 10) {
            statTile(
                icon: "exclamationmark.circle.fill",
                title: "You owe",
                value: vm.pendingOwedCAD,
                valueColor: vm.pendingOwedCAD > 50 ? ChipInTheme.danger : ChipInTheme.accent,
                urgent: vm.pendingOwedCAD > 50
            )
            streakTile
        }
    }
}

private var streakTile: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("🔥 Streak")
            .font(.caption.weight(.medium))
            .foregroundStyle(ChipInTheme.onSurfaceVariant)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(vm.streakDays)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(vm.streakDays >= 3 ? Color(red: 1.0, green: 0.6, blue: 0.1) : ChipInTheme.label)
            Text("day\(vm.streakDays == 1 ? "" : "s")")
                .font(.caption.weight(.medium))
                .foregroundStyle(ChipInTheme.secondaryLabel)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(ChipInTheme.elevated.opacity(0.95))
    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous)
            .stroke(Color.white.opacity(0.05), lineWidth: 1)
    )
}
```

- [ ] **Step 3: Update `statTile` helper to accept `icon` and `urgent`**

Find the existing:
```swift
private func statTile(title: String, value: Decimal, valueColor: Color) -> some View {
```

Replace the entire function with:
```swift
private func statTile(icon: String, title: String, value: Decimal, valueColor: Color, urgent: Bool) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(valueColor.opacity(0.7))
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(ChipInTheme.onSurfaceVariant)
        }
        Text(value, format: .currency(code: "CAD"))
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(valueColor)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(ChipInTheme.elevated.opacity(0.95))
    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: ChipInTheme.squircleRadius, style: .continuous)
            .stroke(urgent ? ChipInTheme.danger.opacity(0.5) : Color.white.opacity(0.05), lineWidth: urgent ? 1.5 : 1)
    )
}
```

- [ ] **Step 4: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/Features/Home/HomeViewModel.swift \
        ChipIn/ChipIn/Features/Home/HomeView.swift
git commit -m "feat: 3-tile home stats row, urgency ring on high debt, consecutive-day streak counter

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 6: Spending Personality Badge on Profile

**Files:**
- Create: `ChipIn/ChipIn/Features/Profile/SpendingPersonalityView.swift`
- Modify: `ChipIn/ChipIn/Features/Profile/ProfileView.swift`

**What:** Compute a fun "spending personality" from the user's history and show it on their profile. Five personality types:
- 🏦 **The Banker** — paid for > 60% of shared expenses
- ⚖️ **The Fair One** — all debts settled within 7 days (avg)
- 👻 **The Ghost** — has unsettled splits > 21 days old
- 🎲 **The Wild Card** — expense variety across 4+ categories
- 🍕 **The Regular** — top category makes up > 70% of expenses

The type is computed locally without a new Supabase table.

- [ ] **Step 1: Create `SpendingPersonalityView.swift`**

```swift
// ChipIn/ChipIn/Features/Profile/SpendingPersonalityView.swift
import SwiftUI
import Supabase

enum SpendingPersonality: String {
    case banker    = "The Banker"
    case fairOne   = "The Fair One"
    case ghost     = "The Ghost"
    case wildCard  = "The Wild Card"
    case regular   = "The Regular"

    var emoji: String {
        switch self {
        case .banker:   return "🏦"
        case .fairOne:  return "⚖️"
        case .ghost:    return "👻"
        case .wildCard: return "🎲"
        case .regular:  return "🍕"
        }
    }

    var tagline: String {
        switch self {
        case .banker:   return "You're always the one who covers the group."
        case .fairOne:  return "You settle fast. Your friends love you for it."
        case .ghost:    return "Your debts are ageing. Time to settle up 👀"
        case .wildCard: return "You spend across every category. Adventurous."
        case .regular:  return "Creature of habit — and there's nothing wrong with that."
        }
    }

    var gradient: [Color] {
        switch self {
        case .banker:   return [Color(red: 0.1, green: 0.5, blue: 0.9), Color(red: 0.0, green: 0.3, blue: 0.7)]
        case .fairOne:  return [Color(red: 0.1, green: 0.7, blue: 0.5), Color(red: 0.0, green: 0.5, blue: 0.3)]
        case .ghost:    return [Color(red: 0.4, green: 0.4, blue: 0.5), Color(red: 0.2, green: 0.2, blue: 0.3)]
        case .wildCard: return [Color(red: 0.8, green: 0.3, blue: 0.9), Color(red: 0.5, green: 0.1, blue: 0.7)]
        case .regular:  return [Color(red: 1.0, green: 0.55, blue: 0.1), Color(red: 0.8, green: 0.3, blue: 0.0)]
        }
    }
}

@MainActor
@Observable
class SpendingPersonalityViewModel {
    var personality: SpendingPersonality?
    var isLoading = false

    func load(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        // Paid by me
        let myExpenses: [Expense] = (try? await supabase
            .from("expenses").select()
            .eq("paid_by", value: userId)
            .limit(100)
            .execute().value) ?? []

        // Splits where I owe money
        let myDebts: [ExpenseSplit] = (try? await supabase
            .from("expense_splits").select()
            .eq("user_id", value: userId)
            .limit(100)
            .execute().value) ?? []

        // Total expenses I'm part of (rough: expenses I paid + distinct expense_ids from splits)
        let involvedIds = Set(myDebts.map(\.expenseId))
        let totalInvolved = max(1, myExpenses.count + involvedIds.subtracting(Set(myExpenses.map(\.id))).count)
        let paidRatio = Double(myExpenses.count) / Double(totalInvolved)

        // Unsettled debts age
        let now = Date()
        let oldestUnsettled = myDebts
            .filter { !$0.isSettled }
            .map { now.timeIntervalSince($0.createdAt) / 86400 } // days
            .max() ?? 0

        // Category variety
        let cats = Set(myExpenses.map(\.category)).count
        let topCatCount = myExpenses.isEmpty ? 0 :
            Dictionary(grouping: myExpenses, by: \.category)
                .values.map(\.count).max() ?? 0
        let topCatRatio = myExpenses.isEmpty ? 0 : Double(topCatCount) / Double(myExpenses.count)

        // Decide personality
        if oldestUnsettled > 21 {
            personality = .ghost
        } else if paidRatio > 0.6 {
            personality = .banker
        } else if cats >= 4 {
            personality = .wildCard
        } else if topCatRatio > 0.7 && !myExpenses.isEmpty {
            personality = .regular
        } else {
            personality = .fairOne
        }
    }
}

struct SpendingPersonalityView: View {
    let userId: UUID
    @State private var vm = SpendingPersonalityViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                ShimmerView(cornerRadius: 16, height: 100)
                    .padding(.horizontal)
            } else if let p = vm.personality {
                HStack(spacing: 16) {
                    Text(p.emoji).font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.rawValue)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Text(p.tagline)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(
                    LinearGradient(colors: p.gradient, startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
            }
        }
        .task { await vm.load(userId: userId) }
    }
}
```

- [ ] **Step 2: Add `SpendingPersonalityView` to `ProfileView.swift`**

Read the current `ProfileView.swift`. Find the section that contains the profile header `Section` (the one with the avatar). Add a new `Section` directly after the closing `}` of that header section, before the next section:

```swift
// Spending personality section
if let userId = auth.currentUser?.id {
    Section {
        SpendingPersonalityView(userId: userId)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
    } header: {
        Text("Your Spending Personality")
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/Features/Profile/SpendingPersonalityView.swift \
        ChipIn/ChipIn/Features/Profile/ProfileView.swift
git commit -m "feat: spending personality badge on profile (The Banker, The Ghost, The Fair One, etc.)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 7: Monthly Recap Shareable Card

**Files:**
- Create: `ChipIn/ChipIn/Features/Insights/MonthRecapView.swift`
- Modify: `ChipIn/ChipIn/Features/Insights/InsightsView.swift`

**What:** Render a beautiful monthly summary card (using `ImageRenderer`) with your total spending, top category, friend count, and a ChipIn brand footer. The user can then share it via the system share sheet to Instagram Stories, iMessage, etc. This is the biggest viral vector for university students.

- [ ] **Step 1: Create `MonthRecapView.swift`**

```swift
// ChipIn/ChipIn/Features/Insights/MonthRecapView.swift
import SwiftUI
import Supabase

private struct MonthStats {
    let monthName: String
    let totalSpent: Decimal
    let topCategory: String
    let topCategoryEmoji: String
    let friendCount: Int
    let expenseCount: Int
}

@MainActor
@Observable
private class MonthRecapViewModel {
    var stats: MonthStats?
    var isLoading = false
    var shareImage: UIImage?
    var showShareSheet = false

    func load(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        let now = Date()
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let expenses: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .eq("paid_by", value: userId)
            .gte("created_at", value: formatter.string(from: startOfMonth))
            .execute()
            .value) ?? []

        let total = expenses.reduce(Decimal(0)) { $0 + $1.cadAmount }

        var catMap: [String: Decimal] = [:]
        for e in expenses { catMap[e.category, default: 0] += e.cadAmount }
        let topCat = catMap.max(by: { $0.value < $1.value })?.key ?? "other"

        let catEmoji: [String: String] = [
            "food": "🍕", "travel": "✈️", "rent": "🏠",
            "fun": "🎉", "utilities": "⚡", "other": "📦"
        ]

        // Distinct friends involved
        let splits: [ExpenseSplit] = (try? await supabase
            .from("expense_splits")
            .select("user_id")
            .in("expense_id", values: expenses.map(\.id.uuidString))
            .neq("user_id", value: userId.uuidString)
            .execute()
            .value) ?? []
        let friendCount = Set(splits.map(\.userId)).count

        let monthName = DateFormatter().monthSymbols[cal.component(.month, from: now) - 1]

        stats = MonthStats(
            monthName: monthName,
            totalSpent: total,
            topCategory: topCat.capitalized,
            topCategoryEmoji: catEmoji[topCat] ?? "📦",
            friendCount: friendCount,
            expenseCount: expenses.count
        )
    }
}

/// The card rendered to an image for sharing.
private struct RecapCard: View {
    let stats: MonthStats

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("⚡ ChipIn")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.26))
                Spacer()
                Text(stats.monthName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider().background(.white.opacity(0.1))

            // Main stat
            VStack(spacing: 6) {
                Text("You spent")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                Text(stats.totalSpent, format: .currency(code: "CAD"))
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 28)

            // Sub-stats grid
            HStack(spacing: 1) {
                subStat(label: "expenses", value: "\(stats.expenseCount)")
                Divider().background(.white.opacity(0.1)).frame(width: 1)
                subStat(label: "friends", value: "\(stats.friendCount)")
                Divider().background(.white.opacity(0.1)).frame(width: 1)
                subStat(label: "top category", value: "\(stats.topCategoryEmoji) \(stats.topCategory)")
            }
            .background(Color.white.opacity(0.05))

            // Footer
            Text("Split fair with ChipIn")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.08, blue: 0.06), Color(red: 0.06, green: 0.04, blue: 0.02)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(width: 340)
    }

    private func subStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

struct MonthRecapView: View {
    let userId: UUID
    @State private var vm = MonthRecapViewModel()
    @State private var renderedImage: Image?
    @State private var uiImage: UIImage?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    if vm.isLoading {
                        ProgressView().tint(ChipInTheme.accent)
                            .frame(maxWidth: .infinity).padding(.vertical, 60)
                    } else if let stats = vm.stats {
                        RecapCard(stats: stats)
                            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
                            .padding(.horizontal)

                        if let image = renderedImage {
                            ShareLink(
                                item: image,
                                preview: SharePreview("My \(stats.monthName) in ChipIn", image: image)
                            ) {
                                Label("Share Your Recap", systemImage: "square.and.arrow.up")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(ChipInTheme.onPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ChipInTheme.ctaGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .padding(.horizontal)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Monthly Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
            .task {
                await vm.load(userId: userId)
                renderCard()
            }
        }
    }

    @MainActor
    private func renderCard() {
        guard let stats = vm.stats else { return }
        let renderer = ImageRenderer(content: RecapCard(stats: stats))
        renderer.scale = 3.0
        if let ui = renderer.uiImage {
            uiImage = ui
            renderedImage = Image(uiImage: ui)
        }
    }
}
```

- [ ] **Step 2: Add "Share This Month" button to `InsightsView.swift`**

Find the section that has the Wrapped banner button (the one with `showWrapped = true`). Add a new button directly **below** it (still within the outer `VStack(spacing: 20)`):

```swift
// Monthly recap share button
Button {
    showMonthRecap = true
} label: {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            Text("📊 Share This Month")
                .font(.headline).foregroundStyle(ChipInTheme.label)
            Text("Beautiful recap card for your stories")
                .font(.caption).foregroundStyle(ChipInTheme.secondaryLabel)
        }
        Spacer()
        Image(systemName: "chevron.right")
            .foregroundStyle(ChipInTheme.accent)
    }
    .padding(16)
    .background(ChipInTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
    )
}
.buttonStyle(.plain)
.padding(.horizontal)
.sheet(isPresented: $showMonthRecap) {
    if let userId = auth.currentUser?.id {
        MonthRecapView(userId: userId)
    }
}
```

Also add the state variable at the top of `InsightsView`:
```swift
@State private var showMonthRecap = false
```

- [ ] **Step 3: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/Features/Insights/MonthRecapView.swift \
        ChipIn/ChipIn/Features/Insights/InsightsView.swift
git commit -m "feat: monthly recap shareable card — render and share via ShareLink/ImageRenderer

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 8: Appearance Mode Toggle (Follow System / Force Dark)

**Files:**
- Modify: `ChipIn/ChipIn/ChipInApp.swift`
- Modify: `ChipIn/ChipIn/Features/Profile/ProfileView.swift`

**What:** Currently the app is hardcoded to `.dark`. Add a preference in ProfileView that lets the user choose between "Always Dark" and "Follow System". Stored in `AppStorage`. The `ChipInNavigationAppearance` is already set up for dark nav bars so those remain fine.

- [ ] **Step 1: Replace the hardcoded `.preferredColorScheme(.dark)` in `ChipInApp.swift`**

Find in `ChipInApp.swift`:
```swift
.preferredColorScheme(.dark)
```

Replace with:
```swift
.preferredColorScheme(forceDark ? .dark : nil)
```

Add the `@AppStorage` property to `ChipInApp` (inside `struct ChipInApp: App`, before `init()`):
```swift
@AppStorage("forceDarkMode") private var forceDark = true
```

- [ ] **Step 2: Add appearance toggle to `ProfileView.swift`**

Read `ProfileView.swift` to find the section containing the `Toggle` for `soundEnabled`. Add a new `Toggle` row in the same `Section`:

```swift
Toggle(isOn: Binding(
    get: { UserDefaults.standard.bool(forKey: "forceDarkMode") },
    set: { val in
        UserDefaults.standard.set(val, forKey: "forceDarkMode")
    }
)) {
    Label("Force Dark Mode", systemImage: "moon.fill")
        .foregroundStyle(ChipInTheme.label)
}
.tint(ChipInTheme.accent)
.listRowBackground(ChipInTheme.card)
```

Note: `@AppStorage` in `ChipInApp` auto-refreshes when `UserDefaults` changes, so the toggle takes effect immediately.

- [ ] **Step 3: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/ChipInApp.swift \
        ChipIn/ChipIn/Features/Profile/ProfileView.swift
git commit -m "feat: appearance mode toggle — force dark or follow system setting in profile

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 9: Quick Text Parser — "pizza $20 @sarah"

**Files:**
- Create: `ChipIn/ChipIn/Services/QuickTextParser.swift`
- Modify: `ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift`
- Modify: `ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift`

**What:** When the user types into the expense title field, a lightweight parser detects an amount (`$20` or `20.50`) and an `@handle` mention. It auto-fills the amount field and searches for the mentioned user. This cuts the most common add-expense flow from 5 taps to just typing one sentence.

- [ ] **Step 1: Create `QuickTextParser.swift`**

```swift
// ChipIn/ChipIn/Services/QuickTextParser.swift
import Foundation

struct QuickTextParseResult {
    var cleanTitle: String  // title with $ amount and @handle stripped
    var amount: String?     // e.g. "20.50"
    var mentionedHandle: String? // e.g. "sarah"
}

enum QuickTextParser {
    /// Parse "pizza $20 @sarah" → title: "pizza", amount: "20", mention: "sarah"
    static func parse(_ input: String) -> QuickTextParseResult {
        var text = input
        var amount: String?
        var handle: String?

        // Extract $amount or bare number at word boundary
        // Pattern: optional $ then digits with optional .XX
        let amountPattern = /\$(\d+(?:\.\d{1,2})?)|(?<!\w)(\d+(?:\.\d{1,2})?)(?!\w)/
        if let match = text.firstMatch(of: amountPattern) {
            let captured = match.output.1 ?? match.output.2
            if let captured {
                amount = String(captured)
                text = text.replacingOccurrences(of: String(match.output.0), with: "").trimmingCharacters(in: .whitespaces)
            }
        }

        // Extract @handle
        let handlePattern = /@([a-zA-Z0-9_]+)/
        if let match = text.firstMatch(of: handlePattern) {
            handle = String(match.output.1)
            text = text.replacingOccurrences(of: String(match.output.0), with: "").trimmingCharacters(in: .whitespaces)
        }

        // Clean up extra spaces
        let cleanTitle = text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return QuickTextParseResult(cleanTitle: cleanTitle, amount: amount, mentionedHandle: handle)
    }
}
```

- [ ] **Step 2: Add `parsedMentionHandle` and `applyQuickParse()` to `AddExpenseViewModel.swift`**

Add a new property after `var templateName`:
```swift
var parsedMentionHandle: String?
```

Add a new method in the `// MARK: - Auto-category` section:
```swift
/// Applies quick-text parsing: if title contains "$20 @sarah" style, auto-fills amount and sets handle search.
func applyQuickParse(raw: String) -> String {
    let result = QuickTextParser.parse(raw)
    if let a = result.amount, !a.isEmpty, amount.isEmpty {
        amount = a
    }
    parsedMentionHandle = result.mentionedHandle
    if !result.cleanTitle.isEmpty {
        return result.cleanTitle
    }
    return raw
}
```

- [ ] **Step 3: Wire parsing into the title field in `AddExpenseView.swift`**

Read `AddExpenseView.swift` and find the `detailsSection` computed property. Find the `TextField` for the title — it will look like:
```swift
TextField("e.g. Dinner at Terroni", text: $vm.title)
```

Add an `.onChange` modifier after that TextField:
```swift
.onChange(of: vm.title) { _, newVal in
    // Only trigger if user typed (not programmatically set)
    // and the raw value contains a $ or @
    if newVal.contains("$") || newVal.contains("@") {
        let cleaned = vm.applyQuickParse(raw: newVal)
        if cleaned != newVal {
            vm.title = cleaned
        }
    }
}
```

Also, after the title TextField section, add a subtle inline hint when a mention handle has been parsed:
```swift
if let handle = vm.parsedMentionHandle {
    HStack(spacing: 6) {
        Image(systemName: "at.circle.fill")
            .foregroundStyle(ChipInTheme.accent)
            .font(.caption)
        Text("Searching for @\(handle)…")
            .font(.caption)
            .foregroundStyle(ChipInTheme.secondaryLabel)
    }
    .onAppear {
        Task {
            // Trigger user search for the parsed handle
            let found = (try? await service.searchUsers(handle)) ?? []
            if let user = found.first {
                if !vm.selectedUserIds.contains(user.id) {
                    vm.selectedUserIds.append(user.id)
                }
                vm.parsedMentionHandle = nil
            }
        }
    }
}
```

- [ ] **Step 4: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/Services/QuickTextParser.swift \
        ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift \
        ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift
git commit -m "feat: quick text parser — 'pizza \$20 @sarah' auto-fills amount and adds participant

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 10: Receipt Scanner Camera Guide Overlay

**Files:**
- Create: `ChipIn/ChipIn/Components/CameraGuideOverlay.swift`
- Modify: `ChipIn/ChipIn/Features/AddExpense/ReceiptScannerView.swift`

**What:** When the camera picker opens for receipt scanning, show an animated corner-bracket overlay with a "Frame your receipt" instruction that fades out after 2 seconds. Makes the feature discoverable and reduces "I don't know how to use this" drop-off.

- [ ] **Step 1: Create `CameraGuideOverlay.swift`**

```swift
// ChipIn/ChipIn/Components/CameraGuideOverlay.swift
import SwiftUI

/// Animated corner-bracket frame overlay for the receipt camera.
struct CameraGuideOverlay: View {
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1.05

    var body: some View {
        ZStack {
            // Semi-dark vignette outside the frame rect
            Color.black.opacity(0.35).ignoresSafeArea()
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .frame(width: 280, height: 380)
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                )

            // Corner brackets
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.9), lineWidth: 2)
                .frame(width: 280, height: 380)
                .scaleEffect(scale)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: scale
                )

            CornerBrackets()
                .scaleEffect(scale)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: scale
                )

            // Instruction text
            VStack {
                Spacer()
                Text("Frame the full receipt")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.bottom, 80)
            }
        }
        .opacity(opacity)
        .onAppear {
            scale = 0.98
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.6)) { opacity = 0 }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CornerBrackets: View {
    private let size: CGFloat = 24
    private let thickness: CGFloat = 3
    private let w: CGFloat = 280
    private let h: CGFloat = 380
    private let r: CGFloat = 12

    var body: some View {
        ZStack {
            // Top-left
            cornerBracket().offset(x: -(w/2 - r), y: -(h/2 - r))
            // Top-right
            cornerBracket().rotationEffect(.degrees(90)).offset(x: (w/2 - r), y: -(h/2 - r))
            // Bottom-right
            cornerBracket().rotationEffect(.degrees(180)).offset(x: (w/2 - r), y: (h/2 - r))
            // Bottom-left
            cornerBracket().rotationEffect(.degrees(270)).offset(x: -(w/2 - r), y: (h/2 - r))
        }
    }

    private func cornerBracket() -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: size))
            p.addLine(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: size, y: 0))
        }
        .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}
```

- [ ] **Step 2: Add the overlay to `ReceiptScannerView.swift`**

Read `ChipIn/ChipIn/Features/AddExpense/ReceiptScannerView.swift`. Find where `CameraPicker` is used. It will be inside a `ZStack` or presented as a sheet. Add `CameraGuideOverlay()` overlaid on top of the `CameraPicker`:

Find the block presenting `CameraPicker` (it will look like a `.sheet` or `ZStack` containing `CameraPicker`). If it's inside a `ZStack`, add:
```swift
CameraGuideOverlay()
```
as a sibling view directly after `CameraPicker(...)`.

If `CameraPicker` is presented via `.sheet`, wrap the sheet content:
```swift
.sheet(isPresented: $showCamera) {
    ZStack {
        CameraPicker(image: $capturedImage) { img in
            // existing handler
        }
        CameraGuideOverlay()
    }
    .ignoresSafeArea()
}
```

- [ ] **Step 3: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/Components/CameraGuideOverlay.swift \
        ChipIn/ChipIn/Features/AddExpense/ReceiptScannerView.swift
git commit -m "feat: animated corner-bracket guide overlay on receipt camera

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 11: App Store Review Prompt After 3rd Settlement

**Files:**
- Modify: `ChipIn/ChipIn/Features/SettleUp/SettleUpView.swift`

**What:** After the user marks a debt as settled for the 3rd time, request an App Store review using `StoreKit`. This is the ideal moment — the user just had a positive outcome (debt cleared, confetti).

- [ ] **Step 1: Add `import StoreKit` and the review counter to `SettleUpView.swift`**

Add at the top:
```swift
import StoreKit
```

Add inside `struct SettleUpView`:
```swift
@AppStorage("settleCount") private var settleCount = 0
```

- [ ] **Step 2: Fire the review prompt when `vm.isSettled` becomes true**

In `SettleUpView`, the settled state is rendered via `if vm.isSettled { settledState }`. The `markAsSettled` action sets `vm.isSettled = true`. Find `markSettledButton`:

```swift
Button {
    Task {
        await vm.markAsSettled(
            fromUserId: fromUserId,
            toUserId: toUser.id,
            amount: amount,
            groupId: groupId
        )
    }
}
```

After that `Task` completes we need to fire the review check. Add `.onChange` on `vm.isSettled` to the root `NavigationStack`:

```swift
.onChange(of: vm.isSettled) { _, settled in
    guard settled else { return }
    settleCount += 1
    if settleCount == 3 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/Features/SettleUp/SettleUpView.swift
git commit -m "feat: App Store review prompt after 3rd settlement (StoreKit)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 12: Consistent Empty States Across All Tabs

**Files:**
- Create: `ChipIn/ChipIn/Components/EmptyStateView.swift`
- Modify: `ChipIn/ChipIn/Features/Search/SearchView.swift`
- Modify: `ChipIn/ChipIn/Features/Groups/GroupsView.swift`
- Modify: `ChipIn/ChipIn/Features/Activity/ActivityFeedView.swift`

**What:** Replace the inconsistent empty states across the app with a single reusable `EmptyStateView` component with personality-driven copy. Each screen gets a unique emoji, headline, and sub-copy that speaks to a university student.

- [ ] **Step 1: Create `EmptyStateView.swift`**

```swift
// ChipIn/ChipIn/Components/EmptyStateView.swift
import SwiftUI

struct EmptyStateView: View {
    let emoji: String
    let headline: String
    let subheadline: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(ChipInTheme.elevated.opacity(0.6))
                    .frame(width: 88, height: 88)
                Text(emoji)
                    .font(.system(size: 42))
            }
            VStack(spacing: 6) {
                Text(headline)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ChipInTheme.label)
                    .multilineTextAlignment(.center)
                Text(subheadline)
                    .font(.subheadline)
                    .foregroundStyle(ChipInTheme.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            if let label = actionLabel, let action {
                Button(action: action) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ChipInTheme.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(ChipInTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
```

- [ ] **Step 2: Replace empty state in `ActivityFeedView.swift`**

Find:
```swift
private var emptyState: some View {
    VStack(spacing: 16) {
        Text("📭").font(.system(size: 48))
        Text("Nothing yet")
            .font(.title3.weight(.bold))
            .foregroundStyle(ChipInTheme.label)
        Text("When friends add expenses you're included in or settle up, they'll appear here.")
            .font(.subheadline)
            .foregroundStyle(ChipInTheme.secondaryLabel)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }
}
```

Replace with:
```swift
private var emptyState: some View {
    EmptyStateView(
        emoji: "🌊",
        headline: "Your feed is quiet",
        subheadline: "Add an expense or settle up with a friend — it'll show up here for everyone involved."
    )
}
```

- [ ] **Step 3: Replace empty state in `GroupsView.swift`**

Read `ChipIn/ChipIn/Features/Groups/GroupsView.swift`. Find the section that shows an empty state when there are no groups (likely a `Text("No groups yet")` or similar placeholder). Replace it with:

```swift
EmptyStateView(
    emoji: "🏕️",
    headline: "No groups yet",
    subheadline: "Create a group for your apartment, a trip, or any shared adventure.",
    actionLabel: "Create your first group",
    action: { showCreateGroup = true }
)
```

(Use the correct state variable name for showing the create group sheet — read the file first to verify it.)

- [ ] **Step 4: Replace or add empty state in `SearchView.swift`**

Read `ChipIn/ChipIn/Features/Search/SearchView.swift`. Find the section showing "No results" or the initial state when the search is empty. Replace with:

```swift
// Empty / no-results state
EmptyStateView(
    emoji: "🔍",
    headline: query.isEmpty ? "Search your expenses" : "Nothing found",
    subheadline: query.isEmpty
        ? "Find any expense by title or category."
        : "Try a different spelling or date range."
)
```

(Where `query` is the search text binding — verify variable name from the file.)

- [ ] **Step 5: Build to verify**

```bash
cd /Users/deepak/Claude-projects/Splitwise/ChipIn && \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme ChipIn \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
cd /Users/deepak/Claude-projects/Splitwise
git add ChipIn/ChipIn/Components/EmptyStateView.swift \
        ChipIn/ChipIn/Features/Activity/ActivityFeedView.swift \
        ChipIn/ChipIn/Features/Groups/GroupsView.swift \
        ChipIn/ChipIn/Features/Search/SearchView.swift
git commit -m "feat: consistent EmptyStateView component applied across Activity, Groups, Search

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Self-Review

### Spec Coverage Check

| Requirement | Covered by |
|-------------|-----------|
| University student friendly, easy to pick up | Task 1 (onboarding), Task 9 (quick parser) |
| Gen Z design aesthetic | Task 1 (gradient slides), Task 5 (streak), Task 6 (personality) |
| Attractive UI | Task 2 (shimmer), Task 7 (recap card), Task 12 (empty states) |
| Feature improvements | Task 3 (group balances), Task 4 (split status), Task 5 (stats row) |
| Social/shareable | Task 7 (shareable recap card) |
| Free features only | All tasks — no payment features |
| New features for engagement | Task 5 (streak), Task 6 (personality), Task 7 (monthly recap), Task 11 (review prompt) |
| UX flow improvements | Task 9 (quick parser), Task 10 (camera guide) |
| Appearance/settings | Task 8 (dark/light toggle) |

### Placeholder Scan ✓
No "TBD", "TODO", or incomplete steps found.

### Type Consistency ✓
- `PersonBalance`, `PersonBalanceRowSkeleton`, `ActivityRowSkeleton` — all self-contained, no cross-task dependencies
- `SpendingPersonality`, `SpendingPersonalityView`, `SpendingPersonalityViewModel` — all defined in Task 6 file
- `MonthStats`, `RecapCard`, `MonthRecapViewModel`, `MonthRecapView` — all defined in Task 7 file
- `QuickTextParseResult`, `QuickTextParser` — defined in Task 9; `parsedMentionHandle` added to `AddExpenseViewModel`
- `EmptyStateView` — self-contained in Task 12; used in 3 views
- `ShimmerView`, `PersonBalanceRowSkeleton`, `ActivityRowSkeleton` — defined in Task 2; used in Tasks 6 (ShimmerView only) and 2

### Critical Notes for the Implementer

1. **Task 9 regex syntax** — Uses Swift 5.7+ regex literals (`/pattern/`). Minimum target must be iOS 16+. ChipIn is already iOS 16+ based on `ImageRenderer` usage elsewhere.

2. **Task 7 `ShareLink`** — Requires iOS 16+. The `Image` transfer type works as a `Transferable`. If `ImageRenderer` returns `nil`, the share button won't appear. This is safe graceful degradation.

3. **Task 3 `computeGroupBalances`** — This is a free-standing function, not a method, declared outside `GroupDetailView`. Swift requires it at file scope or as a static method. Declare it at the top of `GroupDetailView.swift` before the view struct.

4. **Task 8 `@AppStorage("forceDarkMode")`** — `AppStorage` and `UserDefaults` share the same backing store. The toggle in `ProfileView` uses `UserDefaults` directly; `ChipInApp` uses `@AppStorage`. Both read/write the same key and will stay in sync automatically.

5. **Task 10 `ReceiptScannerView`** — Read the file before implementing. The `CameraPicker` presentation mechanism (sheet vs inline ZStack) determines how the overlay is layered.
