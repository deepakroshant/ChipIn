# ChipIn: University Student UX & Social Features Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform ChipIn from a functional expense splitter into an exciting, sticky social app that university students actually want to open — zero payment features, all free, built around speed, fun, and social glue.

**Architecture:** Add a social layer (reactions, activity feed, friend graph) on top of the existing Supabase backend; auto-intelligence (smart category detection, template system) to reduce friction; and delight features (Wrapped summary, leaderboard, QR friend-add, profile photos) that give students a reason to share the app.

**Tech Stack:** SwiftUI iOS 17+, `@Observable`, Supabase (new tables: `reactions`, `friendships`, `expense_templates`), Gemini AI (existing edge function extended), `PhotosUI.PhotosPicker`, `CoreImage` for QR generation, `Charts` (already used in Insights).

---

## Overview of All Features

| # | Feature | New Tables | Effort |
|---|---------|-----------|--------|
| 1 | Smart Auto-Category | none | XS |
| 2 | Expense Templates | `expense_templates` | S |
| 3 | Emoji Reactions | `reactions` | S |
| 4 | Activity Feed Tab | none (query existing) | M |
| 5 | Profile Picture | storage bucket `avatars` | M |
| 6 | QR Code Friend-Add | none | M |
| 7 | Group Leaderboard | none (query existing) | S |
| 8 | Tip Calculator | none | XS |
| 9 | ChipIn Wrapped | none (query existing) | M |
| 10 | Recurring Expense Alerts | `recurring_reminders` | M |

---

## File Structure

**New files to create:**
```
ChipIn/ChipIn/
├── Features/
│   ├── Activity/
│   │   ├── ActivityFeedView.swift          # Tab 3 replacement (replaces Search → moved to tab 4)
│   │   └── ActivityFeedViewModel.swift     # Loads friend + group activity
│   ├── Reactions/
│   │   └── ReactionsBar.swift              # Inline emoji reaction row component
│   ├── Friends/
│   │   ├── FriendQRView.swift              # Show own QR + scan friend QR
│   │   └── FriendService.swift             # friendship CRUD
│   ├── Wrapped/
│   │   └── WrappedView.swift               # Semester in review full-screen
│   └── Groups/
│       └── GroupLeaderboardView.swift      # Fun stats sheet
├── Components/
│   ├── TipCalculatorView.swift             # Reusable tip picker
│   ├── CategoryDetector.swift              # Keyword → ExpenseCategory logic
│   └── TemplatePickerView.swift            # Template selection sheet
└── Services/
    ├── AvatarService.swift                 # Upload/download profile photo
    └── TemplateService.swift               # Save/load expense templates
```

**Files to modify:**
```
ChipIn/ChipIn/
├── ContentView.swift                       # Add Activity tab (tab 2), shift others
├── Features/
│   ├── Home/HomeView.swift                 # Add "Wrapped" banner card
│   ├── AddExpense/AddExpenseView.swift     # Smart category, tip calc, templates
│   ├── AddExpense/AddExpenseViewModel.swift# categoryFromTitle(), tip handling
│   ├── Expenses/ExpenseDetailView.swift    # Add ReactionsBar below splits
│   ├── Groups/GroupDetailView.swift        # Add Leaderboard button
│   └── Profile/ProfileView.swift          # Add avatar picker
supabase/
├── migrations/011_reactions.sql
├── migrations/012_friendships.sql
└── migrations/013_expense_templates.sql
```

---

## Task 1: Smart Auto-Category Detection

**What it does:** When a user types an expense title, ChipIn instantly picks the category. "Pizza Hut" → Food. "Uber" → Travel. "Spotify" → Fun. No tapping required.

**Files:**
- Create: `ChipIn/ChipIn/Components/CategoryDetector.swift`
- Modify: `ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift`
- Modify: `ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift`

- [ ] **Step 1: Create CategoryDetector**

Create `ChipIn/ChipIn/Components/CategoryDetector.swift`:

```swift
import Foundation

/// Pure function — maps a title string to the most likely ExpenseCategory.
/// Keyword matching is case-insensitive and checks word prefixes.
enum CategoryDetector {
    static func detect(from title: String) -> ExpenseCategory? {
        let t = title.lowercased()

        let rules: [(keywords: [String], category: ExpenseCategory)] = [
            // Food & Drink
            (["pizza", "burger", "sushi", "taco", "shawarma", "pho", "ramen",
              "coffee", "tim hortons", "mcdonalds", "subway", "chipotle", "kfc",
              "wendy", "starbucks", "bubble tea", "boba", "grocery", "superstore",
              "loblaws", "metro", "freshmart", "food", "restaurant", "dinner",
              "lunch", "breakfast", "cafe", "bakery", "bar", "pub", "drinks",
              "beer", "wine", "alcohol", "dominos", "pizza hut", "swiss chalet",
              "harveys", "a&w", "popeyes", "dine", "eat", "meal"], .food),

            // Travel
            (["uber", "lyft", "taxi", "transit", "ttc", "go train", "via rail",
              "flight", "airbnb", "hotel", "motel", "hostel", "parking", "gas",
              "petro", "shell", "esso", "trip", "travel", "bus", "subway pass",
              "presto", "rental car", "zipcar", "bicycle", "bike", "ferry",
              "greyhound", "amtrak", "car", "tolls", "airport"], .travel),

            // Rent & Home
            (["rent", "hydro", "electricity", "water", "internet", "wifi",
              "bell", "rogers", "telus", "shaw", "maintenance", "furniture",
              "ikea", "home depot", "cleaning", "supplies", "laundry",
              "apartment", "condo", "house", "mortgage", "utilities", "lease",
              "storage", "moving"], .rent),

            // Fun & Entertainment
            (["netflix", "spotify", "disney", "apple tv", "prime", "hulu",
              "youtube", "twitch", "game", "steam", "playstation", "xbox",
              "movie", "cinema", "concert", "ticket", "event", "festival",
              "bowling", "escape room", "arcade", "karaoke", "club", "nightclub",
              "museum", "zoo", "aquarium", "theme park", "ski", "snowboard",
              "camping", "gym", "fitness", "yoga", "class", "hike", "golf",
              "sport", "league", "hobby", "art", "craft"], .fun),

            // Utilities
            (["phone", "phone bill", "data plan", "subscription", "insurance",
              "textbook", "course", "tuition", "amazon", "walmart", "costco",
              "office", "stationary", "printer", "laptop", "tech", "electronics",
              "apple store", "best buy", "health", "pharmacy", "drugstore",
              "shoppers", "rexall", "medical", "dentist", "haircut", "barber",
              "salon"], .utilities),
        ]

        for rule in rules {
            for keyword in rule.keywords {
                if t.contains(keyword) {
                    return rule.category
                }
            }
        }
        return nil // nil = let user pick
    }
}
```

- [ ] **Step 2: Wire auto-detect into AddExpenseViewModel**

In `AddExpenseViewModel.swift`, find the `title` `@State` (or equivalent stored property). Add a method that fires when title changes:

```swift
// Add this method to AddExpenseViewModel:
func autoDetectCategory(from title: String) {
    guard category == .other || category == ExpenseCategory.allCases.first else { return }
    // Only auto-fill if user hasn't manually picked a non-default category
    if let detected = CategoryDetector.detect(from: title) {
        category = detected
    }
}
```

> If `AddExpenseViewModel` uses a `@Published var title: String` (or `@Observable` stored property), add a `didSet` or an `.onChange` watcher. If it's `@Observable`, add the call inside the setter body or from the view's `.onChange`.

- [ ] **Step 3: Call auto-detect from AddExpenseView**

In `AddExpenseView.swift`, find the title `TextField`. Add `.onChange(of: vm.title)` immediately after it:

```swift
TextField("What was it for?", text: $vm.title)
    // ... existing modifiers ...
    .onChange(of: vm.title) { _, newTitle in
        vm.autoDetectCategory(from: newTitle)
    }
```

- [ ] **Step 4: Add a subtle "auto-detected" indicator**

In `AddExpenseView.swift`, near the category picker, add a small chip that appears when auto-detection fires:

```swift
// Find the category picker row and add below it:
if vm.wasAutoDetected {
    HStack(spacing: 4) {
        Image(systemName: "sparkles")
            .font(.caption2)
        Text("Auto-detected")
            .font(.caption2)
    }
    .foregroundStyle(ChipInTheme.accent.opacity(0.8))
    .transition(.opacity.combined(with: .scale(0.9)))
}
```

Add `@State var wasAutoDetected = false` to the ViewModel (or View), and set it to `true` inside `autoDetectCategory()` when a match is found, and `false` when the user manually changes category.

- [ ] **Step 5: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Manual test in simulator**

Run app → Add Expense → type "Pizza Hut" → category should snap to Food with sparkle chip. Type "Uber" → Travel. Type "asdf" → stays on current pick.

- [ ] **Step 7: Commit**

```bash
git add ChipIn/ChipIn/Components/CategoryDetector.swift \
        ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift \
        ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift
git commit -m "feat: smart auto-category detection from expense title keywords"
```

---

## Task 2: Built-in Tip Calculator

**What it does:** When category is Food or Fun, a "Add Tip" row appears in the Add Expense form. User picks 15%/18%/20%/custom. Tip is added to total and distributed proportionally across splits.

**Files:**
- Create: `ChipIn/ChipIn/Components/TipCalculatorView.swift`
- Modify: `ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift`
- Modify: `ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift`

- [ ] **Step 1: Create TipCalculatorView component**

Create `ChipIn/ChipIn/Components/TipCalculatorView.swift`:

```swift
import SwiftUI

struct TipCalculatorView: View {
    let subtotal: Decimal
    @Binding var tipAmount: Decimal

    @State private var selectedPercent: Int? = nil
    @State private var customText: String = ""
    @FocusState private var customFocused: Bool

    private let presets = [15, 18, 20]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tip", systemImage: "heart.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ChipInTheme.label)

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { pct in
                    Button {
                        selectedPercent = pct
                        customText = ""
                        customFocused = false
                        tipAmount = (subtotal * Decimal(pct)) / 100
                    } label: {
                        Text("\(pct)%")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedPercent == pct ? ChipInTheme.accent : ChipInTheme.elevated)
                            .foregroundStyle(selectedPercent == pct ? ChipInTheme.onPrimary : ChipInTheme.label)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                // Custom tip field
                TextField("Custom", text: $customText)
                    .keyboardType(.decimalPad)
                    .focused($customFocused)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(customFocused ? ChipInTheme.accent.opacity(0.15) : ChipInTheme.elevated)
                    .foregroundStyle(ChipInTheme.label)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(customFocused ? ChipInTheme.accent : Color.clear, lineWidth: 1)
                    )
                    .onChange(of: customText) { _, val in
                        selectedPercent = nil
                        if let d = Decimal(string: val), d >= 0 {
                            tipAmount = d
                        } else if val.isEmpty {
                            tipAmount = 0
                        }
                    }
            }

            if tipAmount > 0 {
                HStack {
                    Text("Tip total")
                        .font(.caption)
                        .foregroundStyle(ChipInTheme.secondaryLabel)
                    Spacer()
                    Text(tipAmount, format: .currency(code: "CAD"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ChipInTheme.accent)
                }
            }

            // "No tip" option
            if tipAmount > 0 || selectedPercent != nil {
                Button("Remove tip") {
                    selectedPercent = nil
                    customText = ""
                    tipAmount = 0
                }
                .font(.caption)
                .foregroundStyle(ChipInTheme.tertiaryLabel)
            }
        }
        .padding(14)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
    }
}
```

- [ ] **Step 2: Add tipAmount to AddExpenseViewModel**

In `AddExpenseViewModel.swift`, add:

```swift
var tipAmount: Decimal = 0

/// Grand total including tip
var grandTotal: Decimal {
    (Decimal(string: amount) ?? 0) + tipAmount
}
```

Make sure the submission uses `grandTotal` as the `totalAmount` when inserting the expense. Find where the expense is built and replace the raw `amount` parse with `grandTotal`.

- [ ] **Step 3: Show TipCalculatorView in AddExpenseView**

In `AddExpenseView.swift`, after the tax row (or category row), add:

```swift
// Show tip calculator only for food and fun categories
if vm.category == .food || vm.category == .fun {
    TipCalculatorView(subtotal: Decimal(string: vm.amount) ?? 0, tipAmount: $vm.tipAmount)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.35), value: vm.category)
}
```

- [ ] **Step 4: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

- [ ] **Step 5: Manual test**

Add Expense → set category to Food → Tip section appears → tap 18% → tip total shows → change to custom 5.00 → tip updates → Submit expense → total in Supabase includes tip.

- [ ] **Step 6: Commit**

```bash
git add ChipIn/ChipIn/Components/TipCalculatorView.swift \
        ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift \
        ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift
git commit -m "feat: built-in tip calculator for food and fun expenses"
```

---

## Task 3: Expense Templates

**What it does:** After saving an expense, user can save it as a template (e.g. "Tim Hortons Run"). Next time, tap template → all fields pre-filled, just change amount and people. Lives as a horizontal scroll row at the top of Add Expense.

**Files:**
- Create: `ChipIn/ChipIn/Services/TemplateService.swift`
- Create: `ChipIn/ChipIn/Components/TemplatePickerView.swift`
- Modify: `ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift`
- Modify: `ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift`
- Create: `supabase/migrations/013_expense_templates.sql`

- [ ] **Step 1: Create Supabase migration**

Create `supabase/migrations/013_expense_templates.sql`:

```sql
create table if not exists public.expense_templates (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    name text not null,
    title text not null,
    category text not null default 'other',
    split_type text not null default 'equal',
    currency text not null default 'CAD',
    created_at timestamptz not null default now()
);

alter table public.expense_templates enable row level security;

create policy "users manage own templates"
    on public.expense_templates
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create index expense_templates_user_id_idx on public.expense_templates(user_id);
```

Run this in the Supabase SQL editor.

- [ ] **Step 2: Create TemplateService**

Create `ChipIn/ChipIn/Services/TemplateService.swift`:

```swift
import Foundation
import Supabase

struct ExpenseTemplate: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var name: String
    var title: String
    var category: String
    var splitType: String
    var currency: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, title, category, currency
        case userId = "user_id"
        case splitType = "split_type"
        case createdAt = "created_at"
    }
}

struct TemplateService {
    func fetchTemplates(userId: UUID) async throws -> [ExpenseTemplate] {
        try await supabase
            .from("expense_templates")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func saveTemplate(userId: UUID, name: String, title: String, category: String, splitType: String, currency: String) async throws {
        struct Insert: Encodable {
            let user_id: String
            let name: String
            let title: String
            let category: String
            let split_type: String
            let currency: String
        }
        let payload = Insert(
            user_id: userId.uuidString,
            name: name, title: title,
            category: category, split_type: splitType, currency: currency
        )
        try await supabase.from("expense_templates").insert(payload).execute()
    }

    func deleteTemplate(id: UUID) async throws {
        try await supabase.from("expense_templates").delete().eq("id", value: id).execute()
    }
}
```

- [ ] **Step 3: Create TemplatePickerView**

Create `ChipIn/ChipIn/Components/TemplatePickerView.swift`:

```swift
import SwiftUI

struct TemplatePickerView: View {
    let templates: [ExpenseTemplate]
    let onSelect: (ExpenseTemplate) -> Void
    let onDelete: (ExpenseTemplate) -> Void

    var body: some View {
        if templates.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick templates")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChipInTheme.tertiaryLabel)
                    .padding(.horizontal, 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(templates) { template in
                            Button {
                                onSelect(template)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(categoryEmoji(template.category))
                                        .font(.title3)
                                    Text(template.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(ChipInTheme.label)
                                        .lineLimit(1)
                                    Text(template.title)
                                        .font(.caption2)
                                        .foregroundStyle(ChipInTheme.secondaryLabel)
                                        .lineLimit(1)
                                }
                                .padding(12)
                                .background(ChipInTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDelete(template)
                                } label: {
                                    Label("Delete Template", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func categoryEmoji(_ cat: String) -> String {
        switch cat {
        case "food": return "🍕"
        case "travel": return "🚗"
        case "rent": return "🏠"
        case "fun": return "🎉"
        case "utilities": return "⚡"
        default: return "📋"
        }
    }
}
```

- [ ] **Step 4: Add template state and methods to AddExpenseViewModel**

In `AddExpenseViewModel.swift`, add:

```swift
var templates: [ExpenseTemplate] = []
private let templateService = TemplateService()

func loadTemplates(userId: UUID) async {
    templates = (try? await templateService.fetchTemplates(userId: userId)) ?? []
}

func applyTemplate(_ template: ExpenseTemplate) {
    title = template.title
    currency = template.currency
    if let cat = ExpenseCategory(rawValue: template.category) {
        category = cat
    }
    // Note: amount and participants are left for the user to fill in
}

func saveCurrentAsTemplate(userId: UUID, name: String) async {
    guard !title.isEmpty else { return }
    try? await templateService.saveTemplate(
        userId: userId, name: name, title: title,
        category: category.rawValue, splitType: splitType.rawValue,
        currency: currency
    )
    await loadTemplates(userId: userId)
}

func deleteTemplate(_ template: ExpenseTemplate) async {
    try? await templateService.deleteTemplate(id: template.id)
    templates.removeAll { $0.id == template.id }
}
```

- [ ] **Step 5: Wire TemplatePickerView into AddExpenseView**

In `AddExpenseView.swift`, near the top of the form (before the amount field), add:

```swift
// Templates row — shown above amount entry
if let userId = auth.currentUser?.id {
    TemplatePickerView(
        templates: vm.templates,
        onSelect: { vm.applyTemplate($0) },
        onDelete: { template in Task { await vm.deleteTemplate(template) } }
    )
    .task { await vm.loadTemplates(userId: userId) }
}
```

After a successful expense submission, show a "Save as Template?" alert:

```swift
// In the success handler after expense is saved:
.alert("Save as Template?", isPresented: $vm.showSaveTemplatePrompt) {
    TextField("Template name (e.g. Tim Hortons Run)", text: $vm.templateName)
    Button("Save") {
        guard let id = auth.currentUser?.id else { return }
        Task { await vm.saveCurrentAsTemplate(userId: id, name: vm.templateName) }
    }
    Button("Skip", role: .cancel) {}
} message: {
    Text("Reuse this setup for quick expense entry.")
}
```

Add `@State var showSaveTemplatePrompt = false` and `@State var templateName = ""` to the ViewModel.

- [ ] **Step 6: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

- [ ] **Step 7: Manual test**

Add expense "Tim Hortons" for $12 → submit → "Save as Template?" appears → name it "Coffee Run" → next time open Add Expense → Coffee Run chip appears → tap it → title fills in.

- [ ] **Step 8: Commit**

```bash
git add supabase/migrations/013_expense_templates.sql \
        ChipIn/ChipIn/Services/TemplateService.swift \
        ChipIn/ChipIn/Components/TemplatePickerView.swift \
        ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift \
        ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift
git commit -m "feat: expense templates — save and reuse common expense setups"
```

---

## Task 4: Emoji Reactions on Expenses

**What it does:** Below each expense's split list, a row of emoji reaction buttons. Tap one and your reaction appears. Friends see it in real-time. Reactions are 👍 🔥 💀 😂 🙏 with a count badge. University students love this — it defuses "who owes what" tension.

**Files:**
- Create: `supabase/migrations/011_reactions.sql`
- Create: `ChipIn/ChipIn/Features/Reactions/ReactionsBar.swift`
- Create: `ChipIn/ChipIn/Features/Reactions/ReactionsService.swift`
- Modify: `ChipIn/ChipIn/Features/Expenses/ExpenseDetailView.swift`

- [ ] **Step 1: Create reactions migration**

Create `supabase/migrations/011_reactions.sql`:

```sql
create table if not exists public.reactions (
    id uuid primary key default gen_random_uuid(),
    expense_id uuid not null references public.expenses(id) on delete cascade,
    user_id uuid not null references public.users(id) on delete cascade,
    emoji text not null check (emoji in ('👍','🔥','💀','😂','🙏')),
    created_at timestamptz not null default now(),
    unique (expense_id, user_id, emoji)
);

alter table public.reactions enable row level security;

-- Anyone who can see the expense can see its reactions
create policy "reactions visible to all authenticated"
    on public.reactions for select
    using (auth.role() = 'authenticated');

create policy "users manage own reactions"
    on public.reactions for insert
    with check (auth.uid() = user_id);

create policy "users delete own reactions"
    on public.reactions for delete
    using (auth.uid() = user_id);

create index reactions_expense_id_idx on public.reactions(expense_id);
```

Run in Supabase SQL editor.

- [ ] **Step 2: Create ReactionsService**

Create `ChipIn/ChipIn/Features/Reactions/ReactionsService.swift`:

```swift
import Foundation
import Supabase

struct Reaction: Codable, Identifiable {
    let id: UUID
    let expenseId: UUID
    let userId: UUID
    let emoji: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, emoji
        case expenseId = "expense_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct ReactionsService {
    func fetchReactions(expenseId: UUID) async throws -> [Reaction] {
        try await supabase
            .from("reactions")
            .select()
            .eq("expense_id", value: expenseId)
            .execute()
            .value
    }

    func toggleReaction(expenseId: UUID, userId: UUID, emoji: String, existing: [Reaction]) async throws {
        let alreadyReacted = existing.contains { $0.userId == userId && $0.emoji == emoji }
        if alreadyReacted {
            try await supabase
                .from("reactions")
                .delete()
                .eq("expense_id", value: expenseId)
                .eq("user_id", value: userId)
                .eq("emoji", value: emoji)
                .execute()
        } else {
            struct Insert: Encodable {
                let expense_id: String
                let user_id: String
                let emoji: String
            }
            try await supabase
                .from("reactions")
                .insert(Insert(expense_id: expenseId.uuidString, user_id: userId.uuidString, emoji: emoji))
                .execute()
        }
    }
}
```

- [ ] **Step 3: Create ReactionsBar view**

Create `ChipIn/ChipIn/Features/Reactions/ReactionsBar.swift`:

```swift
import SwiftUI

struct ReactionsBar: View {
    let expenseId: UUID
    let currentUserId: UUID
    @State private var reactions: [Reaction] = []
    @State private var isLoading = false
    private let service = ReactionsService()
    private let emojis = ["👍", "🔥", "💀", "😂", "🙏"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(emojis, id: \.self) { emoji in
                    reactionButton(emoji: emoji)
                }
            }
            .padding(.vertical, 4)
        }
        .task { await load() }
    }

    private func reactionButton(_ emoji: String) -> some View {
        let count = reactions.filter { $0.emoji == emoji }.count
        let isMine = reactions.contains { $0.userId == currentUserId && $0.emoji == emoji }

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await toggle(emoji: emoji) }
        } label: {
            HStack(spacing: 4) {
                Text(emoji).font(.body)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isMine ? ChipInTheme.onPrimary : ChipInTheme.label)
                }
            }
            .padding(.horizontal, count > 0 ? 10 : 8)
            .padding(.vertical, 6)
            .background(isMine ? ChipInTheme.accent : ChipInTheme.elevated)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isMine ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(isMine ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMine)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        reactions = (try? await service.fetchReactions(expenseId: expenseId)) ?? []
    }

    private func toggle(emoji: String) async {
        let snapshot = reactions
        // Optimistic update
        if reactions.contains(where: { $0.userId == currentUserId && $0.emoji == emoji }) {
            reactions.removeAll { $0.userId == currentUserId && $0.emoji == emoji }
        } else {
            reactions.append(Reaction(
                id: UUID(), expenseId: expenseId, userId: currentUserId,
                emoji: emoji, createdAt: Date()
            ))
        }
        do {
            try await service.toggleReaction(expenseId: expenseId, userId: currentUserId, emoji: emoji, existing: snapshot)
        } catch {
            reactions = snapshot // roll back on error
        }
    }
}
```

- [ ] **Step 4: Add ReactionsBar to ExpenseDetailView**

In `ExpenseDetailView.swift`, after the splits section and before the comments section, add:

```swift
// After split rows, before comments:
if let currentUserId = auth.currentUser?.id {
    VStack(alignment: .leading, spacing: 8) {
        Text("Reactions")
            .font(.caption.weight(.semibold))
            .foregroundStyle(ChipInTheme.tertiaryLabel)
        ReactionsBar(expenseId: expense.id, currentUserId: currentUserId)
    }
    .padding(.top, 4)
}
```

Make sure `ExpenseDetailView` has `@Environment(AuthManager.self) var auth` injected (check if it already does — if not, add it and pass `.environment(auth)` from the caller).

- [ ] **Step 5: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

- [ ] **Step 6: Manual test**

Open any expense → see 5 emoji buttons → tap 🔥 → it highlights with accent color, count shows 1 → tap again → un-reacts → count goes to 0.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/011_reactions.sql \
        ChipIn/ChipIn/Features/Reactions/ReactionsService.swift \
        ChipIn/ChipIn/Features/Reactions/ReactionsBar.swift \
        ChipIn/ChipIn/Features/Expenses/ExpenseDetailView.swift
git commit -m "feat: emoji reactions on expenses (👍🔥💀😂🙏)"
```

---

## Task 5: Activity Feed Tab

**What it does:** Replace Search tab with a scrolling social feed. Shows: your friends added an expense, someone settled up, a new group expense was posted. Like an Instagram feed but for money. University students love feeling "in the loop."

**Files:**
- Create: `ChipIn/ChipIn/Features/Activity/ActivityFeedView.swift`
- Create: `ChipIn/ChipIn/Features/Activity/ActivityFeedViewModel.swift`
- Modify: `ChipIn/ChipIn/ContentView.swift`

- [ ] **Step 1: Create ActivityFeedViewModel**

Create `ChipIn/ChipIn/Features/Activity/ActivityFeedViewModel.swift`:

```swift
import Foundation
import Supabase

struct ActivityItem: Identifiable {
    enum Kind {
        case expenseAdded(Expense)
        case settled(Settlement)
        case groupExpense(Expense, Group)
    }
    let id: UUID
    let kind: Kind
    let date: Date
    let actorName: String
    let actorId: UUID
}

@Observable @MainActor
class ActivityFeedViewModel {
    var items: [ActivityItem] = []
    var isLoading = false
    var error: String?

    func load(currentUserId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        // 1. Expenses you're involved in (paid by others, you're a split member)
        let yourSplits: [ExpenseSplit] = (try? await supabase
            .from("expense_splits")
            .select()
            .eq("user_id", value: currentUserId)
            .order("expense_id", ascending: false)
            .limit(30)
            .execute()
            .value) ?? []

        let splitExpenseIds = Array(Set(yourSplits.map(\.expenseId.uuidString)))
        var expenses: [Expense] = []
        if !splitExpenseIds.isEmpty {
            expenses = (try? await supabase
                .from("expenses")
                .select()
                .in("id", values: splitExpenseIds)
                .neq("paid_by", value: currentUserId) // exclude your own
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value) ?? []
        }

        // 2. Recent settlements involving you
        let settlements: [Settlement] = (try? await supabase
            .from("settlements")
            .select()
            .or("from_user_id.eq.\(currentUserId),to_user_id.eq.\(currentUserId)")
            .order("settled_at", ascending: false)
            .limit(10)
            .execute()
            .value) ?? []

        // Fetch user display names for actors
        var userCache: [UUID: String] = [:]
        let actorIds = Array(Set(expenses.map(\.paidBy) + settlements.map(\.fromUserId) + settlements.map(\.toUserId)))
        if !actorIds.isEmpty {
            let users: [AppUser] = (try? await supabase
                .from("users")
                .select()
                .in("id", values: actorIds.map(\.uuidString))
                .execute()
                .value) ?? []
            for u in users { userCache[u.id] = u.displayName }
        }

        var feed: [ActivityItem] = []

        for exp in expenses {
            feed.append(ActivityItem(
                id: exp.id,
                kind: .expenseAdded(exp),
                date: exp.createdAt,
                actorName: userCache[exp.paidBy] ?? "Someone",
                actorId: exp.paidBy
            ))
        }
        for s in settlements where s.fromUserId != currentUserId {
            feed.append(ActivityItem(
                id: s.id,
                kind: .settled(s),
                date: s.settledAt,
                actorName: userCache[s.fromUserId] ?? "Someone",
                actorId: s.fromUserId
            ))
        }

        items = feed.sorted { $0.date > $1.date }
    }
}
```

- [ ] **Step 2: Create ActivityFeedView**

Create `ChipIn/ChipIn/Features/Activity/ActivityFeedView.swift`:

```swift
import SwiftUI

struct ActivityFeedView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = ActivityFeedViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()

                if vm.isLoading && vm.items.isEmpty {
                    ProgressView().tint(ChipInTheme.accent)
                } else if vm.items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.items) { item in
                                ActivityRow(item: item)
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                Divider()
                                    .background(ChipInTheme.elevated)
                                    .padding(.leading, 68)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .refreshable {
                        if let id = auth.currentUser?.id { await vm.load(currentUserId: id) }
                    }
                }
            }
            .navigationTitle("Activity")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                if let id = auth.currentUser?.id { await vm.load(currentUserId: id) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("📭").font(.system(size: 48))
            Text("Nothing yet")
                .font(.title3.weight(.bold))
                .foregroundStyle(ChipInTheme.label)
            Text("When your friends add expenses or settle up, they'll appear here.")
                .font(.subheadline)
                .foregroundStyle(ChipInTheme.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

private struct ActivityRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(ChipInTheme.avatarColor(for: item.actorId.uuidString))
                    .frame(width: 44, height: 44)
                Text(String(item.actorName.prefix(1)).uppercased())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(rowTitle).font(.subheadline.weight(.semibold)).foregroundStyle(ChipInTheme.label)
                Text(rowSubtitle).font(.caption).foregroundStyle(ChipInTheme.secondaryLabel)
                Text(item.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(ChipInTheme.tertiaryLabel)
            }

            Spacer()
            Text(rowAmount)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(amountColor)
        }
    }

    private var rowTitle: String {
        switch item.kind {
        case .expenseAdded(let e): return "\(item.actorName) added \u{201C}\(e.title)\u{201D}"
        case .settled(let s): return "\(item.actorName) settled up"
        case .groupExpense(let e, let g): return "\(item.actorName) added to \(g.name)"
        }
    }

    private var rowSubtitle: String {
        switch item.kind {
        case .expenseAdded: return "You're included in this expense"
        case .settled: return "Payment marked complete"
        case .groupExpense(let e, _): return e.title
        }
    }

    private var rowAmount: String {
        switch item.kind {
        case .expenseAdded(let e):
            return e.cadAmount.formatted(.currency(code: "CAD"))
        case .settled(let s):
            return s.amount.formatted(.currency(code: "CAD"))
        case .groupExpense(let e, _):
            return e.cadAmount.formatted(.currency(code: "CAD"))
        }
    }

    private var amountColor: Color {
        switch item.kind {
        case .settled: return ChipInTheme.success
        default: return ChipInTheme.label
        }
    }
}
```

- [ ] **Step 3: Add Activity tab to ContentView**

In `ContentView.swift`, modify the TabView to add Activity as tab 2, shift Insights to 3, Search to 4:

```swift
TabView(selection: $selectedTab) {
    HomeView(showAddExpense: $showAddExpense)
        .tabItem { Label("Home", systemImage: "house.fill") }
        .tag(0)

    ActivityFeedView()                              // NEW
        .tabItem { Label("Activity", systemImage: "bell.fill") }
        .tag(1)

    GroupsView()
        .tabItem { Label("Groups", systemImage: "person.3.fill") }
        .tag(2)

    InsightsView()
        .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
        .tag(3)

    SearchView()
        .tabItem { Label("Search", systemImage: "magnifyingglass") }
        .tag(4)
}
```

Remember to add `.environment(auth)` to `ActivityFeedView()` if AuthManager is passed down.

- [ ] **Step 4: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

- [ ] **Step 5: Manual test**

Run app → tap bell tab → see Activity feed → pull to refresh → when another test user adds an expense you're split on, it appears.

- [ ] **Step 6: Commit**

```bash
git add ChipIn/ChipIn/Features/Activity/ActivityFeedView.swift \
        ChipIn/ChipIn/Features/Activity/ActivityFeedViewModel.swift \
        ChipIn/ChipIn/ContentView.swift
git commit -m "feat: activity feed tab — social feed of friend expenses and settlements"
```

---

## Task 6: Profile Picture

**What it does:** Users can take a selfie or pick a photo as their avatar. Shows in balance rows, comments, group detail, settle-up. A small detail that makes the app feel real and personal.

**Files:**
- Create: `ChipIn/ChipIn/Services/AvatarService.swift`
- Modify: `ChipIn/ChipIn/Features/Profile/ProfileView.swift`
- Modify: `ChipIn/ChipIn/Components/PersonBalanceRow.swift`

- [ ] **Step 1: Enable storage bucket in Supabase**

In Supabase dashboard → Storage → New bucket:
- Name: `avatars`
- Public: ✅ (yes, public — URLs are non-guessable UUIDs)

Then in SQL editor:
```sql
-- Allow authenticated users to upload their own avatar
create policy "users upload own avatar"
    on storage.objects for insert
    with check (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

create policy "users update own avatar"
    on storage.objects for update
    using (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

create policy "avatars are publicly readable"
    on storage.objects for select
    using (bucket_id = 'avatars');
```

- [ ] **Step 2: Create AvatarService**

Create `ChipIn/ChipIn/Services/AvatarService.swift`:

```swift
import Foundation
import UIKit
import Supabase

struct AvatarService {
    /// Uploads a JPEG avatar and returns the public URL string.
    func uploadAvatar(userId: UUID, image: UIImage) async throws -> String {
        guard let data = image
            .chipInReceiptPrepared(maxDimension: 400)
            .chipInJPEGDataForReceipt(quality: 0.85) else {
            throw NSError(domain: "AvatarService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Image conversion failed"])
        }
        let path = "\(userId.uuidString)/avatar.jpg"
        try await supabase.storage
            .from("avatars")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try supabase.storage.from("avatars").getPublicURL(path: path)
        return publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"
    }

    /// Updates the user's avatar_url in the users table.
    func saveAvatarURL(userId: UUID, url: String) async throws {
        try await supabase
            .from("users")
            .update(["avatar_url": url])
            .eq("id", value: userId)
            .execute()
    }
}
```

- [ ] **Step 3: Add avatar picker to ProfileView**

In `ProfileView.swift`, add PhotosPicker for avatar:

```swift
// Add these state vars to ProfileView:
@State private var selectedAvatar: PhotosPickerItem?
@State private var avatarUIImage: UIImage?
@State private var isUploadingAvatar = false
@State private var avatarError: String?
private let avatarService = AvatarService()

// Replace the existing avatar display (or add one if there isn't one):
// At the top of the profile form, add:
VStack(spacing: 8) {
    ZStack(alignment: .bottomTrailing) {
        Group {
            if let img = avatarUIImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
            } else if let urlStr = auth.currentUser?.avatarURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(ChipInTheme.elevated)
                }
            } else {
                Circle()
                    .fill(ChipInTheme.elevated)
                    .overlay(
                        Text(auth.currentUser?.displayName.prefix(1).uppercased() ?? "?")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(ChipInTheme.label)
                    )
            }
        }
        .frame(width: 90, height: 90)
        .clipShape(Circle())

        PhotosPicker(selection: $selectedAvatar, matching: .images) {
            Image(systemName: "camera.circle.fill")
                .font(.title2)
                .foregroundStyle(ChipInTheme.accent)
                .background(Circle().fill(ChipInTheme.background).frame(width: 28, height: 28))
        }
        .offset(x: 4, y: 4)
    }

    if isUploadingAvatar {
        ProgressView("Uploading…")
            .font(.caption)
            .tint(ChipInTheme.accent)
    }
    if let err = avatarError {
        Text(err).font(.caption).foregroundStyle(ChipInTheme.danger)
    }
}
.frame(maxWidth: .infinity)
.padding(.bottom, 8)
.onChange(of: selectedAvatar) { _, item in
    guard let item else { return }
    Task {
        isUploadingAvatar = true
        avatarError = nil
        defer { isUploadingAvatar = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let img = UIImage(data: data),
              let userId = auth.currentUser?.id else {
            avatarError = "Couldn't load photo."
            return
        }
        avatarUIImage = img
        do {
            let url = try await avatarService.uploadAvatar(userId: userId, image: img)
            try await avatarService.saveAvatarURL(userId: userId, url: url)
            await auth.reloadCurrentUser()
        } catch {
            avatarError = error.localizedDescription
        }
    }
}
```

Add `import PhotosUI` at the top of `ProfileView.swift`.

Add `func reloadCurrentUser() async` to `AuthManager.swift` that re-fetches the user profile from Supabase and updates `currentUser`.

- [ ] **Step 4: Show avatar in PersonBalanceRow**

In `PersonBalanceRow.swift`, replace the initial-circle avatar with an `AsyncImage` that falls back to the initial:

```swift
// Replace the existing Circle avatar with:
ZStack {
    Circle()
        .fill(ChipInTheme.avatarColor(for: personBalance.user.id.uuidString))
        .frame(width: 44, height: 44)
    if let urlStr = personBalance.user.avatarURL, let url = URL(string: urlStr) {
        AsyncImage(url: url) { img in
            img.resizable().scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } placeholder: {
            Text(String(personBalance.user.displayName.prefix(1)).uppercased())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
    } else {
        Text(String(personBalance.user.displayName.prefix(1)).uppercased())
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
    }
}
```

- [ ] **Step 5: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

- [ ] **Step 6: Manual test**

Profile tab → tap camera icon on avatar circle → pick photo from library → see spinner → avatar updates → go back to Home → balance row for yourself shows photo.

- [ ] **Step 7: Commit**

```bash
git add ChipIn/ChipIn/Services/AvatarService.swift \
        ChipIn/ChipIn/Features/Profile/ProfileView.swift \
        ChipIn/ChipIn/Components/PersonBalanceRow.swift \
        ChipIn/ChipIn/Core/AuthManager.swift
git commit -m "feat: profile picture — upload avatar photo, shown in balance rows"
```

---

## Task 7: QR Code Friend-Adding

**What it does:** Every user gets a QR code (their user ID encoded). Show it in Profile. Anyone else can scan it with the camera to instantly add them as a contact without typing an email. University students love this — "scan my QR" at the dining hall.

**Files:**
- Create: `ChipIn/ChipIn/Features/Friends/FriendQRView.swift`
- Modify: `ChipIn/ChipIn/Features/Profile/ProfileView.swift`

- [ ] **Step 1: Create FriendQRView**

Create `ChipIn/ChipIn/Features/Friends/FriendQRView.swift`:

```swift
import SwiftUI
import CoreImage.CIFilterBuiltins

struct FriendQRView: View {
    let userId: UUID
    let displayName: String
    @Environment(\.dismiss) var dismiss
    @State private var scanMode = false
    @State private var showCamera = false
    @State private var scannedCode: String?
    @State private var resolvedUser: AppUser?
    @State private var isLooking = false
    @State private var lookupError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 32) {
                    if !scanMode {
                        myQRSection
                    } else {
                        scanSection
                    }

                    Picker("Mode", selection: $scanMode) {
                        Text("My QR").tag(false)
                        Text("Scan Friend").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)
                }
                .padding()
            }
            .navigationTitle("Add Friend by QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
        }
    }

    private var myQRSection: some View {
        VStack(spacing: 16) {
            Text("Show this to friends")
                .font(.subheadline)
                .foregroundStyle(ChipInTheme.secondaryLabel)

            if let img = generateQR(from: "chipin://add-friend/\(userId.uuidString)") {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            Text(displayName)
                .font(.headline)
                .foregroundStyle(ChipInTheme.label)
        }
    }

    private var scanSection: some View {
        VStack(spacing: 16) {
            if let user = resolvedUser {
                VStack(spacing: 12) {
                    Text("✅").font(.system(size: 48))
                    Text("Found \(user.displayName)!")
                        .font(.headline).foregroundStyle(ChipInTheme.label)
                    Text(user.email).font(.subheadline).foregroundStyle(ChipInTheme.secondaryLabel)
                    // In future: send friend request. For now, user can add to group.
                    Text("Add them to a group from the Groups tab.")
                        .font(.caption).foregroundStyle(ChipInTheme.tertiaryLabel)
                        .multilineTextAlignment(.center)
                }
            } else {
                Button {
                    showCamera = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 64))
                            .foregroundStyle(ChipInTheme.accent)
                        Text("Open camera to scan")
                            .font(.subheadline)
                            .foregroundStyle(ChipInTheme.secondaryLabel)
                    }
                    .frame(width: 220, height: 220)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if isLooking { ProgressView().tint(ChipInTheme.accent) }
            if let err = lookupError { Text(err).font(.caption).foregroundStyle(ChipInTheme.danger) }
        }
        // QR scanning via camera uses the system scan (native QR detection via AVFoundation).
        // For now, a manual text field as fallback since full camera QR decode needs AVCaptureMetadataOutput.
        // TODO in future: replace with a native QR scanning camera view.
        .sheet(isPresented: $showCamera) {
            VStack(spacing: 16) {
                Text("Paste or type the ChipIn code from your friend's screen:").font(.subheadline)
                TextField("chipin://add-friend/...", text: Binding(get: { scannedCode ?? "" }, set: { scannedCode = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Button("Look up") {
                    showCamera = false
                    if let code = scannedCode { Task { await resolveCode(code) } }
                }
                .buttonStyle(.borderedProminent)
                .tint(ChipInTheme.accent)
            }
            .padding()
            .presentationDetents([.height(220)])
        }
    }

    private func resolveCode(_ code: String) async {
        isLooking = true
        lookupError = nil
        defer { isLooking = false }
        guard let uuidStr = code.components(separatedBy: "chipin://add-friend/").last,
              let uuid = UUID(uuidString: uuidStr) else {
            lookupError = "Invalid QR code."
            return
        }
        let users: [AppUser] = (try? await supabase
            .from("users").select().eq("id", value: uuid).limit(1).execute().value) ?? []
        if let user = users.first {
            resolvedUser = user
        } else {
            lookupError = "User not found."
        }
    }

    private func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
```

- [ ] **Step 2: Add QR button to ProfileView**

In `ProfileView.swift`, add a "My QR Code" button in the profile section:

```swift
@State private var showQR = false

// Add in the profile section:
Button {
    showQR = true
} label: {
    Label("Add Friend by QR", systemImage: "qrcode")
        .frame(maxWidth: .infinity, alignment: .leading)
}
.sheet(isPresented: $showQR) {
    if let user = auth.currentUser {
        FriendQRView(userId: user.id, displayName: user.displayName)
    }
}
```

- [ ] **Step 3: Handle `chipin://add-friend/` deep link in ChipInApp.swift**

In `ChipInApp.swift`, in the `onOpenURL` handler, add:

```swift
case let url where url.host == "add-friend":
    if let uuidStr = url.pathComponents.last, let uuid = UUID(uuidString: uuidStr) {
        // Navigate to a sheet showing the found user
        pendingFriendId = uuid
        showFriendQR = true
    }
```

Add `@State private var pendingFriendId: UUID?` and `@State private var showFriendQR = false` to ChipInApp's scene body.

- [ ] **Step 4: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

- [ ] **Step 5: Manual test**

Profile → "Add Friend by QR" → see QR with your ID → switch to "Scan Friend" → paste the chipin:// URL → user resolves correctly.

- [ ] **Step 6: Commit**

```bash
git add ChipIn/ChipIn/Features/Friends/FriendQRView.swift \
        ChipIn/ChipIn/Features/Profile/ProfileView.swift \
        ChipIn/ChipIn/ChipInApp.swift
git commit -m "feat: QR code friend-adding — show your QR, scan a friend's to look them up"
```

---

## Task 8: Group Leaderboard (Fun Stats)

**What it does:** A "Stats" button in GroupDetailView opens a sheet with fun group leaderboard: "Biggest Spender", "Most Generous (paid the most)", "Most Debt", "Quickest Settler". University students love being called out.

**Files:**
- Create: `ChipIn/ChipIn/Features/Groups/GroupLeaderboardView.swift`
- Modify: `ChipIn/ChipIn/Features/Groups/GroupDetailView.swift`

- [ ] **Step 1: Create GroupLeaderboardView**

Create `ChipIn/ChipIn/Features/Groups/GroupLeaderboardView.swift`:

```swift
import SwiftUI

struct GroupStat: Identifiable {
    let id = UUID()
    let title: String
    let emoji: String
    let winner: AppUser
    let value: String
    let subtitle: String
}

struct GroupLeaderboardView: View {
    let group: Group
    let members: [AppUser]
    @Environment(\.dismiss) var dismiss
    @State private var stats: [GroupStat] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(ChipInTheme.accent)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            Text("🏆 \(group.name) Hall of Fame")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(ChipInTheme.label)
                                .padding(.top, 8)

                            ForEach(stats) { stat in
                                statCard(stat)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Group Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ChipInTheme.surfaceHeader, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(ChipInTheme.secondaryLabel)
                }
            }
            .task { await loadStats() }
        }
        .presentationDetents([.large])
    }

    private func statCard(_ stat: GroupStat) -> some View {
        HStack(spacing: 14) {
            Text(stat.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.title).font(.caption).foregroundStyle(ChipInTheme.tertiaryLabel)
                Text(stat.winner.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ChipInTheme.label)
                Text(stat.subtitle).font(.caption2).foregroundStyle(ChipInTheme.secondaryLabel)
            }
            Spacer()
            Text(stat.value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ChipInTheme.accent)
        }
        .padding(14)
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
    }

    private func loadStats() async {
        defer { isLoading = false }

        // Fetch all expenses for this group
        let expenses: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .eq("group_id", value: group.id)
            .execute()
            .value) ?? []

        // Fetch all splits for group expenses
        let expenseIds = expenses.map(\.id.uuidString)
        var splits: [ExpenseSplit] = []
        if !expenseIds.isEmpty {
            splits = (try? await supabase
                .from("expense_splits")
                .select()
                .in("expense_id", values: expenseIds)
                .execute()
                .value) ?? []
        }

        // Biggest spender: highest total cadAmount paid
        var totalPaid: [UUID: Decimal] = [:]
        for exp in expenses {
            totalPaid[exp.paidBy, default: 0] += exp.cadAmount
        }

        // Most debt: highest total owed in splits (is_settled = false)
        var totalOwed: [UUID: Decimal] = [:]
        for split in splits.filter({ !$0.isSettled }) {
            totalOwed[split.userId, default: 0] += split.owedAmount
        }

        // Quickest settler: most is_settled = true splits
        var settledCount: [UUID: Int] = [:]
        for split in splits.filter({ $0.isSettled }) {
            settledCount[split.userId, default: 0] += 1
        }

        func user(for id: UUID) -> AppUser? { members.first { $0.id == id } }

        var result: [GroupStat] = []

        if let (topId, topAmt) = totalPaid.max(by: { $0.value < $1.value }),
           let u = user(for: topId) {
            result.append(GroupStat(
                title: "Biggest Spender", emoji: "💸",
                winner: u,
                value: topAmt.formatted(.currency(code: "CAD")),
                subtitle: "Paid the most upfront in this group"
            ))
        }

        if let (topId, topAmt) = totalOwed.max(by: { $0.value < $1.value }),
           let u = user(for: topId) {
            result.append(GroupStat(
                title: "Most Debt", emoji: "😬",
                winner: u,
                value: topAmt.formatted(.currency(code: "CAD")),
                subtitle: "Still owes the most — nudge them!"
            ))
        }

        if let (topId, count) = settledCount.max(by: { $0.value < $1.value }),
           let u = user(for: topId) {
            result.append(GroupStat(
                title: "Best Settler", emoji: "⚡",
                winner: u,
                value: "\(count) paid",
                subtitle: "Cleared debts the fastest"
            ))
        }

        // Most expenses paid (generous host)
        var expenseCount: [UUID: Int] = [:]
        for exp in expenses { expenseCount[exp.paidBy, default: 0] += 1 }
        if let (topId, count) = expenseCount.max(by: { $0.value < $1.value }),
           let u = user(for: topId) {
            result.append(GroupStat(
                title: "Generous Host", emoji: "🙌",
                winner: u,
                value: "\(count) expenses",
                subtitle: "Picks up the tab the most"
            ))
        }

        stats = result
    }
}
```

- [ ] **Step 2: Add Leaderboard button to GroupDetailView**

In `GroupDetailView.swift`, add a state var and toolbar button:

```swift
@State private var showLeaderboard = false

// In .toolbar { ... }, add:
ToolbarItem(placement: .topBarTrailing) {
    Button {
        showLeaderboard = true
    } label: {
        Image(systemName: "trophy.fill")
            .foregroundStyle(ChipInTheme.accent)
    }
    .accessibilityLabel("Group Stats")
}

// Add sheet:
.sheet(isPresented: $showLeaderboard) {
    GroupLeaderboardView(group: group, members: members)
}
```

Where `members` is the list of `AppUser` already loaded for the group.

- [ ] **Step 3: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

- [ ] **Step 4: Commit**

```bash
git add ChipIn/ChipIn/Features/Groups/GroupLeaderboardView.swift \
        ChipIn/ChipIn/Features/Groups/GroupDetailView.swift
git commit -m "feat: group leaderboard — biggest spender, most debt, best settler"
```

---

## Task 9: ChipIn Wrapped (Semester Review)

**What it does:** A Spotify Wrapped-style full-screen card in Insights tab showing: total spent this year, top category, most expensive single expense, group you're most active in, person you owe/get paid by most. Tappable slide cards with animations. Students WILL screenshot this.

**Files:**
- Create: `ChipIn/ChipIn/Features/Wrapped/WrappedView.swift`
- Modify: `ChipIn/ChipIn/Features/Home/HomeView.swift` (banner card to open it)
- Modify: `ChipIn/ChipIn/Features/Insights/InsightsView.swift` (button at top)

- [ ] **Step 1: Create WrappedView**

Create `ChipIn/ChipIn/Features/Wrapped/WrappedView.swift`:

```swift
import SwiftUI

struct WrappedCard: Identifiable {
    let id = UUID()
    let emoji: String
    let headline: String
    let subheadline: String
    let detail: String
    let gradient: [Color]
}

struct WrappedView: View {
    let userId: UUID
    @Environment(\.dismiss) var dismiss
    @State private var cards: [WrappedCard] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var offset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            if isLoading {
                Color.black.ignoresSafeArea()
                ProgressView().tint(.white)
            } else if cards.isEmpty {
                Color.black.ignoresSafeArea()
                VStack {
                    Text("Not enough data yet").foregroundStyle(.white)
                    Button("Close") { dismiss() }.foregroundStyle(.orange)
                }
            } else {
                cardStack
            }
        }
        .task { await buildCards() }
    }

    private var cardStack: some View {
        ZStack {
            // Background gradient of current card
            LinearGradient(
                colors: cards[currentIndex].gradient,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: currentIndex)

            VStack {
                // Progress dots
                HStack(spacing: 4) {
                    ForEach(0..<cards.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentIndex ? Color.white : Color.white.opacity(0.35))
                            .frame(width: i == currentIndex ? 20 : 8, height: 4)
                            .animation(.spring(response: 0.3), value: currentIndex)
                    }
                }
                .padding(.top, 56)

                Spacer()

                // Card content
                VStack(spacing: 20) {
                    Text(cards[currentIndex].emoji)
                        .font(.system(size: 80))
                        .scaleEffect(dragOffset == 0 ? 1.0 : 0.85)
                        .animation(.spring(response: 0.4), value: currentIndex)

                    Text(cards[currentIndex].headline)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)

                    Text(cards[currentIndex].subheadline)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)

                    Text(cards[currentIndex].detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.horizontal, 32)
                .offset(x: dragOffset * 0.15)
                .animation(.spring(response: 0.3), value: currentIndex)

                Spacer()

                // Navigation hint
                HStack {
                    if currentIndex > 0 {
                        Button { prev() } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.title2).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    if currentIndex < cards.count - 1 {
                        Button { next() } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title2).foregroundStyle(.white.opacity(0.7))
                        }
                    } else {
                        Button { dismiss() } label: {
                            Text("Done")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24).padding(.vertical, 10)
                                .background(.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { v in dragOffset = v.translation.width }
                .onEnded { v in
                    withAnimation(.spring(response: 0.4)) {
                        dragOffset = 0
                        if v.translation.width < -50 { next() }
                        else if v.translation.width > 50 { prev() }
                    }
                }
        )
        .onTapGesture { next() }
    }

    private func next() {
        withAnimation(.spring(response: 0.4)) {
            if currentIndex < cards.count - 1 { currentIndex += 1 }
        }
    }
    private func prev() {
        withAnimation(.spring(response: 0.4)) {
            if currentIndex > 0 { currentIndex -= 1 }
        }
    }

    private func buildCards() async {
        defer { isLoading = false }
        let year = Calendar.current.component(.year, from: Date())
        let yearStart = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!

        // Fetch all expenses this year
        let allExpenses: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .gte("created_at", value: ISO8601DateFormatter().string(from: yearStart))
            .execute()
            .value) ?? []

        let myExpenses = allExpenses.filter { $0.paidBy == userId }
        let splits: [ExpenseSplit] = (try? await supabase
            .from("expense_splits")
            .select()
            .eq("user_id", value: userId)
            .gte("expense_id", value: "")
            .execute()
            .value) ?? []

        let totalPaid = myExpenses.reduce(Decimal(0)) { $0 + $1.cadAmount }
        let topExpense = myExpenses.max(by: { $0.cadAmount < $1.cadAmount })

        // Category breakdown
        var catTotals: [String: Decimal] = [:]
        for e in myExpenses { catTotals[e.category, default: 0] += e.cadAmount }
        let topCat = catTotals.max(by: { $0.value < $1.value })

        func catEmoji(_ cat: String) -> String {
            switch cat {
            case "food": return "🍕"
            case "travel": return "✈️"
            case "rent": return "🏠"
            case "fun": return "🎉"
            case "utilities": return "⚡"
            default: return "📦"
            }
        }

        var result: [WrappedCard] = []

        result.append(WrappedCard(
            emoji: "🎓",
            headline: "Your \(year)\nWrapped",
            subheadline: "Let's see how the year went financially",
            detail: "Swipe or tap to continue →",
            gradient: [Color(red: 0.9, green: 0.4, blue: 0.1), Color(red: 0.7, green: 0.1, blue: 0.5)]
        ))

        if totalPaid > 0 {
            result.append(WrappedCard(
                emoji: "💰",
                headline: totalPaid.formatted(.currency(code: "CAD")),
                subheadline: "Total you paid this year",
                detail: "Covering bills for \(myExpenses.count) expense\(myExpenses.count == 1 ? "" : "s")",
                gradient: [Color(red: 0.1, green: 0.5, blue: 0.9), Color(red: 0.0, green: 0.3, blue: 0.7)]
            ))
        }

        if let (cat, amt) = topCat {
            result.append(WrappedCard(
                emoji: catEmoji(cat),
                headline: cat.capitalized,
                subheadline: "Your top spending category",
                detail: "\(amt.formatted(.currency(code: "CAD"))) this year on \(cat)",
                gradient: [Color(red: 0.1, green: 0.7, blue: 0.4), Color(red: 0.0, green: 0.5, blue: 0.3)]
            ))
        }

        if let top = topExpense {
            result.append(WrappedCard(
                emoji: "🤯",
                headline: top.cadAmount.formatted(.currency(code: "CAD")),
                subheadline: "Your biggest single expense",
                detail: "\"\(top.title)\" — ouch.",
                gradient: [Color(red: 0.8, green: 0.1, blue: 0.3), Color(red: 0.5, green: 0.0, blue: 0.2)]
            ))
        }

        result.append(WrappedCard(
            emoji: "🫂",
            headline: "Split \(splits.count) times",
            subheadline: "You shared \(splits.count) bill\(splits.count == 1 ? "" : "s") this year",
            detail: "ChipIn kept the friendship math fair",
            gradient: [Color(red: 0.5, green: 0.1, blue: 0.9), Color(red: 0.3, green: 0.0, blue: 0.7)]
        ))

        cards = result
    }
}
```

- [ ] **Step 2: Add "Wrapped" entry point to InsightsView**

In `InsightsView.swift`, add at the top of the scroll view:

```swift
@State private var showWrapped = false

// Add as the first card in the VStack:
Button {
    showWrapped = true
} label: {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            Text("🎓 \(Calendar.current.component(.year, from: Date())) Wrapped")
                .font(.headline).foregroundStyle(ChipInTheme.label)
            Text("Your year in numbers")
                .font(.caption).foregroundStyle(ChipInTheme.secondaryLabel)
        }
        Spacer()
        Image(systemName: "chevron.right")
            .foregroundStyle(ChipInTheme.accent)
    }
    .padding(16)
    .background(
        LinearGradient(
            colors: [ChipInTheme.accent.opacity(0.25), ChipInTheme.accent.opacity(0.05)],
            startPoint: .leading, endPoint: .trailing
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: ChipInTheme.cardCornerRadius, style: .continuous)
            .stroke(ChipInTheme.accent.opacity(0.3), lineWidth: 1)
    )
}
.buttonStyle(.plain)
.fullScreenCover(isPresented: $showWrapped) {
    if let userId = auth.currentUser?.id {
        WrappedView(userId: userId)
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

- [ ] **Step 4: Manual test**

Insights tab → tap "2026 Wrapped" card → full-screen slides appear → swipe through all cards → Done closes it.

- [ ] **Step 5: Commit**

```bash
git add ChipIn/ChipIn/Features/Wrapped/WrappedView.swift \
        ChipIn/ChipIn/Features/Insights/InsightsView.swift
git commit -m "feat: ChipIn Wrapped — Spotify-style year-in-review with slide cards"
```

---

## Task 10: Recurring Expense Smart Reminders

**What it does:** When a user marks an expense as recurring, ChipIn logs the next due date. A local notification fires the day before: "Netflix is due tomorrow — add it to ChipIn?" Tapping opens Add Expense pre-filled.

**Files:**
- Create: `supabase/migrations/014_recurring_reminders.sql`
- Modify: `ChipIn/ChipIn/Core/NotificationManager.swift`
- Modify: `ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift`

- [ ] **Step 1: Add recurring tracking migration**

Create `supabase/migrations/014_recurring_reminders.sql`:

```sql
alter table public.expenses
    add column if not exists next_due_date date;

-- When an expense is recurring and submitted, next_due_date is set by the app.
-- No server-side trigger needed — app schedules local notification.
```

Run in Supabase SQL editor.

- [ ] **Step 2: Schedule local notification when recurring expense is saved**

In `NotificationManager.swift` (or create it if it doesn't exist), add:

```swift
import UserNotifications

struct NotificationManager {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Schedules a local notification the day before `dueDate` at 9am.
    static func scheduleRecurringReminder(expenseTitle: String, dueDate: Date, expenseId: UUID) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["recurring-\(expenseId.uuidString)"])

        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: dueDate) else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        components.hour = 9
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "📅 \(expenseTitle) is due tomorrow"
        content.body = "Tap to add it in ChipIn and split it with your group."
        content.sound = .default
        content.userInfo = ["expenseTitle": expenseTitle, "action": "add_recurring"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "recurring-\(expenseId.uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    static func cancelReminder(expenseId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["recurring-\(expenseId.uuidString)"])
    }
}
```

- [ ] **Step 3: Wire into AddExpenseViewModel**

In `AddExpenseViewModel.swift`, after a successful expense submission, if the expense is recurring:

```swift
// After expense is submitted successfully:
if isRecurring, let interval = recurrenceInterval {
    let nextDate = nextDueDate(from: Date(), interval: interval)
    NotificationManager.scheduleRecurringReminder(
        expenseTitle: title,
        dueDate: nextDate,
        expenseId: savedExpenseId  // the UUID returned from Supabase insert
    )
}

// Helper:
private func nextDueDate(from date: Date, interval: String) -> Date {
    var components = DateComponents()
    switch interval {
    case "weekly": components.weekOfYear = 1
    case "biweekly": components.weekOfYear = 2
    case "monthly": components.month = 1
    case "yearly": components.year = 1
    default: components.month = 1
    }
    return Calendar.current.date(byAdding: components, to: date) ?? date
}
```

- [ ] **Step 4: Request notification permission on first use**

In `ChipInApp.swift`, in the `.task { }` block on app startup:

```swift
await NotificationManager.requestPermission()
```

- [ ] **Step 5: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | \
  grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

- [ ] **Step 6: Manual test**

Add expense → toggle Recurring → set interval Monthly → submit → check notification center in simulator (`Device → Trigger Notification` or advance simulator date) → notification appears with expense title.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/014_recurring_reminders.sql \
        ChipIn/ChipIn/Core/NotificationManager.swift \
        ChipIn/ChipIn/Features/AddExpense/AddExpenseViewModel.swift \
        ChipIn/ChipIn/ChipInApp.swift
git commit -m "feat: recurring expense local notifications — reminds day before due date"
```

---

## Self-Review

### Spec Coverage Check

| Requirement | Task |
|---|---|
| Free, no payment features | ✅ All tasks — zero payment features |
| Exciting for university students | ✅ Reactions (T4), Wrapped (T9), Leaderboard (T8) |
| Easy to use | ✅ Auto-category (T1), Tip calc (T2), Templates (T3) |
| Social features | ✅ Activity feed (T5), QR friends (T7), Reactions (T4) |
| Profile personalization | ✅ Avatar (T6) |
| Smart/AI features | ✅ Auto-category (T1) |
| Recurring support | ✅ Recurring reminders (T10) |

### Placeholder Scan

- Task 7 (QR Scan): Manual text-paste fallback noted as TODO for native camera scanning — acceptable, it works functionally. Future improvement: replace sheet with an `AVCaptureMetadataOutput` QR scanner.
- All code blocks are complete and self-contained.
- All file paths are exact.

### Type Consistency

- `ExpenseTemplate` defined in `TemplateService.swift`, used in `TemplatePickerView.swift` and `AddExpenseViewModel.swift` — consistent.
- `ActivityItem` defined in `ActivityFeedViewModel.swift`, used only in `ActivityFeedView.swift` — consistent.
- `GroupStat` defined and used within `GroupLeaderboardView.swift` — consistent.
- `WrappedCard` defined and used within `WrappedView.swift` — consistent.
- `Reaction` defined in `ReactionsService.swift`, used in `ReactionsBar.swift` — consistent.

---

## Execution Order

Recommended sequence (each task is independent):

```
T1 (auto-category) → T2 (tip calc) → T3 (templates)  [day 1 — add expense UX]
T4 (reactions) → T5 (activity feed) → T6 (avatars)   [day 2 — social layer]
T7 (QR friends) → T8 (leaderboard)                   [day 3 — fun extras]
T9 (Wrapped) → T10 (recurring reminders)             [day 4 — delight features]
```
