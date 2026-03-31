# Chip In — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Chip In — a free, native SwiftUI iOS expense-splitting app for Canadian users with real-time sync, receipt scanning, and Interac settle-up.

**Architecture:** SwiftUI (iOS 17+) frontend with SwiftData for local persistence and offline-first operation. Supabase handles auth, database, real-time subscriptions, and edge functions. Gemini 1.5 Flash (free tier) powers receipt parsing via a Supabase Edge Function.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, Supabase Swift SDK, Gemini 1.5 Flash API, iOS Vision framework, WidgetKit, AVFoundation, AuthenticationServices (Apple Sign-In)

---

## Parallelization Map

```
Phase 1 (sequential): Project Setup → Supabase Schema → Auth
Phase 2 (parallel after Phase 1): Navigation + Models | Home Screen | Groups UI
Phase 3 (parallel after Phase 2): Add Expense Flow | Settle Up | Friends View
Phase 4 (parallel after Phase 3): Receipt Scanning | Recurring | Multi-Currency
Phase 5 (parallel after Phase 4): Insights/Charts | Widgets | Sounds | Notifications | Personalization
Phase 6 (sequential): Offline Sync + SwiftData, Final Polish
```

---

## File Structure

```
ChipIn/
├── ChipInApp.swift                    # App entry point, environment setup
├── ContentView.swift                  # Root TabView + floating + button
│
├── Core/
│   ├── SupabaseClient.swift           # Supabase singleton, env config
│   ├── AuthManager.swift             # Apple Sign-In, session, current user
│   ├── SyncManager.swift             # SwiftData ↔ Supabase real-time sync
│   └── NotificationManager.swift     # APNs registration + handling
│
├── Models/
│   ├── User.swift                    # User struct (matches users table)
│   ├── Group.swift                   # Group struct
│   ├── Expense.swift                 # Expense + ExpenseItem + ExpenseSplit
│   ├── Settlement.swift              # Settlement struct
│   └── Comment.swift                 # Comment struct
│
├── Features/
│   ├── Auth/
│   │   ├── AuthView.swift            # Sign-in screen
│   │   └── AuthViewModel.swift
│   │
│   ├── Home/
│   │   ├── HomeView.swift            # Tab 1 — balance + activity feed
│   │   └── HomeViewModel.swift
│   │
│   ├── Groups/
│   │   ├── GroupsView.swift          # Tab 2 — groups list
│   │   ├── GroupDetailView.swift     # Single group expenses + members
│   │   ├── ExpenseDetailView.swift   # Expense breakdown + comments
│   │   ├── FriendsView.swift         # 1-on-1 balances
│   │   └── GroupsViewModel.swift
│   │
│   ├── AddExpense/
│   │   ├── AddExpenseView.swift      # Main add expense sheet
│   │   ├── SplitPickerView.swift     # Split method selector
│   │   ├── ItemSplitView.swift       # Item-level receipt assignment
│   │   ├── ReceiptScannerView.swift  # Camera + Vision OCR
│   │   └── AddExpenseViewModel.swift
│   │
│   ├── SettleUp/
│   │   ├── SettleUpView.swift        # Settle flow + bank picker
│   │   └── SettleUpViewModel.swift
│   │
│   ├── Insights/
│   │   ├── InsightsView.swift        # Tab 3 — charts + history
│   │   └── InsightsViewModel.swift
│   │
│   └── Profile/
│       ├── ProfileView.swift         # Tab 4 — settings + personalization
│       └── ProfileViewModel.swift
│
├── Components/
│   ├── BalanceCard.swift             # Reusable balance display card
│   ├── ExpenseRow.swift              # Row in expense lists
│   ├── FloatingAddButton.swift       # Persistent + button
│   └── ConfettiView.swift           # Settle-up celebration
│
├── Services/
│   ├── ExpenseService.swift          # CRUD for expenses/splits
│   ├── GroupService.swift            # CRUD for groups/members
│   ├── SettlementService.swift       # Settle up logic
│   ├── ReceiptService.swift          # Vision OCR + Gemini call
│   ├── CurrencyService.swift         # frankfurter.app exchange rates
│   └── SoundService.swift           # AVFoundation custom sounds
│
├── Widgets/
│   ├── ChipInWidget.swift            # WidgetKit entry point
│   ├── BalanceWidget.swift           # Small balance widget
│   └── PendingWidget.swift           # Medium pending balances widget
│
└── Supabase/
    └── edge-functions/
        └── parse-receipt/
            └── index.ts              # Gemini 1.5 Flash receipt parser
```

---

## Phase 1: Foundation

### Task 1: Xcode Project Setup

**Files:**
- Create: `ChipIn.xcodeproj` (via Xcode)
- Create: `ChipIn/ChipInApp.swift`
- Create: `ChipIn/ContentView.swift`
- Create: `.gitignore`

- [ ] **Step 1: Create Xcode project**

Open Xcode → New Project → App. Settings:
```
Product Name: ChipIn
Bundle ID: com.yourname.chipin
Interface: SwiftUI
Language: Swift
Storage: SwiftData
Minimum Deployment: iOS 17.0
```

- [ ] **Step 2: Add `.gitignore`**

```
*.xcuserstate
*.xcuserdatad/
DerivedData/
.build/
*.ipa
*.dSYM.zip
.env
Secrets.swift
```

- [ ] **Step 3: Add Supabase Swift SDK via Swift Package Manager**

Xcode → File → Add Package Dependencies:
```
https://github.com/supabase/supabase-swift
```
Version: Up To Next Major from `2.0.0`
Add to target: ChipIn

- [ ] **Step 4: Create `Secrets.swift` (gitignored)**

```swift
// ChipIn/Core/Secrets.swift — DO NOT COMMIT
enum Secrets {
    static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
    static let supabaseAnonKey = "YOUR_ANON_KEY"
    static let geminiAPIKey = "YOUR_GEMINI_KEY"
}
```

- [ ] **Step 5: Initial commit**

```bash
git init
git add -A
git commit -m "feat: initial Xcode project setup with Supabase SDK"
```

---

### Task 2: Supabase Schema

**Files:**
- Create: `supabase/migrations/001_initial_schema.sql`

- [ ] **Step 1: Create Supabase project**

Go to supabase.com → New Project → name it `chipin` → choose a region close to Canada (us-east-1).

- [ ] **Step 2: Run initial schema migration**

In Supabase Dashboard → SQL Editor, run:

```sql
-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Users (extends Supabase auth.users)
create table public.users (
  id uuid references auth.users on delete cascade primary key,
  name text not null,
  avatar_url text,
  email text not null,
  default_currency text not null default 'CAD',
  interac_contact text,
  created_at timestamptz not null default now()
);

-- Groups
create table public.groups (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  emoji text not null default '👥',
  colour text not null default '#F97316',
  created_by uuid references public.users(id) not null,
  created_at timestamptz not null default now()
);

-- Group members
create table public.group_members (
  group_id uuid references public.groups(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  role text not null default 'member' check (role in ('admin', 'member')),
  primary key (group_id, user_id)
);

-- Expenses
create table public.expenses (
  id uuid primary key default uuid_generate_v4(),
  group_id uuid references public.groups(id) on delete cascade,
  paid_by uuid references public.users(id) not null,
  title text not null,
  total_amount numeric(10,2) not null,
  currency text not null default 'CAD',
  cad_amount numeric(10,2) not null,
  category text not null default 'Other',
  receipt_url text,
  is_recurring boolean not null default false,
  recurrence_interval text check (recurrence_interval in ('daily','weekly','biweekly','monthly')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Expense items (for receipt scanning)
create table public.expense_items (
  id uuid primary key default uuid_generate_v4(),
  expense_id uuid references public.expenses(id) on delete cascade,
  name text not null,
  price numeric(10,2) not null,
  tax_portion numeric(10,2) not null default 0,
  assigned_to uuid references public.users(id) not null
);

-- Expense splits
create table public.expense_splits (
  id uuid primary key default uuid_generate_v4(),
  expense_id uuid references public.expenses(id) on delete cascade,
  user_id uuid references public.users(id) not null,
  owed_amount numeric(10,2) not null,
  split_type text not null check (split_type in ('equal','percent','exact','byItem','shares')),
  is_settled boolean not null default false
);

-- Settlements
create table public.settlements (
  id uuid primary key default uuid_generate_v4(),
  from_user_id uuid references public.users(id) not null,
  to_user_id uuid references public.users(id) not null,
  amount numeric(10,2) not null,
  group_id uuid references public.groups(id),
  method text not null default 'interac' check (method in ('interac','cash','other')),
  settled_at timestamptz not null default now()
);

-- Comments
create table public.comments (
  id uuid primary key default uuid_generate_v4(),
  expense_id uuid references public.expenses(id) on delete cascade,
  user_id uuid references public.users(id) not null,
  body text not null,
  created_at timestamptz not null default now()
);

-- Notifications
create table public.notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  type text not null,
  reference_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
```

- [ ] **Step 3: Enable Row Level Security**

```sql
alter table public.users enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_items enable row level security;
alter table public.expense_splits enable row level security;
alter table public.settlements enable row level security;
alter table public.comments enable row level security;
alter table public.notifications enable row level security;

-- Users can read/write their own profile
create policy "users_own" on public.users
  for all using (auth.uid() = id);

-- Group members can see their groups
create policy "group_member_access" on public.groups
  for all using (
    id in (select group_id from public.group_members where user_id = auth.uid())
    or created_by = auth.uid()
  );

create policy "group_members_access" on public.group_members
  for all using (
    group_id in (select group_id from public.group_members where user_id = auth.uid())
  );

create policy "expenses_access" on public.expenses
  for all using (
    group_id in (select group_id from public.group_members where user_id = auth.uid())
  );

create policy "expense_items_access" on public.expense_items
  for all using (
    expense_id in (select id from public.expenses where group_id in (
      select group_id from public.group_members where user_id = auth.uid()
    ))
  );

create policy "expense_splits_access" on public.expense_splits
  for all using (
    expense_id in (select id from public.expenses where group_id in (
      select group_id from public.group_members where user_id = auth.uid()
    ))
  );

create policy "settlements_access" on public.settlements
  for all using (from_user_id = auth.uid() or to_user_id = auth.uid());

create policy "comments_access" on public.comments
  for all using (
    expense_id in (select id from public.expenses where group_id in (
      select group_id from public.group_members where user_id = auth.uid()
    ))
  );

create policy "notifications_own" on public.notifications
  for all using (user_id = auth.uid());
```

- [ ] **Step 4: Enable Realtime on key tables**

In Supabase Dashboard → Database → Replication, enable realtime for:
`expenses`, `expense_splits`, `settlements`, `comments`, `notifications`

- [ ] **Step 5: Save migration file and commit**

```bash
mkdir -p supabase/migrations
# Save the SQL above to supabase/migrations/001_initial_schema.sql
git add supabase/
git commit -m "feat: add Supabase schema with RLS policies"
```

---

### Task 3: Supabase Client + Data Models

**Files:**
- Create: `ChipIn/Core/SupabaseClient.swift`
- Create: `ChipIn/Models/User.swift`
- Create: `ChipIn/Models/Group.swift`
- Create: `ChipIn/Models/Expense.swift`
- Create: `ChipIn/Models/Settlement.swift`
- Create: `ChipIn/Models/Comment.swift`

- [ ] **Step 1: Create SupabaseClient**

```swift
// ChipIn/Core/SupabaseClient.swift
import Supabase
import Foundation

let supabase = SupabaseClient(
    supabaseURL: URL(string: Secrets.supabaseURL)!,
    supabaseKey: Secrets.supabaseAnonKey
)
```

- [ ] **Step 2: Create User model**

```swift
// ChipIn/Models/User.swift
import Foundation

struct AppUser: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var avatarURL: String?
    let email: String
    var defaultCurrency: String
    var interacContact: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case avatarURL = "avatar_url"
        case defaultCurrency = "default_currency"
        case interacContact = "interac_contact"
        case createdAt = "created_at"
    }
}
```

- [ ] **Step 3: Create Group model**

```swift
// ChipIn/Models/Group.swift
import Foundation

struct Group: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var emoji: String
    var colour: String
    let createdBy: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, colour
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct GroupMember: Codable, Hashable {
    let groupId: UUID
    let userId: UUID
    let joinedAt: Date
    var role: String

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case role
    }
}
```

- [ ] **Step 4: Create Expense model**

```swift
// ChipIn/Models/Expense.swift
import Foundation

struct Expense: Codable, Identifiable, Hashable {
    let id: UUID
    let groupId: UUID
    let paidBy: UUID
    var title: String
    var totalAmount: Decimal
    var currency: String
    var cadAmount: Decimal
    var category: String
    var receiptURL: String?
    var isRecurring: Bool
    var recurrenceInterval: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, currency, category
        case groupId = "group_id"
        case paidBy = "paid_by"
        case title
        case totalAmount = "total_amount"
        case cadAmount = "cad_amount"
        case receiptURL = "receipt_url"
        case isRecurring = "is_recurring"
        case recurrenceInterval = "recurrence_interval"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ExpenseItem: Codable, Identifiable, Hashable {
    let id: UUID
    let expenseId: UUID
    var name: String
    var price: Decimal
    var taxPortion: Decimal
    var assignedTo: UUID

    enum CodingKeys: String, CodingKey {
        case id, name, price
        case expenseId = "expense_id"
        case taxPortion = "tax_portion"
        case assignedTo = "assigned_to"
    }
}

struct ExpenseSplit: Codable, Identifiable, Hashable {
    let id: UUID
    let expenseId: UUID
    let userId: UUID
    var owedAmount: Decimal
    var splitType: String
    var isSettled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case expenseId = "expense_id"
        case userId = "user_id"
        case owedAmount = "owed_amount"
        case splitType = "split_type"
        case isSettled = "is_settled"
    }
}

enum SplitType: String {
    case equal, percent, exact, byItem, shares
}

enum ExpenseCategory: String, CaseIterable {
    case food = "Food"
    case travel = "Travel"
    case rent = "Rent"
    case fun = "Fun"
    case utilities = "Utilities"
    case other = "Other"

    var emoji: String {
        switch self {
        case .food: return "🍔"
        case .travel: return "✈️"
        case .rent: return "🏠"
        case .fun: return "🎉"
        case .utilities: return "💡"
        case .other: return "📦"
        }
    }
}
```

- [ ] **Step 5: Create Settlement + Comment models**

```swift
// ChipIn/Models/Settlement.swift
import Foundation

struct Settlement: Codable, Identifiable, Hashable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    var amount: Decimal
    var groupId: UUID?
    var method: String
    let settledAt: Date

    enum CodingKeys: String, CodingKey {
        case id, amount, method
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case groupId = "group_id"
        case settledAt = "settled_at"
    }
}
```

```swift
// ChipIn/Models/Comment.swift
import Foundation

struct Comment: Codable, Identifiable, Hashable {
    let id: UUID
    let expenseId: UUID
    let userId: UUID
    var body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body
        case expenseId = "expense_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add ChipIn/Core/SupabaseClient.swift ChipIn/Models/
git commit -m "feat: add Supabase client and core data models"
```

---

### Task 4: Authentication

**Files:**
- Create: `ChipIn/Core/AuthManager.swift`
- Create: `ChipIn/Features/Auth/AuthView.swift`
- Modify: `ChipIn/ChipInApp.swift`

- [ ] **Step 1: Create AuthManager**

```swift
// ChipIn/Core/AuthManager.swift
import SwiftUI
import Supabase
import AuthenticationServices

@MainActor
@Observable
class AuthManager {
    var currentUser: AppUser?
    var isAuthenticated = false
    var isLoading = true

    func initialize() async {
        do {
            let session = try await supabase.auth.session
            await loadUser(id: session.user.id)
        } catch {
            isAuthenticated = false
        }
        isLoading = false

        // Listen for auth changes
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .signedIn:
                if let session { await loadUser(id: session.user.id) }
            case .signedOut:
                currentUser = nil
                isAuthenticated = false
            default: break
            }
        }
    }

    private func loadUser(id: UUID) async {
        do {
            let user: AppUser = try await supabase
                .from("users")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            currentUser = user
            isAuthenticated = true
        } catch {
            isAuthenticated = false
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: tokenString)
        )
        // Upsert user profile
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        if !name.isEmpty {
            try await supabase.from("users").upsert([
                "id": session.user.id.uuidString,
                "name": name,
                "email": session.user.email ?? ""
            ]).execute()
        }
        await loadUser(id: session.user.id)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    enum AuthError: Error {
        case invalidCredential
    }
}
```

- [ ] **Step 2: Create AuthView**

```swift
// ChipIn/Features/Auth/AuthView.swift
import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(AuthManager.self) var auth

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Chip In")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Split expenses with friends")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#F97316"))
                }

                Spacer()

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task {
                        switch result {
                        case .success(let auth):
                            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                                try? await auth.signInWithApple(credential: credential)
                            }
                        case .failure: break
                        }
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}
```

- [ ] **Step 3: Update ChipInApp.swift**

```swift
// ChipIn/ChipInApp.swift
import SwiftUI

@main
struct ChipInApp: App {
    @State private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoading {
                    ProgressView()
                        .tint(Color(hex: "#F97316"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(hex: "#0A0A0A"))
                } else if auth.isAuthenticated {
                    ContentView()
                } else {
                    AuthView()
                }
            }
            .environment(auth)
            .task { await auth.initialize() }
        }
    }
}

// Hex color helper used throughout the app
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 4: In Supabase Dashboard, enable Apple provider**

Supabase Dashboard → Authentication → Providers → Apple → Enable. Follow the Apple Developer setup guide at supabase.com/docs/guides/auth/social-login/auth-apple.

- [ ] **Step 5: Commit**

```bash
git add ChipIn/Core/AuthManager.swift ChipIn/Features/Auth/ ChipIn/ChipInApp.swift
git commit -m "feat: add Apple Sign-In authentication"
```

---

## Phase 2: Navigation + Core UI

### Task 5: Navigation Structure + FloatingAddButton

**Files:**
- Create: `ChipIn/ContentView.swift`
- Create: `ChipIn/Components/FloatingAddButton.swift`

- [ ] **Step 1: Create ContentView with TabView**

```swift
// ChipIn/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAddExpense = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                GroupsView()
                    .tabItem { Label("Groups", systemImage: "person.3.fill") }
                    .tag(1)

                InsightsView()
                    .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
                    .tag(2)

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.fill") }
                    .tag(3)
            }
            .tint(Color(hex: "#F97316"))
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)

            FloatingAddButton {
                showAddExpense = true
            }
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView()
        }
    }
}
```

- [ ] **Step 2: Create FloatingAddButton**

```swift
// ChipIn/Components/FloatingAddButton.swift
import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .background(Color(hex: "#F97316"))
                .clipShape(Circle())
                .shadow(color: Color(hex: "#F97316").opacity(0.5), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Create stub views for each tab (so it compiles)**

```swift
// ChipIn/Features/Home/HomeView.swift
import SwiftUI
struct HomeView: View {
    var body: some View {
        NavigationStack {
            Text("Home").navigationTitle("Chip In")
                .background(Color(hex: "#0A0A0A"))
        }
    }
}
```

Repeat minimal stubs for `GroupsView`, `InsightsView`, `ProfileView`, `AddExpenseView` (each returns a `Text` placeholder in a `NavigationStack`).

- [ ] **Step 4: Build and run on simulator — confirm tabs and + button appear**

Expected: 4 tabs visible, orange + button floats above tab bar, tapping + shows a sheet.

- [ ] **Step 5: Commit**

```bash
git add ChipIn/ContentView.swift ChipIn/Components/FloatingAddButton.swift ChipIn/Features/
git commit -m "feat: add tab navigation and floating add button"
```

---

### Task 6: Home Screen

**Files:**
- Create: `ChipIn/Features/Home/HomeViewModel.swift`
- Modify: `ChipIn/Features/Home/HomeView.swift`
- Create: `ChipIn/Components/BalanceCard.swift`
- Create: `ChipIn/Components/ExpenseRow.swift`

- [ ] **Step 1: Create HomeViewModel**

```swift
// ChipIn/Features/Home/HomeViewModel.swift
import SwiftUI
import Supabase

@MainActor
@Observable
class HomeViewModel {
    var netBalance: Decimal = 0        // positive = owed to you, negative = you owe
    var pendingSettlements: [(user: AppUser, amount: Decimal)] = []
    var recentActivity: [Expense] = []
    var isLoading = false

    func load(currentUserId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Load all unsettled splits where I'm involved
            let splits: [ExpenseSplit] = try await supabase
                .from("expense_splits")
                .select()
                .eq("user_id", value: currentUserId)
                .eq("is_settled", value: false)
                .execute()
                .value

            // Load expenses paid by me that are unsettled for others
            let paidExpenses: [Expense] = try await supabase
                .from("expenses")
                .select()
                .eq("paid_by", value: currentUserId)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value

            recentActivity = paidExpenses

            // Net balance = sum of what others owe me - sum of what I owe
            let iOwe = splits.reduce(Decimal(0)) { $0 + $1.owedAmount }
            netBalance = -iOwe // simplified; full impl accounts for paid_by
        } catch {
            print("HomeViewModel load error: \(error)")
        }
    }
}
```

- [ ] **Step 2: Create BalanceCard component**

```swift
// ChipIn/Components/BalanceCard.swift
import SwiftUI

struct BalanceCard: View {
    let balance: Decimal

    private var isOwed: Bool { balance >= 0 }
    private var color: Color { isOwed ? Color(hex: "#10B981") : Color(hex: "#F87171") }
    private var label: String { isOwed ? "You're owed" : "You owe" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)

            Text(abs(balance), format: .currency(code: "CAD"))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 3: Create ExpenseRow component**

```swift
// ChipIn/Components/ExpenseRow.swift
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
```

- [ ] **Step 4: Build full HomeView**

```swift
// ChipIn/Features/Home/HomeView.swift
import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BalanceCard(balance: vm.netBalance)
                        .padding(.horizontal)

                    if !vm.recentActivity.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Activity")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)

                            LazyVStack(spacing: 0) {
                                ForEach(vm.recentActivity) { expense in
                                    ExpenseRow(expense: expense)
                                        .padding(.horizontal)
                                    Divider().background(Color(hex: "#2C2C2E"))
                                }
                            }
                            .background(Color(hex: "#1C1C1E"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
            }
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Chip In")
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                if let id = auth.currentUser?.id {
                    await vm.load(currentUserId: id)
                }
            }
            .refreshable {
                if let id = auth.currentUser?.id {
                    await vm.load(currentUserId: id)
                }
            }
        }
    }
}
```

- [ ] **Step 5: Build and run — verify home screen loads**

Expected: Dark background, orange balance card showing $0.00, no activity yet.

- [ ] **Step 6: Commit**

```bash
git add ChipIn/Features/Home/ ChipIn/Components/BalanceCard.swift ChipIn/Components/ExpenseRow.swift
git commit -m "feat: add home screen with balance card and activity feed"
```

---

### Task 7: Groups Screen

**Files:**
- Create: `ChipIn/Services/GroupService.swift`
- Create: `ChipIn/Features/Groups/GroupsViewModel.swift`
- Modify: `ChipIn/Features/Groups/GroupsView.swift`
- Create: `ChipIn/Features/Groups/GroupDetailView.swift`

- [ ] **Step 1: Create GroupService**

```swift
// ChipIn/Services/GroupService.swift
import Foundation
import Supabase

struct GroupService {
    func fetchGroups(for userId: UUID) async throws -> [Group] {
        let memberRows: [GroupMember] = try await supabase
            .from("group_members")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        let groupIds = memberRows.map { $0.groupId }
        guard !groupIds.isEmpty else { return [] }

        return try await supabase
            .from("groups")
            .select()
            .in("id", values: groupIds.map { $0.uuidString })
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createGroup(name: String, emoji: String, colour: String, createdBy: UUID) async throws -> Group {
        let group: Group = try await supabase
            .from("groups")
            .insert([
                "name": name,
                "emoji": emoji,
                "colour": colour,
                "created_by": createdBy.uuidString
            ])
            .select()
            .single()
            .execute()
            .value

        // Add creator as admin member
        try await supabase.from("group_members").insert([
            "group_id": group.id.uuidString,
            "user_id": createdBy.uuidString,
            "role": "admin"
        ]).execute()

        return group
    }

    func fetchExpenses(for groupId: UUID) async throws -> [Expense] {
        try await supabase
            .from("expenses")
            .select()
            .eq("group_id", value: groupId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
}
```

- [ ] **Step 2: Create GroupsViewModel**

```swift
// ChipIn/Features/Groups/GroupsViewModel.swift
import SwiftUI

@MainActor
@Observable
class GroupsViewModel {
    var groups: [Group] = []
    var isLoading = false
    var showCreateGroup = false
    private let service = GroupService()

    func load(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            groups = try await service.fetchGroups(for: userId)
        } catch {
            print("GroupsViewModel error: \(error)")
        }
    }

    func createGroup(name: String, emoji: String, colour: String, userId: UUID) async {
        do {
            let group = try await service.createGroup(name: name, emoji: emoji, colour: colour, createdBy: userId)
            groups.insert(group, at: 0)
        } catch {
            print("Create group error: \(error)")
        }
    }
}
```

- [ ] **Step 3: Build GroupsView**

```swift
// ChipIn/Features/Groups/GroupsView.swift
import SwiftUI

struct GroupsView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = GroupsViewModel()
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.groups) { group in
                    NavigationLink(destination: GroupDetailView(group: group)) {
                        HStack(spacing: 14) {
                            Text(group.emoji)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Color(hex: group.colour).opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                Text("Tap to view expenses")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(hex: "#1C1C1E"))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Groups")
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreate = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(Color(hex: "#F97316"))
                    }
                }
            }
            .task {
                if let id = auth.currentUser?.id { await vm.load(userId: id) }
            }
            .sheet(isPresented: $showCreate) {
                CreateGroupSheet { name, emoji, colour in
                    if let id = auth.currentUser?.id {
                        await vm.createGroup(name: name, emoji: emoji, colour: colour, userId: id)
                    }
                }
            }
        }
    }
}

struct CreateGroupSheet: View {
    let onCreate: (String, String, String) async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var emoji = "👥"
    @State private var colour = "#F97316"

    private let colours = ["#F97316", "#3B82F6", "#10B981", "#8B5CF6", "#EC4899"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Details") {
                    HStack {
                        Text("Icon").foregroundStyle(.secondary)
                        Spacer()
                        EmojiPickerField(emoji: $emoji)
                    }
                    TextField("Group name", text: $name)
                }
                Section("Colour") {
                    HStack(spacing: 16) {
                        ForEach(colours, id: \.self) { c in
                            Circle()
                                .fill(Color(hex: c))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(.white, lineWidth: colour == c ? 3 : 0))
                                .onTapGesture { colour = c }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await onCreate(name, emoji, colour)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct EmojiPickerField: View {
    @Binding var emoji: String
    var body: some View {
        TextField("", text: $emoji)
            .multilineTextAlignment(.center)
            .frame(width: 44)
    }
}
```

- [ ] **Step 4: Create GroupDetailView stub (full impl in later task)**

```swift
// ChipIn/Features/Groups/GroupDetailView.swift
import SwiftUI

struct GroupDetailView: View {
    let group: Group
    @State private var expenses: [Expense] = []
    private let service = GroupService()

    var body: some View {
        List {
            ForEach(expenses) { expense in
                ExpenseRow(expense: expense)
                    .listRowBackground(Color(hex: "#1C1C1E"))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(hex: "#0A0A0A"))
        .navigationTitle(group.name)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            expenses = (try? await service.fetchExpenses(for: group.id)) ?? []
        }
    }
}
```

- [ ] **Step 5: Build and run — verify groups list and create group sheet**

- [ ] **Step 6: Commit**

```bash
git add ChipIn/Services/GroupService.swift ChipIn/Features/Groups/
git commit -m "feat: add groups list, create group, and group detail screen"
```

---

## Phase 3: Core Features

### Task 8: Add Expense Flow

**Files:**
- Create: `ChipIn/Services/ExpenseService.swift`
- Create: `ChipIn/Services/CurrencyService.swift`
- Create: `ChipIn/Features/AddExpense/AddExpenseViewModel.swift`
- Modify: `ChipIn/Features/AddExpense/AddExpenseView.swift`
- Create: `ChipIn/Features/AddExpense/SplitPickerView.swift`

- [ ] **Step 1: Create CurrencyService**

```swift
// ChipIn/Services/CurrencyService.swift
import Foundation

struct CurrencyService {
    func convert(amount: Decimal, from currency: String, to target: String = "CAD") async throws -> Decimal {
        guard currency != target else { return amount }
        let url = URL(string: "https://api.frankfurter.app/latest?from=\(currency)&to=\(target)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
        guard let rate = response.rates[target] else { throw CurrencyError.rateNotFound }
        return amount * Decimal(rate)
    }
}

private struct FrankfurterResponse: Decodable {
    let rates: [String: Double]
}

enum CurrencyError: Error {
    case rateNotFound
}
```

- [ ] **Step 2: Create ExpenseService**

```swift
// ChipIn/Services/ExpenseService.swift
import Foundation
import Supabase

struct ExpenseService {
    private let currencyService = CurrencyService()

    func createExpense(
        groupId: UUID,
        paidBy: UUID,
        title: String,
        amount: Decimal,
        currency: String,
        category: String,
        splitType: SplitType,
        splits: [(userId: UUID, amount: Decimal)],
        isRecurring: Bool,
        recurrenceInterval: String?,
        items: [NewExpenseItem] = []
    ) async throws {
        let cadAmount = try await currencyService.convert(amount: amount, from: currency)

        let expense: Expense = try await supabase
            .from("expenses")
            .insert([
                "group_id": groupId.uuidString,
                "paid_by": paidBy.uuidString,
                "title": title,
                "total_amount": "\(amount)",
                "currency": currency,
                "cad_amount": "\(cadAmount)",
                "category": category,
                "is_recurring": isRecurring,
                "recurrence_interval": recurrenceInterval as Any
            ])
            .select()
            .single()
            .execute()
            .value

        // Insert splits
        let splitRows = splits.map { split in [
            "expense_id": expense.id.uuidString,
            "user_id": split.userId.uuidString,
            "owed_amount": "\(split.amount)",
            "split_type": splitType.rawValue,
            "is_settled": false
        ] as [String: Any] }
        try await supabase.from("expense_splits").insert(splitRows).execute()

        // Insert items if byItem split
        if !items.isEmpty {
            let itemRows = items.map { item in [
                "expense_id": expense.id.uuidString,
                "name": item.name,
                "price": "\(item.price)",
                "tax_portion": "\(item.taxPortion)",
                "assigned_to": item.assignedTo.uuidString
            ] as [String: Any] }
            try await supabase.from("expense_items").insert(itemRows).execute()
        }
    }

    func calculateEqualSplits(amount: Decimal, userIds: [UUID]) -> [(userId: UUID, amount: Decimal)] {
        guard !userIds.isEmpty else { return [] }
        let share = (amount / Decimal(userIds.count)).rounded(.bankers)
        let remainder = amount - share * Decimal(userIds.count)
        return userIds.enumerated().map { idx, userId in
            (userId, idx == 0 ? share + remainder : share)
        }
    }
}

struct NewExpenseItem {
    let name: String
    let price: Decimal
    let taxPortion: Decimal
    let assignedTo: UUID
}
```

- [ ] **Step 3: Create AddExpenseViewModel**

```swift
// ChipIn/Features/AddExpense/AddExpenseViewModel.swift
import SwiftUI

@MainActor
@Observable
class AddExpenseViewModel {
    var title = ""
    var amount = ""
    var currency = "CAD"
    var category = ExpenseCategory.food
    var splitType = SplitType.equal
    var selectedGroupId: UUID?
    var selectedUserIds: [UUID] = []
    var isRecurring = false
    var recurrenceInterval = "monthly"
    var note = ""
    var isSubmitting = false
    var error: String?

    private let service = ExpenseService()

    var amountDecimal: Decimal {
        Decimal(string: amount) ?? 0
    }

    func submit(paidBy: UUID) async -> Bool {
        guard !title.isEmpty, amountDecimal > 0, let groupId = selectedGroupId, !selectedUserIds.isEmpty else {
            error = "Please fill in all required fields"
            return false
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let splits: [(userId: UUID, amount: Decimal)]
            switch splitType {
            case .equal:
                splits = service.calculateEqualSplits(amount: amountDecimal, userIds: selectedUserIds)
            default:
                splits = service.calculateEqualSplits(amount: amountDecimal, userIds: selectedUserIds)
            }

            try await service.createExpense(
                groupId: groupId,
                paidBy: paidBy,
                title: title,
                amount: amountDecimal,
                currency: currency,
                category: category.rawValue,
                splitType: splitType,
                splits: splits,
                isRecurring: isRecurring,
                recurrenceInterval: isRecurring ? recurrenceInterval : nil
            )
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
```

- [ ] **Step 4: Build AddExpenseView**

```swift
// ChipIn/Features/AddExpense/AddExpenseView.swift
import SwiftUI

struct AddExpenseView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @State private var vm = AddExpenseViewModel()
    @State private var groups: [Group] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        Text("CAD")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $vm.amount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(hex: "#F97316"))
                    }
                }

                Section("Details") {
                    TextField("What's this for?", text: $vm.title)

                    Picker("Group", selection: $vm.selectedGroupId) {
                        Text("Select group").tag(Optional<UUID>.none)
                        ForEach(groups) { g in
                            Text("\(g.emoji) \(g.name)").tag(Optional(g.id))
                        }
                    }

                    Picker("Category", selection: $vm.category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Text("\(cat.emoji) \(cat.rawValue)").tag(cat)
                        }
                    }
                }

                Section("Split") {
                    SplitPickerView(splitType: $vm.splitType)
                }

                Section("Recurring") {
                    Toggle("Repeat automatically", isOn: $vm.isRecurring)
                    if vm.isRecurring {
                        Picker("Frequency", selection: $vm.recurrenceInterval) {
                            Text("Daily").tag("daily")
                            Text("Weekly").tag("weekly")
                            Text("Bi-weekly").tag("biweekly")
                            Text("Monthly").tag("monthly")
                        }
                    }
                }

                if let error = vm.error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if let id = auth.currentUser?.id, await vm.submit(paidBy: id) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(vm.isSubmitting)
                }
            }
            .task {
                if let id = auth.currentUser?.id {
                    groups = (try? await GroupService().fetchGroups(for: id)) ?? []
                }
            }
        }
    }
}
```

- [ ] **Step 5: Create SplitPickerView**

```swift
// ChipIn/Features/AddExpense/SplitPickerView.swift
import SwiftUI

struct SplitPickerView: View {
    @Binding var splitType: SplitType

    private let options: [(SplitType, String, String)] = [
        (.equal, "Equal", "person.2"),
        (.percent, "Percent", "percent"),
        (.exact, "Exact", "dollarsign"),
        (.byItem, "By Item", "list.bullet"),
        (.shares, "Shares", "chart.pie")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options, id: \.0.rawValue) { type, label, icon in
                    Button {
                        splitType = type
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.headline)
                            Text(label)
                                .font(.caption)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(splitType == type ? Color(hex: "#F97316") : Color(hex: "#2C2C2E"))
                        .foregroundStyle(splitType == type ? .black : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
```

- [ ] **Step 6: Build and run — verify expense can be created**

- [ ] **Step 7: Commit**

```bash
git add ChipIn/Services/ ChipIn/Features/AddExpense/
git commit -m "feat: add expense creation with split types and currency conversion"
```

---

### Task 9: Settle Up Flow

**Files:**
- Create: `ChipIn/Services/SettlementService.swift`
- Create: `ChipIn/Features/SettleUp/SettleUpView.swift`
- Create: `ChipIn/Features/SettleUp/SettleUpViewModel.swift`
- Create: `ChipIn/Components/ConfettiView.swift`

- [ ] **Step 1: Create SettlementService**

```swift
// ChipIn/Services/SettlementService.swift
import Foundation
import Supabase

struct SettlementService {
    func settle(fromUserId: UUID, toUserId: UUID, amount: Decimal, groupId: UUID?, method: String) async throws {
        // Record settlement
        try await supabase.from("settlements").insert([
            "from_user_id": fromUserId.uuidString,
            "to_user_id": toUserId.uuidString,
            "amount": "\(amount)",
            "group_id": groupId?.uuidString as Any,
            "method": method
        ]).execute()

        // Mark relevant splits as settled
        try await supabase
            .from("expense_splits")
            .update(["is_settled": true])
            .eq("user_id", value: fromUserId)
            .execute()
    }

    func openBankApp(_ bank: BankApp) {
        guard let url = bank.url, UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}

enum BankApp: String, CaseIterable, Identifiable {
    case td = "TD Bank"
    case rbc = "RBC"
    case scotiabank = "Scotiabank"
    case bmo = "BMO"
    case cibc = "CIBC"
    case tangerine = "Tangerine"
    case eq = "EQ Bank"
    case wealthsimple = "Wealthsimple"

    var id: String { rawValue }

    var url: URL? {
        switch self {
        case .td: return URL(string: "tdct://")
        case .rbc: return URL(string: "rbcmobile://")
        case .scotiabank: return URL(string: "scotiabank://")
        case .bmo: return URL(string: "bmo://")
        case .cibc: return URL(string: "cibc://")
        case .tangerine: return URL(string: "tangerine://")
        case .eq: return URL(string: "eqbank://")
        case .wealthsimple: return URL(string: "wealthsimple://")
        }
    }
}
```

- [ ] **Step 2: Create SettleUpViewModel**

```swift
// ChipIn/Features/SettleUp/SettleUpViewModel.swift
import SwiftUI

@MainActor
@Observable
class SettleUpViewModel {
    var isSettled = false
    var isLoading = false
    private let service = SettlementService()

    func copyAmount(_ amount: Decimal) {
        let formatted = NSDecimalNumber(decimal: amount).stringValue
        UIPasteboard.general.string = formatted
    }

    func openBank(_ bank: BankApp) {
        service.openBankApp(bank)
    }

    func markAsSettled(fromUserId: UUID, toUserId: UUID, amount: Decimal, groupId: UUID?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.settle(fromUserId: fromUserId, toUserId: toUserId, amount: amount, groupId: groupId, method: "interac")
            isSettled = true
        } catch {
            print("Settlement error: \(error)")
        }
    }
}
```

- [ ] **Step 3: Create ConfettiView**

```swift
// ChipIn/Components/ConfettiView.swift
import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .offset(x: p.x, y: p.y)
                    .opacity(p.opacity)
            }
        }
        .onAppear { spawnParticles() }
        .allowsHitTesting(false)
    }

    private func spawnParticles() {
        let colors: [Color] = [.orange, .yellow, .green, .blue, .pink, .purple]
        particles = (0..<60).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: -180...180),
                y: CGFloat.random(in: -300...100),
                size: CGFloat.random(in: 6...14),
                color: colors.randomElement()!,
                opacity: Double.random(in: 0.7...1.0)
            )
        }
        withAnimation(.easeOut(duration: 1.5)) {
            for i in particles.indices {
                particles[i].y += CGFloat.random(in: 200...400)
                particles[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}
```

- [ ] **Step 4: Create SettleUpView**

```swift
// ChipIn/Features/SettleUp/SettleUpView.swift
import SwiftUI

struct SettleUpView: View {
    let fromUserId: UUID
    let toUser: AppUser
    let amount: Decimal
    let groupId: UUID?

    @Environment(\.dismiss) var dismiss
    @State private var vm = SettleUpViewModel()
    @State private var showBankPicker = false
    @State private var amountCopied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                if vm.isSettled {
                    VStack(spacing: 24) {
                        ConfettiView()
                        Text("🎉").font(.system(size: 72))
                        Text("All settled!").font(.title).bold().foregroundStyle(.white)
                        Text("You sent \(amount, format: .currency(code: "CAD")) to \(toUser.name)")
                            .foregroundStyle(.secondary)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "#F97316"))
                    }
                } else {
                    VStack(spacing: 24) {
                        Spacer()

                        VStack(spacing: 6) {
                            Text("You owe \(toUser.name)").font(.headline).foregroundStyle(.secondary)
                            Text(amount, format: .currency(code: "CAD"))
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#F87171"))
                        }

                        if let interac = toUser.interacContact {
                            HStack {
                                Image(systemName: "envelope.fill").foregroundStyle(.secondary)
                                Text(interac).foregroundStyle(.white)
                            }
                            .padding(12)
                            .background(Color(hex: "#1C1C1E"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(spacing: 12) {
                            Button {
                                vm.copyAmount(amount)
                                amountCopied = true
                            } label: {
                                Label(amountCopied ? "Copied!" : "Copy Amount", systemImage: amountCopied ? "checkmark" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: "#2C2C2E"))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button {
                                showBankPicker = true
                            } label: {
                                Label("Open Bank App", systemImage: "building.columns.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: "#F97316"))
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button {
                                Task {
                                    await vm.markAsSettled(fromUserId: fromUserId, toUserId: toUser.id, amount: amount, groupId: groupId)
                                }
                            } label: {
                                Text("I've sent it — mark as settled")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: "#1C1C1E"))
                                    .foregroundStyle(Color(hex: "#F97316"))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                }
            }
            .navigationTitle("Settle Up")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showBankPicker) {
                BankPickerSheet { bank in
                    vm.openBank(bank)
                    showBankPicker = false
                }
            }
        }
    }
}

struct BankPickerSheet: View {
    let onSelect: (BankApp) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List(BankApp.allCases) { bank in
                Button(bank.rawValue) {
                    onSelect(bank)
                    dismiss()
                }
                .foregroundStyle(.white)
                .listRowBackground(Color(hex: "#1C1C1E"))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Open Bank App")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
```

- [ ] **Step 5: Build and run — verify settle up flow end-to-end**

- [ ] **Step 6: Commit**

```bash
git add ChipIn/Services/SettlementService.swift ChipIn/Features/SettleUp/ ChipIn/Components/ConfettiView.swift
git commit -m "feat: add settle up flow with Interac bank deep-link and confetti"
```

---

## Phase 4: Power Features

### Task 10: Receipt Scanning

**Files:**
- Create: `supabase/edge-functions/parse-receipt/index.ts`
- Create: `ChipIn/Services/ReceiptService.swift`
- Create: `ChipIn/Features/AddExpense/ReceiptScannerView.swift`
- Create: `ChipIn/Features/AddExpense/ItemSplitView.swift`

- [ ] **Step 1: Deploy Supabase Edge Function for receipt parsing**

```typescript
// supabase/edge-functions/parse-receipt/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!
const GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent"

serve(async (req) => {
  const { imageBase64 } = await req.json()

  const prompt = `Analyze this receipt image and extract:
1. Each line item with name and price
2. Subtotal
3. Tax amount
4. Tip amount (if any)
5. Total

Return ONLY valid JSON in this exact format:
{
  "items": [{"name": "string", "price": number}],
  "subtotal": number,
  "tax": number,
  "tip": number,
  "total": number
}`

  const response = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{
        parts: [
          { text: prompt },
          { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }
        ]
      }]
    })
  })

  const data = await response.json()
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}"

  // Extract JSON from response
  const jsonMatch = text.match(/\{[\s\S]*\}/)
  const parsed = jsonMatch ? JSON.parse(jsonMatch[0]) : {}

  return new Response(JSON.stringify(parsed), {
    headers: { "Content-Type": "application/json" }
  })
})
```

Deploy with: `supabase functions deploy parse-receipt`
Set secret: `supabase secrets set GEMINI_API_KEY=your_key_here`

- [ ] **Step 2: Create ReceiptService**

```swift
// ChipIn/Services/ReceiptService.swift
import Foundation
import Vision
import UIKit

struct ParsedReceipt {
    struct Item {
        var name: String
        var price: Decimal
        var taxPortion: Decimal = 0
        var assignedTo: UUID?
    }
    var items: [Item]
    var subtotal: Decimal
    var tax: Decimal
    var tip: Decimal
    var total: Decimal
}

struct ReceiptService {
    func parseReceipt(image: UIImage) async throws -> ParsedReceipt {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ReceiptError.imageConversionFailed
        }
        let base64 = imageData.base64EncodedString()

        let response = try await supabase.functions.invoke(
            "parse-receipt",
            options: .init(body: ["imageBase64": base64])
        )

        let result = try JSONDecoder().decode(ReceiptAPIResponse.self, from: response.data)

        let taxRate = result.subtotal > 0 ? result.tax / result.subtotal : 0
        let items = result.items.map { item -> ParsedReceipt.Item in
            let taxPortion = Decimal(item.price) * taxRate
            return ParsedReceipt.Item(name: item.name, price: Decimal(item.price), taxPortion: taxPortion)
        }

        return ParsedReceipt(
            items: items,
            subtotal: Decimal(result.subtotal),
            tax: Decimal(result.tax),
            tip: Decimal(result.tip),
            total: Decimal(result.total)
        )
    }
}

private struct ReceiptAPIResponse: Decodable {
    struct Item: Decodable { let name: String; let price: Double }
    let items: [Item]
    let subtotal: Double
    let tax: Double
    let tip: Double
    let total: Double
}

enum ReceiptError: Error {
    case imageConversionFailed
    case parseFailed
}
```

- [ ] **Step 3: Create ReceiptScannerView**

```swift
// ChipIn/Features/AddExpense/ReceiptScannerView.swift
import SwiftUI
import PhotosUI

struct ReceiptScannerView: View {
    @Binding var parsedReceipt: ParsedReceipt?
    @Environment(\.dismiss) var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    private let service = ReceiptService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(Color(hex: "#F97316"))
                        Text("Reading receipt...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 64))
                            .foregroundStyle(Color(hex: "#F97316"))

                        Text("Scan a Receipt")
                            .font(.title2).bold().foregroundStyle(.white)
                        Text("AI will read all items, prices, and tax automatically")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("Choose Photo", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "#F97316"))
                                .foregroundStyle(.black)
                                .fontWeight(.semibold)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)

                        if let error = errorMessage {
                            Text(error).foregroundStyle(.red).font(.caption)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Receipt Scanner")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    isProcessing = true
                    defer { isProcessing = false }
                    do {
                        if let data = try await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            parsedReceipt = try await service.parseReceipt(image: image)
                            dismiss()
                        }
                    } catch {
                        errorMessage = "Couldn't read receipt. Try a clearer photo."
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Create ItemSplitView**

```swift
// ChipIn/Features/AddExpense/ItemSplitView.swift
import SwiftUI

struct ItemSplitView: View {
    @Binding var receipt: ParsedReceipt
    let groupMembers: [AppUser]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Items") {
                    ForEach($receipt.items.indices, id: \.self) { idx in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(receipt.items[idx].name)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(receipt.items[idx].price, format: .currency(code: "CAD"))
                                    .foregroundStyle(Color(hex: "#F97316"))
                            }

                            Picker("Assign to", selection: $receipt.items[idx].assignedTo) {
                                Text("Unassigned").tag(Optional<UUID>.none)
                                ForEach(groupMembers) { member in
                                    Text(member.name).tag(Optional(member.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color(hex: "#F97316"))
                        }
                        .listRowBackground(Color(hex: "#1C1C1E"))
                    }
                }

                Section("Summary") {
                    HStack { Text("Subtotal"); Spacer(); Text(receipt.subtotal, format: .currency(code: "CAD")) }
                        .listRowBackground(Color(hex: "#1C1C1E"))
                    HStack { Text("Tax"); Spacer(); Text(receipt.tax, format: .currency(code: "CAD")).foregroundStyle(.secondary) }
                        .listRowBackground(Color(hex: "#1C1C1E"))
                    HStack { Text("Total").bold(); Spacer(); Text(receipt.total, format: .currency(code: "CAD")).bold().foregroundStyle(Color(hex: "#F97316")) }
                        .listRowBackground(Color(hex: "#1C1C1E"))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Assign Items")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "#F97316"))
                }
            }
        }
    }
}
```

- [ ] **Step 5: Build and test receipt scanning on device**

Note: Camera/photo picker requires a real device or simulator with a photo library.

- [ ] **Step 6: Commit**

```bash
git add supabase/edge-functions/ ChipIn/Services/ReceiptService.swift ChipIn/Features/AddExpense/ReceiptScannerView.swift ChipIn/Features/AddExpense/ItemSplitView.swift
git commit -m "feat: add receipt scanning with Gemini AI item parsing and proportional tax"
```

---

## Phase 5: Polish Features

### Task 11: Custom Sounds + Haptics

**Files:**
- Create: `ChipIn/Services/SoundService.swift`
- Add sound files to `ChipIn/Resources/Sounds/` (`.caf` format)

- [ ] **Step 1: Add sound files**

Record or source 4 short audio clips and convert to `.caf`:
- `expense_add.caf` — neutral chime ("faaah")
- `money_in.caf` — celebratory ("haiyo!")
- `money_out.caf` — subtle uh-oh
- `settled.caf` — big satisfying sound

Convert with: `afconvert -f caff -d ima4 input.m4a output.caf`

Add files to Xcode project under `ChipIn/Resources/Sounds/` and ensure they're included in the app target.

- [ ] **Step 2: Create SoundService**

```swift
// ChipIn/Services/SoundService.swift
import AVFoundation
import UIKit

enum AppSound: String {
    case expenseAdd = "expense_add"
    case moneyIn = "money_in"
    case moneyOut = "money_out"
    case settled = "settled"
}

@MainActor
class SoundService: ObservableObject {
    static let shared = SoundService()
    private var players: [AppSound: AVAudioPlayer] = [:]
    private var soundEnabled: Bool {
        UserDefaults.standard.bool(forKey: "soundEnabled")
    }

    private init() {
        AppSound.allCases.forEach { sound in
            if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                players[sound] = player
            }
        }
    }

    func play(_ sound: AppSound, haptic: UIImpactFeedbackGenerator.FeedbackStyle? = nil) {
        guard soundEnabled else { return }
        players[sound]?.play()
        if let style = haptic {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}

extension AppSound: CaseIterable {}
```

- [ ] **Step 3: Enable UserDefaults default for sound**

```swift
// In ChipInApp.swift, inside init():
UserDefaults.standard.register(defaults: ["soundEnabled": true])
```

- [ ] **Step 4: Wire sounds to events**

In `SettleUpViewModel.markAsSettled`, after `isSettled = true`:
```swift
await SoundService.shared.play(.settled, haptic: .heavy)
```

In `ExpenseService.createExpense`, after success:
```swift
await SoundService.shared.play(.expenseAdd, haptic: .light)
```

In `HomeViewModel.load`, when `netBalance > 0`:
```swift
await SoundService.shared.play(.moneyIn, haptic: .medium)
```

- [ ] **Step 5: Add sound toggle in Profile**

```swift
// In ProfileView, inside the settings list:
Toggle("Sounds & Haptics", isOn: Binding(
    get: { UserDefaults.standard.bool(forKey: "soundEnabled") },
    set: { UserDefaults.standard.set($0, forKey: "soundEnabled") }
))
```

- [ ] **Step 6: Commit**

```bash
git add ChipIn/Services/SoundService.swift ChipIn/Resources/Sounds/
git commit -m "feat: add custom sounds and haptic feedback per event type"
```

---

### Task 12: Insights Tab

**Files:**
- Create: `ChipIn/Features/Insights/InsightsViewModel.swift`
- Modify: `ChipIn/Features/Insights/InsightsView.swift`

- [ ] **Step 1: Create InsightsViewModel**

```swift
// ChipIn/Features/Insights/InsightsViewModel.swift
import SwiftUI

struct CategoryStat: Identifiable {
    let id = UUID()
    let category: String
    let emoji: String
    let total: Decimal
    let colour: Color
}

@MainActor
@Observable
class InsightsViewModel {
    var categoryStats: [CategoryStat] = []
    var monthlyTotal: Decimal = 0
    var totalOwed: Decimal = 0
    var totalSettled: Decimal = 0
    var settlements: [Settlement] = []

    private let colours: [Color] = [
        Color(hex: "#F97316"), Color(hex: "#3B82F6"),
        Color(hex: "#10B981"), Color(hex: "#8B5CF6"),
        Color(hex: "#EC4899"), Color(hex: "#FBBF24")
    ]

    func load(userId: UUID) async {
        do {
            let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!

            let expenses: [Expense] = try await supabase
                .from("expenses")
                .select()
                .gte("created_at", value: ISO8601DateFormatter().string(from: startOfMonth))
                .execute()
                .value

            monthlyTotal = expenses.reduce(0) { $0 + $1.cadAmount }

            // Group by category
            var byCategory: [String: Decimal] = [:]
            for expense in expenses {
                byCategory[expense.category, default: 0] += expense.cadAmount
            }

            categoryStats = byCategory.enumerated().map { idx, pair in
                let cat = ExpenseCategory(rawValue: pair.key) ?? .other
                return CategoryStat(
                    category: pair.key,
                    emoji: cat.emoji,
                    total: pair.value,
                    colour: colours[idx % colours.count]
                )
            }.sorted { $0.total > $1.total }

            settlements = try await supabase
                .from("settlements")
                .select()
                .or("from_user_id.eq.\(userId),to_user_id.eq.\(userId)")
                .order("settled_at", ascending: false)
                .limit(20)
                .execute()
                .value

        } catch {
            print("InsightsViewModel error: \(error)")
        }
    }
}
```

- [ ] **Step 2: Build InsightsView**

```swift
// ChipIn/Features/Insights/InsightsView.swift
import SwiftUI
import Charts

struct InsightsView: View {
    @Environment(AuthManager.self) var auth
    @State private var vm = InsightsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Monthly summary
                    HStack(spacing: 12) {
                        StatCard(title: "Spent", value: vm.monthlyTotal, color: Color(hex: "#F97316"))
                    }
                    .padding(.horizontal)

                    // Category chart
                    if !vm.categoryStats.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Category")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)

                            Chart(vm.categoryStats) { stat in
                                SectorMark(
                                    angle: .value("Amount", stat.total),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 2
                                )
                                .foregroundStyle(stat.colour)
                            }
                            .frame(height: 220)
                            .padding(.horizontal)

                            // Legend
                            VStack(spacing: 8) {
                                ForEach(vm.categoryStats) { stat in
                                    HStack {
                                        Circle().fill(stat.colour).frame(width: 10, height: 10)
                                        Text("\(stat.emoji) \(stat.category)").foregroundStyle(.white)
                                        Spacer()
                                        Text(stat.total, format: .currency(code: "CAD"))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Insights")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                if let id = auth.currentUser?.id { await vm.load(userId: id) }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: Decimal
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            Text(value, format: .currency(code: "CAD"))
                .font(.title2).bold().foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add ChipIn/Features/Insights/
git commit -m "feat: add insights tab with category donut chart"
```

---

### Task 13: Profile + Personalization

**Files:**
- Modify: `ChipIn/Features/Profile/ProfileView.swift`

- [ ] **Step 1: Build ProfileView**

```swift
// ChipIn/Features/Profile/ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) var auth
    @State private var soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
    @State private var biometricEnabled = false
    @State private var hideBalances = false
    @State private var selectedAccent = "#F97316"

    private let accents = ["#F97316", "#3B82F6", "#10B981", "#8B5CF6", "#EC4899"]

    var body: some View {
        NavigationStack {
            List {
                // Profile header
                Section {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(hex: selectedAccent).opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(auth.currentUser?.name.prefix(1) ?? "?")
                                    .font(.title2).bold()
                                    .foregroundStyle(Color(hex: selectedAccent))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.currentUser?.name ?? "").font(.headline).foregroundStyle(.white)
                            Text(auth.currentUser?.email ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color(hex: "#1C1C1E"))
                }

                // Interac
                Section("Interac e-Transfer") {
                    TextField("Your email or phone", text: .constant(auth.currentUser?.interacContact ?? ""))
                        .foregroundStyle(.white)
                        .listRowBackground(Color(hex: "#1C1C1E"))
                }

                // Appearance
                Section("Appearance") {
                    HStack {
                        Text("Accent Colour")
                        Spacer()
                        HStack(spacing: 10) {
                            ForEach(accents, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(.white, lineWidth: selectedAccent == hex ? 2 : 0))
                                    .onTapGesture { selectedAccent = hex }
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "#1C1C1E"))
                }

                // Privacy
                Section("Privacy") {
                    Toggle("Biometric Lock", isOn: $biometricEnabled)
                        .tint(Color(hex: selectedAccent))
                        .listRowBackground(Color(hex: "#1C1C1E"))
                    Toggle("Hide Balances", isOn: $hideBalances)
                        .tint(Color(hex: selectedAccent))
                        .listRowBackground(Color(hex: "#1C1C1E"))
                }

                // Sounds
                Section("Sounds & Haptics") {
                    Toggle("Custom Sounds", isOn: $soundEnabled)
                        .tint(Color(hex: selectedAccent))
                        .listRowBackground(Color(hex: "#1C1C1E"))
                        .onChange(of: soundEnabled) { _, val in
                            UserDefaults.standard.set(val, forKey: "soundEnabled")
                        }
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        Task { try? await auth.signOut() }
                    } label: {
                        Text("Sign Out").frame(maxWidth: .infinity, alignment: .center)
                    }
                    .listRowBackground(Color(hex: "#1C1C1E"))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0A0A0A"))
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ChipIn/Features/Profile/
git commit -m "feat: add profile screen with personalization and privacy settings"
```

---

### Task 14: WidgetKit

**Files:**
- Create: `ChipInWidget/ChipInWidget.swift`
- Create: `ChipInWidget/BalanceWidget.swift`

- [ ] **Step 1: Add Widget Extension target**

Xcode → File → New → Target → Widget Extension. Name: `ChipInWidget`. Uncheck "Include Configuration App Intent".

- [ ] **Step 2: Create BalanceWidget**

```swift
// ChipInWidget/BalanceWidget.swift
import WidgetKit
import SwiftUI

struct BalanceEntry: TimelineEntry {
    let date: Date
    let balance: Decimal
    let isOwed: Bool
}

struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: .now, balance: 240.00, isOwed: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) {
        completion(BalanceEntry(date: .now, balance: 240.00, isOwed: true))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        // Fetch from shared UserDefaults (app group)
        let defaults = UserDefaults(suiteName: "group.com.yourname.chipin")
        let balance = Decimal(defaults?.double(forKey: "netBalance") ?? 0)
        let entry = BalanceEntry(date: .now, balance: abs(balance), isOwed: balance >= 0)
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900)))
        completion(timeline)
    }
}

struct BalanceWidgetView: View {
    let entry: BalanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Chip In").font(.caption2).foregroundStyle(.secondary)
            Text(entry.isOwed ? "Owed to you" : "You owe")
                .font(.caption).foregroundStyle(.secondary)
            Text(entry.balance, format: .currency(code: "CAD"))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(entry.isOwed ? Color(hex: "#10B981") : Color(hex: "#F87171"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .background(Color(hex: "#1C1C1E"))
        .containerBackground(Color(hex: "#0A0A0A"), for: .widget)
    }
}

@main
struct ChipInWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BalanceWidget", provider: BalanceProvider()) { entry in
            BalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Chip In Balance")
        .description("See your current balance at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
```

- [ ] **Step 3: Add App Group to both targets**

Xcode → ChipIn target → Signing & Capabilities → + Capability → App Groups → add `group.com.yourname.chipin`. Repeat for ChipInWidget target.

- [ ] **Step 4: Write balance to shared UserDefaults in HomeViewModel.load**

```swift
// Add to HomeViewModel.load after computing netBalance:
let defaults = UserDefaults(suiteName: "group.com.yourname.chipin")
defaults?.set(NSDecimalNumber(decimal: netBalance).doubleValue, forKey: "netBalance")
WidgetCenter.shared.reloadAllTimelines()
```

Add `import WidgetKit` to HomeViewModel.swift.

- [ ] **Step 5: Build widget and verify on simulator**

- [ ] **Step 6: Commit**

```bash
git add ChipInWidget/
git commit -m "feat: add WidgetKit balance widget for Home Screen and Lock Screen"
```

---

### Task 15: Offline Sync with SwiftData + Supabase Realtime

**Files:**
- Modify: `ChipIn/Core/SyncManager.swift`
- Modify: `ChipInApp.swift`

- [ ] **Step 1: Create SyncManager for Realtime**

```swift
// ChipIn/Core/SyncManager.swift
import SwiftUI
import Supabase

@MainActor
@Observable
class SyncManager {
    var isConnected = false

    func startListening(groupIds: [UUID], onUpdate: @escaping () async -> Void) async {
        let channel = supabase.channel("group-updates")

        channel.on(.postgresChanges, filter: .init(event: .all, schema: "public", table: "expenses")) { _ in
            Task { await onUpdate() }
        }
        channel.on(.postgresChanges, filter: .init(event: .all, schema: "public", table: "expense_splits")) { _ in
            Task { await onUpdate() }
        }
        channel.on(.postgresChanges, filter: .init(event: .all, schema: "public", table: "settlements")) { _ in
            Task { await onUpdate() }
        }

        await channel.subscribe()
        isConnected = true
    }
}
```

- [ ] **Step 2: Wire SyncManager in ContentView**

```swift
// In ContentView.swift, add:
@State private var sync = SyncManager()
@Environment(AuthManager.self) var auth

// In body, add .task:
.task {
    if let id = auth.currentUser?.id {
        let groups = (try? await GroupService().fetchGroups(for: id)) ?? []
        await sync.startListening(groupIds: groups.map(\.id)) {
            // Trigger refresh in HomeViewModel — pass via environment or notification
            NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
        }
    }
}
```

```swift
// Add to a new file: ChipIn/Core/Notifications.swift
import Foundation
extension Notification.Name {
    static let dataDidUpdate = Notification.Name("dataDidUpdate")
}
```

- [ ] **Step 3: Commit**

```bash
git add ChipIn/Core/SyncManager.swift ChipIn/Core/Notifications.swift
git commit -m "feat: add Supabase Realtime listener for live group updates"
```

---

## Phase 6: Final Polish

### Task 16: Push Notifications

**Files:**
- Modify: `ChipIn/Core/NotificationManager.swift`
- Modify: `ChipInApp.swift`

- [ ] **Step 1: Create NotificationManager**

```swift
// ChipIn/Core/NotificationManager.swift
import UserNotifications
import UIKit

@MainActor
class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { await registerForAPNs() }
        return granted
    }

    private func registerForAPNs() async {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
```

- [ ] **Step 2: Register APNs token with Supabase**

In `AppDelegate` or Scene lifecycle, after receiving APNs token:
```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Task {
        try? await supabase.auth.updateUser(attributes: .init(data: [
            "apns_token": deviceToken.map { String(format: "%02x", $0) }.joined()
        ]))
    }
}
```

- [ ] **Step 3: Request permission on first launch**

```swift
// In AuthManager.initialize(), after successful auth:
_ = await NotificationManager.shared.requestPermission()
```

- [ ] **Step 4: Commit**

```bash
git add ChipIn/Core/NotificationManager.swift
git commit -m "feat: add push notification registration"
```

---

### Task 17: Final Build + Device Install

- [ ] **Step 1: Clean and build for device**

Connect iPhone via USB. In Xcode, select your device as the build target. Product → Build (⌘B).

Fix any remaining compiler errors.

- [ ] **Step 2: Set signing to your personal Apple ID**

Xcode → ChipIn target → Signing & Capabilities → Team → select your personal Apple ID (free). Xcode will auto-create a provisioning profile.

- [ ] **Step 3: Install on device**

Product → Run (⌘R) with device selected. App installs and launches.

On device, go to Settings → General → VPN & Device Management → Trust your developer certificate.

- [ ] **Step 4: Smoke test core flows**

- Sign in with Apple → profile created
- Create a group → members invited
- Add an expense → splits calculated correctly
- Scan a receipt → items parsed, tax distributed
- Settle up → bank app opens, amount on clipboard
- Widgets show on Home Screen

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: Chip In v1.0 — full iOS expense splitting app"
```

---

## Summary

| Phase | Tasks | Can Parallelize |
|---|---|---|
| 1 | Project Setup, Schema, Models, Auth | Sequential |
| 2 | Navigation, Home, Groups | Partial parallel |
| 3 | Add Expense, Settle Up | Parallel after Phase 2 |
| 4 | Receipt Scanning | After Phase 3 |
| 5 | Sounds, Insights, Profile, Widgets | All parallel |
| 6 | Realtime Sync, Push Notifs, Device Install | Sequential |
