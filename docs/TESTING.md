# ChipIn — manual testing guide

Use this checklist to verify features after a build or a Supabase change. Build the iOS app from `ChipIn/` with the `ChipIn` scheme.

## Prerequisites

1. **Supabase** — Run `supabase/RUN_THIS_ON_PRODUCTION_CHIPIN.sql` in the **SQL Editor** on your production (or staging) project. It now includes **reactions** and **expense_templates** (sections 9–10), so you do **not** need to run `011_reactions.sql` and `013_expense_templates.sql` separately if you paste the full file.
2. **Avatar uploads** — In **Storage**, create a bucket named **`avatars`**: allow **public** read and **authenticated** write (or match your `AvatarService` policy). This is not part of the SQL file.
3. **Sign in** — Use a real test account with at least one friend or group for social flows.

> **Note:** `chipin_existing_db_one_paste.sql` is kept in sync with `RUN_THIS_ON_PRODUCTION_CHIPIN.sql` (same sections 9–10). Either file is safe to paste for an existing database.

---

## Feature checklist

| # | Feature | Where | How to test |
|---|---------|-------|-------------|
| 1 | Category auto-detect | Add expense → title | Type e.g. “Uber to airport” or “groceries”; category should update; sparkle may show when auto-detected. |
| 2 | Tip calculator | Add expense (food/fun when shown) | Use 15/18/20% or custom; confirm total updates. |
| 3 | Expense templates | Add expense → templates | **Needs `expense_templates` table.** Save a template; open add expense again and apply it. |
| 4 | Emoji reactions | Expense detail | **Needs `reactions` table.** Open an expense; tap 👍🔥💀😂🙏; should save and update the bar. |
| 5 | Activity feed | **Activity** tab | Create expenses / settlements; pull to refresh; items should appear. |
| 6 | Profile avatar | Home → profile avatar → Photos | **Needs `avatars` bucket.** Pick a photo; avatar should update after upload. |
| 7 | QR friend add | Profile → Add Friend by QR | Show QR; scan or use paste flow your build supports. |
| 8 | Group leaderboard | Groups → open group → stats/trophy | Open a group with data; leaderboard cards should populate. |
| 9 | Wrapped (year in review) | **Insights** → Wrapped | Tap Wrapped; swipe cards (needs expenses in that year). |
| 10 | Recurring + local reminder | Add expense → recurring | Enable recurring; allow iOS notifications for ChipIn; reminder schedules for day before at 9:00 (see `NotificationManager`). |
| 11 | Onboarding (5 slides + currency) | First launch | Reset app or clear `onboardingComplete` in UserDefaults; walk through slides and currency. |
| 12 | Shimmer loading | Home, Activity | Cold start or slow network; skeleton rows instead of only a spinner. |
| 13 | Group balances | Groups → group detail | With group expenses, **Balances** section shows who owes whom. |
| 14 | Person settlement UI | Home → person | Progress bar + Settled/Pending chips on shared expenses when splits load. |
| 15 | Home stats + streak | **Home** | Check Paid / You’re owed / You owe + streak; pay on consecutive days to exercise streak. |
| 16 | Spending personality | **Profile** | Card loads (Banker, Ghost, etc.) after data fetch. |
| 17 | Monthly recap share | **Insights** → Share This Month | Opens recap; tap Share; share sheet appears with image. |
| 18 | Force dark / system | Profile → Appearance | Toggle Force Dark Mode; off follows system appearance. |
| 19 | Quick text parser | Add expense title | e.g. `Pizza $20 @friendhandle` fills amount and finds user when handle matches search. |
| 20 | Receipt camera guide | Add expense → Scan receipt → camera | Corner frame overlay appears and fades. |
| 21 | App Store review prompt | Settle up → mark settled | Third successful settle may trigger review (often **no UI in Simulator**). |
| 22 | Empty states | Activity / Groups / Search | With no data, friendly empty copy; Groups offers create action. |

---

## Quick smoke (5 minutes)

1. Launch app, sign in.  
2. **Home** → **+** → add a small expense with a friend.  
3. **Insights** → open Wrapped or monthly recap if visible.  
4. **Profile** → toggle sound / dark mode; open QR.  
5. **Groups** → open a group or see empty state.  
6. **Activity** → confirm feed or empty state.  
7. Open an **expense** → reactions (if DB migrated).

---

## Troubleshooting

| Symptom | Likely cause |
|--------|----------------|
| Reactions fail or empty | `reactions` table / RLS not applied — run production SQL section 9. |
| Templates fail | `expense_templates` not applied — section 10. |
| Avatar upload fails | Missing **`avatars`** bucket or storage policies. |
| Search / add friend broken | `search_users` RPC — included in production SQL earlier sections. |
