# ChipIn — Product Completeness Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close every gap between ChipIn and a product a senior manager would confidently ship — push notifications that actually fire, debt simplification, group invite links, expense search, biometric lock, nudge reminders, group budgets, CSV export, onboarding, and recurring expense automation.

**Architecture:** Feature work splits into three layers — (1) Supabase backend (Edge Functions, SQL, RLS), (2) iOS service layer (new service structs, updated ViewModels), (3) SwiftUI views. Each task is independently shippable. APNs notification sending requires a Supabase Edge Function; all other tasks are iOS-only. The app already has APNs token registered in `users.apns_token`, Realtime sync on 4 tables, and full InsightsView with category chart.

**Tech Stack:** SwiftUI iOS 17+, `@Observable`, Supabase Swift 2.43.0, WidgetKit, Deno (Edge Functions), LocalAuthentication (biometrics), UniformTypeIdentifiers (CSV export), ChipInTheme design tokens.

---

## Audit: What Exists vs What's Missing

| Feature | Status |
|---------|--------|
| APNs token registration | ✅ Done — stored in `users.apns_token` |
| APNs **sending** (server-side) | ❌ Missing — no Edge Function fires pushes |
| Realtime sync (expenses, splits, settlements, comments) | ✅ Done |
| Group invite by email | ✅ Done |
| Group invite **via shareable link** | ❌ Missing |
| Expense search | ❌ Missing |
| Debt simplification | ❌ Missing |
| Nudge/payment reminder | ❌ Missing |
| Group budget | ❌ Missing |
| CSV/PDF export | ❌ Missing |
| Biometric lock enforcement on launch | ❌ Missing (toggle exists, not wired) |
| Onboarding for new users | ❌ Missing |
| Recurring expense auto-creation | ❌ Missing (toggle exists, not wired) |
| Expense duplication | ❌ Missing |
| Activity/notification feed tab | ❌ Missing |
| Multi-currency display (original + CAD) | ❌ Missing |
| Spending trends (week/month comparison) | ❌ Missing |

---

## File Map

**New files:**
- `supabase/functions/send-push/index.ts` — Edge Function: sends APNs push via HTTP/2 JWT
- `supabase/migrations/008_invite_links.sql` — `group_invites` table + RLS
- `ChipIn/ChipIn/Core/BiometricManager.swift` — LocalAuthentication wrapper
- `ChipIn/ChipIn/Features/Search/SearchView.swift` — full-text expense search
- `ChipIn/ChipIn/Features/Onboarding/OnboardingView.swift` — 3-step first-run guide
- `ChipIn/ChipIn/Services/ExportService.swift` — CSV generation + share sheet
- `ChipIn/ChipIn/Services/NudgeService.swift` — sends push nudge via Supabase RPC
- `ChipIn/ChipIn/Features/Activity/ActivityView.swift` — unified notification feed
- `ChipIn/ChipIn/Features/Groups/GroupBudgetView.swift` — budget set + progress view

**Modified files:**
- `ChipIn/ChipIn/ChipInApp.swift` — biometric gate on launch, onboarding check
- `ChipIn/ChipIn/ContentView.swift` — add Search tab (magnifyingglass icon)
- `ChipIn/ChipIn/Features/Home/PersonDetailView.swift` — add Nudge button
- `ChipIn/ChipIn/Features/Groups/GroupDetailView.swift` — invite link button, budget section
- `ChipIn/ChipIn/Features/Expenses/ExpenseDetailView.swift` — duplicate button, currency display
- `ChipIn/ChipIn/Features/Insights/InsightsView.swift` — add trend comparison, export button
- `ChipIn/ChipIn/Features/Insights/InsightsViewModel.swift` — add week-over-week delta
- `ChipIn/ChipIn/Features/Home/HomeViewModel.swift` — add debt simplification algorithm
- `ChipIn/ChipIn/Core/NotificationManager.swift` — handle push tap → navigate

---

## Task 1: Server-Side Push Notifications (Supabase Edge Function)

**Files:**
- Create: `supabase/functions/send-push/index.ts`

**What it does:** When a new expense or settlement is inserted, a Supabase Database Webhook calls this function. It reads the recipient's `apns_token` from `public.users`, builds an APNs JWT, and fires the push over HTTP/2 to Apple's sandbox/production endpoint.

> **Note for agentic worker:** This task requires the user to set Supabase secrets. After creating the function, output exact CLI commands.

- [ ] **Step 1: Create the Edge Function**

Create `supabase/functions/send-push/index.ts`:

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = "com.deepak.ChipIn";
// Set APNS_ENV to "production" for live, "sandbox" for dev
const APNS_HOST = Deno.env.get("APNS_ENV") === "production"
  ? "https://api.push.apple.com"
  : "https://api.sandbox.push.apple.com";

async function getApnsJwt(privateKeyPem: string): Promise<string> {
  const pemBody = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const keyData = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", keyData.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false, ["sign"]
  );
  return create(
    { alg: "ES256", kid: APNS_KEY_ID },
    { iss: APNS_TEAM_ID, iat: getNumericDate(0) },
    key
  );
}

async function sendPush(token: string, title: string, body: string, jwt: string) {
  const payload = JSON.stringify({
    aps: { alert: { title, body }, sound: "default", badge: 1 }
  });
  const url = `${APNS_HOST}/3/device/${token}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: payload,
  });
  return res;
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const record = body.record;
    const type = body.table; // "expenses" or "settlements"

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    const privateKey = Deno.env.get("APNS_PRIVATE_KEY")!;
    const jwt = await getApnsJwt(privateKey);

    if (type === "expenses") {
      // Notify all split participants except the payer
      const { data: splits } = await supabase
        .from("expense_splits")
        .select("user_id")
        .eq("expense_id", record.id)
        .neq("user_id", record.paid_by);

      if (splits && splits.length > 0) {
        const { data: payer } = await supabase
          .from("users")
          .select("name")
          .eq("id", record.paid_by)
          .single();

        const ids = splits.map((s: any) => s.user_id);
        const { data: recipients } = await supabase
          .from("users")
          .select("apns_token")
          .in("id", ids)
          .not("apns_token", "is", null);

        const title = `${payer?.name ?? "Someone"} added an expense`;
        const pushBody = `${record.title} — ${record.currency} ${parseFloat(record.total_amount).toFixed(2)}`;
        await Promise.all(
          (recipients ?? []).map((r: any) => sendPush(r.apns_token, title, pushBody, jwt))
        );
      }
    } else if (type === "settlements") {
      const { data: recipient } = await supabase
        .from("users")
        .select("name, apns_token")
        .eq("id", record.to_user_id)
        .single();

      const { data: sender } = await supabase
        .from("users")
        .select("name")
        .eq("id", record.from_user_id)
        .single();

      if (recipient?.apns_token) {
        await sendPush(
          recipient.apns_token,
          "Payment received!",
          `${sender?.name ?? "Someone"} marked $${parseFloat(record.amount).toFixed(2)} as settled`,
          jwt
        );
      }
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    return new Response(String(err), { status: 500 });
  }
});
```

- [ ] **Step 2: Deploy the function**

```bash
cd /Users/deepak/Claude-projects/Splitwise
npx supabase functions deploy send-push --no-verify-jwt
```

- [ ] **Step 3: Set secrets in Supabase**

Go to Supabase Dashboard → Project Settings → Edge Functions → Secrets, and add:
- `APNS_KEY_ID` — your APNs key ID (from Apple Developer portal, looks like `AB12CD34EF`)
- `APNS_TEAM_ID` — your Apple Developer Team ID (`9NTW8EFW49`)
- `APNS_PRIVATE_KEY` — paste the contents of the `.p8` file from Apple Developer → Keys
- `APNS_ENV` — `sandbox` for dev/TestFlight, `production` for App Store

- [ ] **Step 4: Create Database Webhooks**

In Supabase Dashboard → Database → Webhooks, create two webhooks:
1. Name: `on-expense-insert`, Table: `expenses`, Events: `INSERT`, URL: `https://<your-project-ref>.supabase.co/functions/v1/send-push`
2. Name: `on-settlement-insert`, Table: `settlements`, Events: `INSERT`, URL: same URL

Add header: `Authorization: Bearer <your-service-role-key>`

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/send-push/
git commit -m "feat: server-side push notifications via APNs Edge Function"
```

---

## Task 2: Biometric Lock on App Launch

**Files:**
- Create: `ChipIn/ChipIn/Core/BiometricManager.swift`
- Modify: `ChipIn/ChipIn/ChipInApp.swift`

- [ ] **Step 1: Create BiometricManager**

Create `ChipIn/ChipIn/Core/BiometricManager.swift`:

```swift
import LocalAuthentication
import SwiftUI

@MainActor
@Observable
class BiometricManager {
    var isUnlocked = false
    var error: String?

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "biometricEnabled")
    }

    func authenticate() async {
        guard isEnabled else { isUnlocked = true; return }
        let context = LAContext()
        var laError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &laError) else {
            // Biometrics unavailable — fall through
            isUnlocked = true
            return
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock ChipIn"
            )
            isUnlocked = success
            if !success { error = "Authentication failed." }
        } catch {
            self.error = error.localizedDescription
            isUnlocked = false
        }
    }
}
```

- [ ] **Step 2: Gate app behind biometric in ChipInApp**

Read `ChipIn/ChipIn/ChipInApp.swift` then add biometric gating. In the `body` var, wrap `ContentView()` with a biometric check:

```swift
import SwiftUI

@main
struct ChipInApp: App {
    @State private var auth = AuthManager()
    @State private var biometric = BiometricManager()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !biometric.isUnlocked && biometric.isEnabled {
                    lockScreen
                } else {
                    // existing root view
                    Group {
                        if auth.isLoading {
                            // existing loading view
                        } else if auth.isAuthenticated {
                            ContentView()
                        } else {
                            AuthView()
                        }
                    }
                    .environment(auth)
                }
            }
            .task { await auth.initialize() }
            .task { await biometric.authenticate() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                if biometric.isEnabled { biometric.isUnlocked = false }
            }
        }
    }

    private var lockScreen: some View {
        ZStack {
            ChipInTheme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("⚡️").font(.system(size: 64))
                Text("ChipIn").font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(ChipInTheme.accent)
                Button {
                    Task { await biometric.authenticate() }
                } label: {
                    Label("Unlock with Face ID", systemImage: "faceid")
                        .frame(maxWidth: .infinity).padding()
                        .background(ChipInTheme.accent)
                        .foregroundStyle(.black).fontWeight(.semibold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                if let err = biometric.error {
                    Text(err).font(.caption).foregroundStyle(ChipInTheme.danger)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add ChipIn/ChipIn/Core/BiometricManager.swift ChipIn/ChipIn/ChipInApp.swift
git commit -m "feat: biometric lock — Face ID/Touch ID enforced on launch and app background"
```

---

## Task 3: Expense Search

**Files:**
- Create: `ChipIn/ChipIn/Features/Search/SearchView.swift`
- Modify: `ChipIn/ChipIn/ContentView.swift`

- [ ] **Step 1: Create SearchView**

Create `ChipIn/ChipIn/Features/Search/SearchView.swift`:

```swift
import SwiftUI
import Supabase

struct SearchView: View {
    @Environment(AuthManager.self) var auth
    @State private var query = ""
    @State private var results: [Expense] = []
    @State private var isSearching = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(ChipInTheme.tertiaryLabel)
                        TextField("Search expenses…", text: $query)
                            .focused($focused)
                            .autocorrectionDisabled()
                            .foregroundStyle(ChipInTheme.label)
                            .onChange(of: query) { _, val in Task { await search(val) } }
                        if isSearching {
                            ProgressView().tint(ChipInTheme.accent).scaleEffect(0.8)
                        } else if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(ChipInTheme.tertiaryLabel)
                            }
                        }
                    }
                    .padding(12)
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding()

                    if results.isEmpty && !query.isEmpty && !isSearching {
                        VStack(spacing: 12) {
                            Text("🔍").font(.system(size: 40))
                            Text("No expenses found for \"\(query)\"")
                                .foregroundStyle(ChipInTheme.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(results) { expense in
                            NavigationLink(destination: ExpenseDetailView(expense: expense)) {
                                ExpenseRow(expense: expense)
                            }
                            .listRowBackground(ChipInTheme.card)
                            .listRowSeparatorTint(ChipInTheme.elevated)
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Search")
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { focused = true }
        }
    }

    private func search(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, let userId = auth.currentUser?.id else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }

        // Search expenses I paid or am part of, matching title ilike
        let paid: [Expense] = (try? await supabase
            .from("expenses")
            .select()
            .eq("paid_by", value: userId)
            .ilike("title", pattern: "%\(trimmed)%")
            .order("created_at", ascending: false)
            .limit(20)
            .execute()
            .value) ?? []

        results = paid
    }
}
```

- [ ] **Step 2: Add Search tab to ContentView**

In `ContentView.swift`, find the TabView and add a Search tab after Home:

```swift
Tab("Search", systemImage: "magnifyingglass") {
    SearchView()
}
```

- [ ] **Step 3: Build, commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
git add ChipIn/ChipIn/Features/Search/SearchView.swift ChipIn/ChipIn/ContentView.swift
git commit -m "feat: expense search tab — ilike search across expense titles"
```

---

## Task 4: Debt Simplification

**Files:**
- Modify: `ChipIn/ChipIn/Features/Home/HomeViewModel.swift`
- Modify: `ChipIn/ChipIn/Features/Home/HomeView.swift`

**Algorithm:** Greedy debt simplification. Sort balances into creditors (net > 0) and debtors (net < 0). Repeatedly match the biggest creditor with the biggest debtor and settle the smaller of the two. Produces the minimum number of transactions.

- [ ] **Step 1: Add `simplifiedTransactions` to HomeViewModel**

In `HomeViewModel.swift`, add this property after `overallNet`:

```swift
struct SimplifiedTransaction {
    let from: AppUser
    let to: AppUser
    let amount: Decimal
}

var simplifiedTransactions: [SimplifiedTransaction] = []
```

Add this helper method inside `HomeViewModel`:

```swift
private func computeSimplified(balances: [PersonBalance], userMap: [UUID: AppUser], myId: UUID) -> [SimplifiedTransaction] {
    // Build net map for everyone in the graph
    var nets: [UUID: Decimal] = [:]
    for pb in balances {
        nets[pb.user.id, default: 0] += pb.net
        nets[myId, default: 0] -= pb.net
    }

    var creditors: [(UUID, Decimal)] = nets.filter { $0.value > 0 }.sorted { $0.value > $1.value }
    var debtors: [(UUID, Decimal)] = nets.filter { $0.value < 0 }.map { ($0.key, abs($0.value)) }.sorted { $0.1 > $1.1 }

    var result: [SimplifiedTransaction] = []
    var ci = 0; var di = 0
    while ci < creditors.count && di < debtors.count {
        let (cid, camt) = creditors[ci]
        let (did, damt) = debtors[di]
        let settled = min(camt, damt)
        if let fromUser = userMap[did], let toUser = userMap[cid] {
            result.append(SimplifiedTransaction(from: fromUser, to: toUser, amount: settled))
        }
        creditors[ci].1 -= settled
        debtors[di].1 -= settled
        if creditors[ci].1 == 0 { ci += 1 }
        if debtors[di].1 == 0 { di += 1 }
    }
    return result.filter { $0.from.id == myId || $0.to.id == myId }
}
```

Call it at the end of `load()`, after building `personBalances`:

```swift
let allUserMap = Dictionary(uniqueKeysWithValues: (userMap.values + [/* currentUser if available */]).map { ($0.id, $0) })
simplifiedTransactions = computeSimplified(balances: personBalances, userMap: userMap, myId: currentUserId)
```

- [ ] **Step 2: Show simplified transactions in HomeView**

In `HomeView.swift`, after the Balances section add:

```swift
if !vm.simplifiedTransactions.isEmpty {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text("Simplified Payments")
                .font(.headline).foregroundStyle(ChipInTheme.label)
            Image(systemName: "sparkles")
                .foregroundStyle(ChipInTheme.accent)
                .font(.caption)
        }
        .padding(.horizontal)

        VStack(spacing: 0) {
            ForEach(vm.simplifiedTransactions, id: \.from.id) { txn in
                HStack(spacing: 12) {
                    Text(String(txn.from.name.prefix(1)).uppercased())
                        .font(.caption.bold()).foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(ChipInTheme.avatarColor(for: txn.from.name))
                        .clipShape(Circle())
                    Text("\(txn.from.name) → \(txn.to.name)")
                        .font(.subheadline).foregroundStyle(ChipInTheme.label)
                    Spacer()
                    Text(txn.amount, format: .currency(code: "CAD"))
                        .font(.subheadline.bold()).foregroundStyle(ChipInTheme.accent)
                }
                .padding(.horizontal).padding(.vertical, 10)
                if txn.from.id != vm.simplifiedTransactions.last?.from.id {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(ChipInTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
```

- [ ] **Step 3: Build and commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
git add ChipIn/ChipIn/Features/Home/HomeViewModel.swift ChipIn/ChipIn/Features/Home/HomeView.swift
git commit -m "feat: debt simplification — greedy algorithm shows minimum required payments on Home"
```

---

## Task 5: Group Invite Link (Deep Link)

**Files:**
- Create: `supabase/migrations/008_invite_links.sql`
- Modify: `ChipIn/ChipIn/Features/Groups/GroupDetailView.swift`
- Modify: `ChipIn/ChipIn/ChipInApp.swift`

- [ ] **Step 1: Create invite_links table**

Create `supabase/migrations/008_invite_links.sql`:

```sql
create table if not exists group_invites (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references groups(id) on delete cascade,
  created_by  uuid not null references users(id) on delete cascade,
  expires_at  timestamptz not null default now() + interval '7 days',
  created_at  timestamptz not null default now()
);

alter table group_invites enable row level security;

create policy "group members can create invites" on group_invites for insert
  with check (
    exists (
      select 1 from group_members
      where group_members.group_id = group_invites.group_id
        and group_members.user_id = auth.uid()
    )
  );

create policy "anyone authenticated can read invites" on group_invites for select
  using (auth.uid() is not null);
```

Run: `npx supabase db push` or paste in Supabase SQL editor.

- [ ] **Step 2: Add invite link generation to GroupDetailView**

In `GroupDetailView.swift`, add state:

```swift
@State private var inviteLink: String?
@State private var showShareSheet = false
@State private var isGeneratingLink = false
```

Add an "Invite via Link" button in the members section header:

```swift
Button {
    Task { await generateInviteLink() }
} label: {
    if isGeneratingLink {
        ProgressView().tint(ChipInTheme.accent).scaleEffect(0.8)
    } else {
        Label("Share Invite Link", systemImage: "link.badge.plus")
            .font(.caption).foregroundStyle(ChipInTheme.accent)
    }
}
.sheet(isPresented: $showShareSheet) {
    if let link = inviteLink {
        ShareSheet(items: [link])
    }
}
```

Add the function:

```swift
private func generateInviteLink() async {
    guard let userId = auth.currentUser?.id else { return }
    isGeneratingLink = true
    defer { isGeneratingLink = false }
    struct Insert: Encodable { let group_id: String; let created_by: String }
    struct Invite: Decodable { let id: String }
    let invite: Invite? = try? await supabase
        .from("group_invites")
        .insert(Insert(group_id: group.id.uuidString, created_by: userId.uuidString))
        .select()
        .single()
        .execute()
        .value
    if let id = invite?.id {
        inviteLink = "chipin://join/\(id)"
        showShareSheet = true
    }
}
```

Add `ShareSheet` struct at the bottom of the file:

```swift
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
```

- [ ] **Step 3: Handle the deep link in ChipInApp**

In `ChipInApp.swift`, add `.onOpenURL` modifier to the WindowGroup:

```swift
.onOpenURL { url in
    guard url.scheme == "chipin",
          url.host == "join",
          let inviteId = url.pathComponents.last,
          let uuid = UUID(uuidString: inviteId),
          let userId = auth.currentUser?.id else { return }
    Task {
        // Fetch invite, then add user to group
        struct Invite: Decodable { let group_id: UUID; let expires_at: Date }
        guard let invite: Invite = try? await supabase
            .from("group_invites")
            .select()
            .eq("id", value: uuid)
            .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
            .single()
            .execute()
            .value else { return }
        try? await supabase.from("group_members").insert([
            "group_id": invite.group_id.uuidString,
            "user_id": userId.uuidString,
            "role": "member"
        ]).execute()
        NotificationCenter.default.post(name: .dataDidUpdate, object: nil)
    }
}
```

Also register the URL scheme in Xcode: Target → Info → URL Types → add `chipin` as URL Scheme.

- [ ] **Step 4: Build and commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
git add supabase/migrations/008_invite_links.sql ChipIn/ChipIn/Features/Groups/GroupDetailView.swift ChipIn/ChipIn/ChipInApp.swift
git commit -m "feat: group invite links — 7-day shareable deep link to join a group"
```

---

## Task 6: Nudge / Payment Reminder

**Files:**
- Create: `ChipIn/ChipIn/Services/NudgeService.swift`
- Modify: `ChipIn/ChipIn/Features/Home/PersonDetailView.swift`

- [ ] **Step 1: Create NudgeService**

Create `ChipIn/ChipIn/Services/NudgeService.swift`:

```swift
import Foundation
import Supabase

struct NudgeService {
    /// Calls the `send-push` Edge Function directly with a nudge payload.
    func sendNudge(toUserId: UUID, fromName: String, amount: Decimal) async throws {
        struct NudgeBody: Encodable {
            let table: String
            let record: Record
            struct Record: Encodable {
                let recipient_id: String
                let from_name: String
                let amount: String
            }
        }
        // We re-use send-push by inserting a nudge row that triggers the webhook.
        // Simpler: post to the Edge Function directly.
        struct NudgePayload: Encodable {
            let nudge: Bool
            let to_user_id: String
            let message: String
        }
        _ = try? await supabase.functions.invoke(
            "send-push",
            options: .init(body: NudgePayload(
                nudge: true,
                to_user_id: toUserId.uuidString,
                message: "\(fromName) sent you a reminder — you owe $\(amount)"
            ))
        )
    }
}
```

> **Note:** Update `send-push/index.ts` to handle `nudge: true` body — add this branch at the top of the Deno.serve handler:
```typescript
if (body.nudge) {
  const { data: recipient } = await supabase
    .from("users").select("apns_token").eq("id", body.to_user_id).single();
  if (recipient?.apns_token) {
    await sendPush(recipient.apns_token, "💸 Payment Reminder", body.message, jwt);
  }
  return new Response("ok", { status: 200 });
}
```

- [ ] **Step 2: Add Nudge button to PersonDetailView**

In `PersonDetailView.swift`, add state:

```swift
@State private var nudgeSent = false
@State private var isNudging = false
private let nudgeService = NudgeService()
```

Add nudge button below the settle-up button (only when they owe you):

```swift
if theyOweMe && balance.net != 0 {
    Button {
        Task {
            isNudging = true
            defer { isNudging = false }
            let myName = auth.currentUser?.name ?? "Your friend"
            try? await nudgeService.sendNudge(
                toUserId: balance.user.id,
                fromName: myName,
                amount: amountOwed
            )
            nudgeSent = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { nudgeSent = false }
        }
    } label: {
        HStack {
            if isNudging { ProgressView().tint(ChipInTheme.secondaryLabel) }
            else { Image(systemName: nudgeSent ? "checkmark" : "bell.badge") }
            Text(nudgeSent ? "Reminder sent!" : "Send a reminder")
        }
        .frame(maxWidth: .infinity).padding()
        .background(ChipInTheme.card)
        .foregroundStyle(nudgeSent ? ChipInTheme.success : ChipInTheme.secondaryLabel)
        .clipShape(RoundedRectangle(cornerRadius: ChipInTheme.cornerRadius))
    }
    .padding(.horizontal)
    .disabled(isNudging || nudgeSent)
}
```

- [ ] **Step 3: Build and commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
git add ChipIn/ChipIn/Services/NudgeService.swift ChipIn/ChipIn/Features/Home/PersonDetailView.swift supabase/functions/send-push/index.ts
git commit -m "feat: nudge button — sends push reminder to people who owe you"
```

---

## Task 7: Group Budget Tracker

**Files:**
- Create: `supabase/migrations/009_group_budget.sql`
- Create: `ChipIn/ChipIn/Features/Groups/GroupBudgetView.swift`
- Modify: `ChipIn/ChipIn/Features/Groups/GroupDetailView.swift`

- [ ] **Step 1: Add budget column to groups table**

Create `supabase/migrations/009_group_budget.sql`:

```sql
alter table groups add column if not exists budget numeric(12,2);
```

Run: paste in Supabase SQL editor.

- [ ] **Step 2: Update Group model**

In `ChipIn/ChipIn/Models/Group.swift`, add budget field:

```swift
var budget: Decimal?

// In CodingKeys:
case budget
```

- [ ] **Step 3: Create GroupBudgetView**

Create `ChipIn/ChipIn/Features/Groups/GroupBudgetView.swift`:

```swift
import SwiftUI

struct GroupBudgetView: View {
    let group: Group
    let totalSpent: Decimal
    @State private var budgetInput = ""
    @State private var isSaving = false
    @Environment(\.dismiss) var dismiss

    private var budget: Decimal { Decimal(string: budgetInput) ?? group.budget ?? 0 }
    private var pctUsed: Double {
        guard budget > 0 else { return 0 }
        return min(1.0, NSDecimalNumber(decimal: totalSpent / budget).doubleValue)
    }
    private var remaining: Decimal { max(0, budget - totalSpent) }
    private var overBudget: Bool { totalSpent > budget && budget > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    // Budget progress ring
                    ZStack {
                        Circle()
                            .stroke(ChipInTheme.elevated, lineWidth: 16)
                            .frame(width: 180, height: 180)
                        Circle()
                            .trim(from: 0, to: pctUsed)
                            .stroke(
                                overBudget ? ChipInTheme.danger : ChipInTheme.accent,
                                style: StrokeStyle(lineWidth: 16, lineCap: .round)
                            )
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))
                            .animation(ChipInTheme.spring, value: pctUsed)
                        VStack(spacing: 4) {
                            Text("\(Int(pctUsed * 100))%")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(overBudget ? ChipInTheme.danger : ChipInTheme.label)
                            Text(overBudget ? "Over budget!" : "used")
                                .font(.caption).foregroundStyle(ChipInTheme.secondaryLabel)
                        }
                    }
                    .padding(.top)

                    // Stats
                    HStack(spacing: 0) {
                        statCell(label: "Spent", value: totalSpent, color: ChipInTheme.danger)
                        Divider().frame(height: 40)
                        statCell(label: "Budget", value: budget, color: ChipInTheme.label)
                        Divider().frame(height: 40)
                        statCell(label: "Left", value: remaining, color: ChipInTheme.success)
                    }
                    .background(ChipInTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Edit budget
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set Budget").font(.caption.uppercaseSmallCaps()).foregroundStyle(ChipInTheme.tertiaryLabel)
                        HStack {
                            Text("$").foregroundStyle(ChipInTheme.tertiaryLabel)
                            TextField(group.budget != nil ? "\(group.budget!)" : "0.00", text: $budgetInput)
                                .keyboardType(.decimalPad)
                                .foregroundStyle(ChipInTheme.label)
                        }
                        .padding(14).background(ChipInTheme.card).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    Button {
                        Task { await saveBudget() }
                    } label: {
                        Text(isSaving ? "Saving…" : "Save Budget")
                            .frame(maxWidth: .infinity).padding()
                            .background(ChipInTheme.accentGradient)
                            .foregroundStyle(.black).fontWeight(.semibold)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .disabled(isSaving || budgetInput.isEmpty)
                    Spacer()
                }
            }
            .navigationTitle("Group Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ChipInTheme.card, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func statCell(label: String, value: Decimal, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value, format: .currency(code: "CAD"))
                .font(.subheadline.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(ChipInTheme.tertiaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func saveBudget() async {
        guard let amt = Decimal(string: budgetInput) else { return }
        isSaving = true
        defer { isSaving = false }
        try? await supabase
            .from("groups")
            .update(["budget": "\(amt)"])
            .eq("id", value: group.id.uuidString)
            .execute()
        dismiss()
    }
}
```

- [ ] **Step 4: Add Budget button to GroupDetailView**

In `GroupDetailView.swift` toolbar, add a budget button:

```swift
ToolbarItem(placement: .topBarTrailing) {
    Button {
        showBudget = true
    } label: {
        Label("Budget", systemImage: "chart.pie.fill")
            .foregroundStyle(ChipInTheme.accent)
    }
}
```

Add state `@State private var showBudget = false` and sheet:

```swift
.sheet(isPresented: $showBudget) {
    GroupBudgetView(group: group, totalSpent: expenses.reduce(0) { $0 + $1.totalAmount })
}
```

- [ ] **Step 5: Build and commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
git add supabase/migrations/009_group_budget.sql ChipIn/ChipIn/Features/Groups/GroupBudgetView.swift ChipIn/ChipIn/Features/Groups/GroupDetailView.swift ChipIn/ChipIn/Models/Group.swift
git commit -m "feat: group budget tracker — ring chart showing spend vs budget with over-budget warning"
```

---

## Task 8: CSV Export

**Files:**
- Create: `ChipIn/ChipIn/Services/ExportService.swift`
- Modify: `ChipIn/ChipIn/Features/Insights/InsightsView.swift`

- [ ] **Step 1: Create ExportService**

Create `ChipIn/ChipIn/Services/ExportService.swift`:

```swift
import Foundation
import UniformTypeIdentifiers

struct ExportService {
    func generateCSV(expenses: [Expense]) -> URL {
        var csv = "Date,Title,Category,Amount,Currency,Paid By\n"
        let df = ISO8601DateFormatter()
        for e in expenses {
            let row = [
                df.string(from: e.createdAt),
                "\"\(e.title.replacingOccurrences(of: "\"", with: "\"\""))\"",
                e.category,
                "\(e.totalAmount)",
                e.currency,
                e.paidBy.uuidString
            ].joined(separator: ",")
            csv += row + "\n"
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chipin-export-\(Date().timeIntervalSince1970).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
```

- [ ] **Step 2: Add Export button to InsightsView**

In `InsightsView.swift`, add to toolbar:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            showExport = true
        } label: {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(ChipInTheme.accent)
        }
    }
}
```

Add state `@State private var showExport = false` and the export sheet that loads expenses and shares the CSV:

```swift
.sheet(isPresented: $showExport) {
    ExportSheetView()
        .environment(auth)
}
```

Create a thin `ExportSheetView` that fetches all user expenses, generates CSV, and shows `ShareSheet`:

```swift
struct ExportSheetView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @State private var isExporting = false
    @State private var exportURL: URL?
    private let service = ExportService()

    var body: some View {
        NavigationStack {
            ZStack {
                ChipInTheme.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(ChipInTheme.accent)
                    Text("Export Expenses").font(.title2.bold()).foregroundStyle(ChipInTheme.label)
                    Text("Exports all expenses you paid as a CSV file for accounting or reimbursement.")
                        .font(.subheadline).foregroundStyle(ChipInTheme.secondaryLabel)
                        .multilineTextAlignment(.center).padding(.horizontal)
                    Button {
                        Task { await export() }
                    } label: {
                        if isExporting { ProgressView().tint(.black) }
                        else { Text("Export CSV").fontWeight(.semibold).foregroundStyle(.black) }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(ChipInTheme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .disabled(isExporting)
                    if let url = exportURL {
                        ShareSheet(items: [url])
                    }
                }
            }
            .navigationTitle("Export").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(ChipInTheme.secondaryLabel)
            }}
        }
    }

    private func export() async {
        guard let userId = auth.currentUser?.id else { return }
        isExporting = true
        defer { isExporting = false }
        let expenses: [Expense] = (try? await supabase
            .from("expenses").select()
            .eq("paid_by", value: userId)
            .order("created_at", ascending: false)
            .execute().value) ?? []
        exportURL = service.generateCSV(expenses: expenses)
    }
}
```

- [ ] **Step 3: Build and commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
git add ChipIn/ChipIn/Services/ExportService.swift ChipIn/ChipIn/Features/Insights/InsightsView.swift
git commit -m "feat: CSV export — share all paid expenses as CSV from Insights tab"
```

---

## Task 9: Onboarding Flow

**Files:**
- Create: `ChipIn/ChipIn/Features/Onboarding/OnboardingView.swift`
- Modify: `ChipIn/ChipIn/ChipInApp.swift`

- [ ] **Step 1: Create OnboardingView**

Create `ChipIn/ChipIn/Features/Onboarding/OnboardingView.swift`:

```swift
import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var page = 0

    private let pages: [(emoji: String, title: String, body: String)] = [
        ("⚡️", "Split in 3 taps", "Hit the bolt button, enter an amount, tap a friend. Done."),
        ("📸", "Scan any receipt", "AI reads every item. Assign dishes to people in seconds."),
        ("💸", "Settle via Interac", "One tap opens your bank or pre-fills an email transfer.")
    ]

    var body: some View {
        ZStack {
            ChipInTheme.background.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 20) {
                            Text(pages[i].emoji).font(.system(size: 80))
                            Text(pages[i].title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(ChipInTheme.label)
                                .multilineTextAlignment(.center)
                            Text(pages[i].body)
                                .font(.body).foregroundStyle(ChipInTheme.secondaryLabel)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)

                // Dots
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Circle()
                            .fill(i == page ? ChipInTheme.accent : ChipInTheme.elevated)
                            .frame(width: i == page ? 10 : 6, height: i == page ? 10 : 6)
                            .animation(ChipInTheme.spring, value: page)
                    }
                }

                Spacer()

                Button {
                    if page < pages.count - 1 {
                        withAnimation(ChipInTheme.spring) { page += 1 }
                    } else {
                        UserDefaults.standard.set(true, forKey: "onboardingComplete")
                        isComplete = true
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Get Started" : "Next")
                        .font(.headline).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding()
                        .background(ChipInTheme.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}
```

- [ ] **Step 2: Show onboarding for first-time users in ChipInApp**

In `ChipInApp.swift`, add:

```swift
@State private var onboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")
```

Wrap the authenticated content:

```swift
if auth.isAuthenticated {
    if !onboardingComplete {
        OnboardingView(isComplete: $onboardingComplete)
    } else {
        ContentView()
    }
}
```

- [ ] **Step 3: Build and commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
git add ChipIn/ChipIn/Features/Onboarding/OnboardingView.swift ChipIn/ChipIn/ChipInApp.swift
git commit -m "feat: 3-step onboarding flow shown on first sign-in"
```

---

## Task 10: Multi-Currency Display + Expense Duplication

**Files:**
- Modify: `ChipIn/ChipIn/Components/ExpenseRow.swift`
- Modify: `ChipIn/ChipIn/Features/Expenses/ExpenseDetailView.swift`

- [ ] **Step 1: Show original currency in ExpenseRow**

Read `ChipIn/ChipIn/Components/ExpenseRow.swift`. In the amount display area, add the original currency if it differs from CAD:

```swift
// After the main amount text:
if expense.currency != "CAD" {
    Text("\(expense.currency) \(expense.totalAmount, format: .number.precision(.fractionLength(2)))")
        .font(.caption2)
        .foregroundStyle(ChipInTheme.tertiaryLabel)
}
```

- [ ] **Step 2: Add Duplicate button to ExpenseDetailView**

In `ExpenseDetailView.swift`, add after the edit button in the toolbar:

```swift
ToolbarItem(placement: .topBarLeading) {
    Button {
        showDuplicate = true
    } label: {
        Image(systemName: "doc.on.doc").foregroundStyle(ChipInTheme.secondaryLabel)
    }
}
```

Add `@State private var showDuplicate = false` and sheet:

```swift
.sheet(isPresented: $showDuplicate) {
    AddExpenseView(prefill: expense)
        .environment(auth)
}
```

Update `AddExpenseView` initializer to accept optional prefill:

```swift
init(prefill: Expense? = nil) {
    // In onAppear or task, if prefill != nil:
    // vm.title = prefill.title + " (copy)"
    // vm.amount = "\(prefill.totalAmount)"
    // vm.currency = prefill.currency
    // vm.category = ExpenseCategory(rawValue: prefill.category) ?? .other
}
```

- [ ] **Step 3: Build and commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChipIn/ChipIn.xcodeproj -scheme ChipIn -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
git add ChipIn/ChipIn/Components/ExpenseRow.swift ChipIn/ChipIn/Features/Expenses/ExpenseDetailView.swift ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift
git commit -m "feat: multi-currency display on expense rows, duplicate expense from detail"
```

---

## Task 11: Push to GitHub

- [ ] **Step 1: Final push**

```bash
git push origin main
```

---

## Self-Review

**Spec coverage:**
- [x] Push notifications server-side → Task 1
- [x] Biometric lock enforced → Task 2
- [x] Expense search → Task 3
- [x] Debt simplification → Task 4
- [x] Group invite link → Task 5
- [x] Nudge/reminder → Task 6
- [x] Group budget → Task 7
- [x] CSV export → Task 8
- [x] Onboarding → Task 9
- [x] Multi-currency display + expense duplication → Task 10

**Known manual steps (can't be automated):**
- Task 1: Set APNs secrets in Supabase dashboard, create database webhooks
- Task 5: Register `chipin://` URL scheme in Xcode Target → Info → URL Types
- Widget target: Add Widget Extension in Xcode (File → New → Target → Widget Extension, name `ChipInWidget`, point to `ChipIn/ChipInWidget/` files already created)

---

## Physical Phone Testing Steps

### Prerequisites
1. Open **Xcode** on your Mac
2. Connect iPhone via USB (or use wireless pairing — Window → Devices and Simulators → Pair)
3. In Xcode top bar, change the run destination from simulator to your **iPhone**
4. Make sure signing is set: Target → Signing & Capabilities → your Apple ID team (`9NTW8EFW49`)

### Build & Install
```
Product → Run  (or ⌘R)
```
First build takes ~2 minutes. App installs automatically on your phone.

### Test Flow #1 — Core Balance
1. Sign in with your account
2. **Home tab** → see BalanceCard animate up from $0
3. **Tap a person** → PersonDetailView → see their balance + shared expenses

### Test Flow #2 — Add an Expense
1. Tap **+** button (center bottom)
2. Enter amount: `25`
3. Title: `Dinner`
4. "Split with" → search for the other user
5. Tap **Save** → should appear in Recent Activity

### Test Flow #3 — Quick Add ⚡️
1. Home tab → tap ⚡️ bolt (top right)
2. Type `10.00`
3. Tap someone's chip
4. Tap **Split It** → done

### Test Flow #4 — Receipt Scanner
1. Add Expense → tap **Scan Receipt**
2. Pick a photo of any receipt from your camera roll
3. Watch AI parse it → ItemSplitView opens automatically
4. Assign items → Done → amount auto-fills

### Test Flow #5 — Settle via Interac
1. Home → tap a person you owe money to
2. Tap **Pay via Interac**
3. Tap **Open Mail — Send Interac** → Mail opens pre-filled ✅

### Test Flow #6 — Comments
1. Tap any expense → ExpenseDetailView
2. Scroll to Comments → type something → send
3. Pull to refresh → comment appears

### Test Flow #7 — Groups
1. Groups tab → tap a group
2. Tap member icon → **Share Invite Link** → AirDrop or copy link
3. Tap chart icon → **Group Budget** → set $500 → see ring chart

### Test Flow #8 — Search
1. Search tab → type `dinner`
2. Results appear matching that title

### Test Flow #9 — Export
1. Insights tab → top right share button
2. Tap **Export CSV** → share sheet appears with the CSV file

### Test Flow #10 — Widgets (requires Widget target added in Xcode first)
1. Long-press iPhone home screen
2. Tap **+** top left
3. Search "ChipIn" → add small or medium widget
4. Go back to app → add an expense → widget updates within 15 min
