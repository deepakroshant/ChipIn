# ChipIn UI/UX Improvement Initiative

**Product:** ChipIn — SwiftUI iOS expense-splitting app (Supabase backend)  
**Audience:** Solo developer execution  
**References:** [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) (Typography, Materials, Accessibility, Navigation), Dynamic Type (`@Environment(\.dynamicTypeSize)`, `.dynamicTypeSize`, semantic fonts)

---

## Context (codebase anchors)

| Area | Primary files |
|------|----------------|
| Home title / chrome | `ChipIn/ChipIn/Features/Home/HomeView.swift` — `.navigationTitle("Chip In")`, `.toolbarBackground`, `.toolbarColorScheme(.dark)` |
| Tab bar | `ChipIn/ChipIn/ContentView.swift` — `TabView`, `.toolbarBackground` for `.tabBar`, `.tint` |
| Add Expense form | `ChipIn/ChipIn/Features/AddExpense/AddExpenseView.swift` — default `Form` (light grouped appearance) |
| Split picker | `ChipIn/ChipIn/Features/AddExpense/SplitPickerView.swift` — horizontal `ScrollView` + `HStack` of five options |
| Split logic | `ChipIn/ChipIn/Services/ExpenseService.swift` — `calculateEqualSplits` only; `AddExpenseViewModel.submit` always uses equal splits |
| Friends tab surface | `ChipIn/ChipIn/Features/Groups/FriendsView.swift` — list with no `.task` / empty state |

---

## (A) UI / contrast / accessibility — prioritized by impact

**P0 — Legal/brand risk + daily friction**

1. **Add Expense sheet — text and placeholders on light `Form`**  
   Placeholders (“0.00”, “What’s this for?”) and secondary labels sit on system grouped backgrounds; contrast fails WCAG 2.x AA for normal text (4.5:1) in common combinations.  
   *Direction:* Unify sheet with app chrome **or** use semantic `Color` pairs (label / secondary / tertiary) tested against actual `Form`/`List` backgrounds; avoid fixed orange-on-light without verification. Prefer **semantic fonts** (`.title`, `.body`) over fixed `font(.system(size: 28))` so **Dynamic Type** scales without breaking layout.

2. **Home navigation title “Chip In”**  
   Large title on dark bar can render with insufficient contrast if the title color does not follow the bar’s color scheme.  
   *Direction:* Explicit large-title styling where needed (e.g. `toolbar` + `principal` or `.navigationBarTitleDisplayMode` + verified `foregroundStyle` for title hierarchy), aligned with HIG “Navigation bars” and legibility on dark materials.

3. **Tab bar vs main chrome**  
   `ContentView` sets `toolbarBackground` for tab bar to `#1C1C1E`, but system appearance and material can still read as “light grey” on some OS versions/devices.  
   *Direction:* Apply **`toolbarColorScheme(.dark, for: .tabBar)`** (and verify under iOS 17/18), consider `UITabBarAppearance` bridge only if SwiftUI modifiers prove insufficient — verify on smallest device + Reduce Transparency.

**P1 — Feature discoverability**

4. **Split picker — “Shares” clipped**  
   Horizontal-only layout with five chips does not adapt to narrow width + larger Dynamic Type.  
   *Direction:* Wrapping layout (`LazyVGrid` with adaptive columns), or vertical segmented control pattern, or scroll with **minimum touch targets** (44pt) per HIG.

5. **Home empty state**  
   When `recentActivity` is empty, only `BalanceCard` shows — large void below. Hurts perceived quality and onboarding.  
   *Direction:* Dedicated empty state (copy + primary CTA “Add expense” / link to Groups) — see section (B).

**P2 — Broader pass**

6. **Lists and cards across tabs**  
   Audit `.secondary` on `#1C1C1E` / `#2C2C2E`, chart labels in `InsightsView`, and `ProfileView` rows. Use **Reduce Transparency** and **Increase Contrast** in Simulator/Accessibility Inspector.

**Verification (each P0/P1 item):**  
- Xcode Accessibility Inspector — contrast warnings on affected views.  
- Dynamic Type — largest sizes on iPhone SE simulator.  
- VoiceOver — Add Expense flow, tab switching, split selection.

---

## (B) Empty states and navigation polish

| Screen | Current gap | Suggested behavior |
|--------|-------------|-------------------|
| **Home** | No content when no recent activity | Illustration or SF Symbol cluster + short line (“No recent activity”) + secondary action (e.g. open Groups or trigger add expense) |
| **Friends** | `FriendsView` never loads data; empty list silent | Empty state + “Friends you split with will appear here” OR wire fetch + balances (ties to product roadmap) |
| **Groups** | If zero groups | Empty state + create group CTA (if creation exists) |
| **Insights** | If no data | Empty chart placeholder with guidance |

**Navigation polish (HIG-aligned):**

- Keep **large titles** consistent per tab (`Home` already scrolls; ensure title display mode matches sibling tabs).  
- Ensure **destructive** and **primary** actions use standard placements (toolbar trailing for primary on modals — already partially there).  
- Document **deep link** expectations later (v2); short term: stable `NavigationStack` IDs where pushing group detail.

---

## (C) Add Expense — layout and form contrast

**Form surface**

- Default SwiftUI `Form` is optimized for light appearance; mixed with a dark app shell feels inconsistent. Options: (1) dark `Form` styling via `scrollContentBackground`, section backgrounds, and `Color` tokens; (2) replace `Form` with `ScrollView` + custom grouped cards matching `#1C1C1E` — pick one approach and apply to **Add Expense** first, then receipt/item flows if any share styling.

**Split section**

- **Short term:** Ensure horizontal `ScrollView` has visible scroll affordance or padding so last chip is not clipped; snap or center selected option on change if helpful.  
- **Medium term:** Replace single row with **adaptive grid** or **two rows** at compact width; cap label length (“By Item” vs icon-only at accessibility sizes).

**Amount row**

- Replace magic number `28` with **semantic style** (e.g. `.font(.title)` with `.fontWeight(.bold)`) and test at **AX5**.

**Keyboard / focus**

- Decimal pad: ensure **Done** accessory or dismiss strategy (HIG input accessory) for usability.

---

## (D) Feature completeness matrix

| Feature | Status | Notes |
|---------|--------|--------|
| 4 tabs + floating add | **Done** | `ContentView` |
| Auth | **Done** | `AuthManager`, `AuthView` |
| Home balance + recent activity | **Done** | Empty state missing |
| Groups list + detail | **Done** | Verify edge cases |
| Add expense — amount, currency, group, category | **Done** | Form contrast issues |
| Split types UI | **Stub** | All five in `SplitPickerView`; submit uses **equal only** (`calculateEqualSplits`) |
| Receipt scan | **Partial** | UI path; depends on scanner + parsing |
| Recurring toggle + interval | **Stub** | Stored in model path; **no scheduler** |
| Settle up / Interac | **Done / partial** | Flow exists; verify end-to-end |
| Insights charts | **Done / partial** | Depends on data volume |
| Profile settings | **Done** | |
| Realtime sync | **Done** | `SyncManager` + notifications |
| Widgets | **Partial** | Profile copy references widgets |
| Friends + balances | **Missing / stub** | `FriendsView` no fetch |
| Comments on expenses | **Missing** | Not in inventory |
| Biometric app lock | **Missing** | |
| Offline / SwiftData | **Partial / missing** | Per handoff |

---

## (E) Suggested v2 features (worth adding)

1. **Split logic parity** — Percent, exact, shares, by-item with validation and server-side or client-trusted split rows (aligns with existing `expense_splits.split_type`).  
2. **Friends & balances** — Cross-group friend list and per-friend net balance (high user expectation vs Splitwise-class apps).  
3. **Recurring automation** — Local notifications + background task or server cron; clear UX for “next occurrence.”  
4. **Expense comments / activity** — Lightweight thread or audit log for disputes.  
5. **Biometric gate** — Optional Face ID / Touch ID for open (sensitive finance data).  
6. **Apple Pay / Cash App style settle** — Deep links; Interac is CA-specific — document regions.  
7. **Export (CSV/PDF)** — Trust and tax season.  
8. **System appearance** — Optional light mode or true dark-only with audited palette (product decision).

---

## (F) Implementation phases (1–2 week slices, solo)

**Phase 1 (Week 1) — Contrast & Add Expense**  
- **Do:** P0 items for Add Expense + Home title + tab bar scheme; split picker scroll/layout fix so no chip is clipped on SE + largest type.  
- **Verify:** Accessibility Inspector (contrast), Dynamic Type AX5, VoiceOver on Add Expense and Home.

**Phase 2 (Week 2) — Empty states & navigation**  
- **Do:** Home empty state; Friends empty state (and minimal load or explicit “coming soon” if data not wired); align navigation title behavior across tabs.  
- **Verify:** Fresh-install flows; screenshot matrix for marketing/App Store.

**Phase 3 (Following sprint) — Accessibility sweep + form architecture**  
- **Do:** P2 audit (Insights, Profile, lists); optional migration from plain `Form` to tokenized dark grouped UI; keyboard toolbar for amount field.  
- **Verify:** Reduce Transparency + Increase Contrast; RTL if in scope.

**Phase 4 (Parallel / backlog) — Feature depth**  
- **Do:** Choose one: split logic beyond equal **or** Friends fetch + balances **or** recurring scheduler stub → real.  
- **Verify:** Unit tests for split math; integration test against Supabase for one split type.

---

## Guardrails

- **Must have:** No regression on Supabase writes; split changes must stay consistent with `expense_splits` schema.  
- **Must not have:** Hard-coded colors scattered without a single semantic layer (introduce or extend existing `Color(hex:)` usage toward named tokens as you touch files).  
- **HIG / a11y:** Prefer standard components and materials; test Dynamic Type and contrast on real smallest target device.

---

## ADR-style decision (UI shell)

| Field | Content |
|-------|--------|
| **Decision** | Treat Add Expense as a first-class surface: either fully dark-grouped styling or documented light sheet with WCAG-AA text colors — not an unthemed default `Form` on a dark app. |
| **Drivers** | User screenshots show contrast failures; brand consistency; App Store accessibility narrative. |
| **Alternatives** | (A) Dark custom layout — stronger brand match, more work. (B) Light sheet with fixed palette — faster, must pass contrast audit. |
| **Why chosen** | Defer to Phase 1 spike: 4–8 hours to compare (A) vs (B) on device; document choice in PR. |
| **Consequences** | Touch `AddExpenseView`, possibly `ReceiptScannerView` / `ItemSplitView` for consistency. |
| **Follow-ups** | Single `ChipInTheme` or asset catalog color set if not already centralized. |

---

## Success criteria (initiative)

- Measurable improvement: **no** Accessibility Inspector contrast failures on P0 screens at default and large Dynamic Type.  
- Add Expense: all split options visible and tappable on iPhone SE without horizontal guesswork.  
- Home: no “black void” for new users.  
- Matrix (D) updated in-repo or in release notes when features move from stub to done.

---

*Plan generated for planning-only handoff; implementation via normal dev workflow when approved.*
