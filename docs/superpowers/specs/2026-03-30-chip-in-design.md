# Chip In — Design Spec
**Date:** 2026-03-30
**Status:** Approved

---

## Overview

Chip In is a free, ad-free iOS expense splitting app for Canadian users. It is designed to be everything Splitwise is not: fast, beautiful, uncluttered, and completely free with no paywalls. Built with native SwiftUI for the best possible iOS experience.

---

## Core Requirements

- **Platform:** iOS 17+ (SwiftUI native)
- **Cost to user:** 100% free — no ads, no paywalls, no premium tier
- **Target region:** Canada only (CAD as default currency)
- **Distribution:** Xcode direct install for initial testing (2–3 devices); TestFlight once ready to expand
- **Users:** Friend groups, roommates/housemates, couples, travel groups — all contexts

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 17+) |
| Local storage / offline | SwiftData |
| Backend | Supabase (free tier) — PostgreSQL, Realtime, Auth |
| Authentication | Apple Sign-In + magic link email |
| Receipt AI | iOS Vision framework (on-device OCR) + Supabase Edge Function + Gemini 1.5 Flash (Google AI Studio free tier — 1,500 req/day, $0) |
| Push notifications | Supabase + APNs |
| Widgets | WidgetKit (Home Screen + Lock Screen) |

---

## Visual Design

**Style:** Dark Minimal + Warm Friendly hybrid
- Deep charcoal/black base (`#0A0A0A`, `#1C1C1E`)
- Warm amber/orange accent colour (`#F97316`) as primary action colour
- High contrast typography, bold numbers
- Feels premium (like a banking app) but approachable (like iMessage)
- Smooth spring animations throughout

**Modes:** Dark / Light / System — user selectable
**Accent colours:** 5 warm palette options selectable in Profile
**App icons:** 4 alternate icons (dark, light, minimal, colourful)

---

## Navigation

4-tab bottom navigation + persistent floating **+** button:

### Tab 1 — Home
- Net balance card (large, bold): "You're owed $240" or "You owe $80"
- Quick-settle list: top 3 pending balances with one-tap Interac flow
- Activity feed: live stream of all group/friend expense activity

### Tab 2 — Groups
- Groups list: each shows custom emoji, colour, name, your balance, last activity
- Group detail: expense list, member balances, settle-up summary
- Expense detail: full split breakdown, comments, edit/delete
- Friends view: 1-on-1 balances outside of groups

### Tab 3 — Insights
- Monthly overview: total spent, owed, settled this month
- Category breakdown: animated donut chart with warm colours
- 6-month spending trend bar chart
- Top spender stat per group
- Full settlement history log

### Tab 4 — Profile
- Avatar + name (custom photo or Memoji)
- Appearance: Dark/Light/System toggle, accent colour picker
- Default split method per group
- Notification preferences (nudge timing, reminders on/off)
- Currency settings (CAD default + travel currencies)
- Interac e-Transfer contact (email or phone number)
- Widget configuration (Home Screen + Lock Screen)
- Alternate app icon picker
- Privacy: biometric lock (Face ID/Touch ID), hide balances mode
- Sound settings: custom sound on/off per event type

### Floating + Button (always visible)
Opens Add Expense sheet from any tab.

---

## Add Expense Flow

Designed for speed — 3 taps to log a basic expense:

1. **Amount** — large numpad, feels like Apple Pay
2. **Who paid + split with** — pick group or individual friends
3. **Split method** — Equal / Percentage / Exact amount / By item / By shares
4. **Category** — emoji-tagged: Food, Travel, Rent, Fun, Utilities, Other
5. **Receipt scan** — tap camera icon, AI fills the form (see Receipt Scanning)
6. **Recurring toggle** — set frequency (daily/weekly/monthly)
7. **Note** — optional description
8. **Comments** — add context notes on any expense

---

## Receipt Scanning — Item-Level Splitting

One of the core differentiators over Splitwise:

1. User photographs a receipt
2. iOS Vision framework performs on-device OCR
3. Supabase Edge Function calls Gemini 1.5 Flash (free tier) to parse line items, prices, subtotal, tax, tip
4. App displays each **individual item** for assignment
5. User taps each item to assign it to one person (drag/tap)
6. **Tax is distributed proportionally** across each person's items automatically
7. Each person's total = their items + their proportional share of tax
8. Tip can be split equally or proportionally
9. Items shared between multiple people (e.g. a shared appetizer) should be added as a separate equal-split expense

Example: Deepak has $18 burger, Raj has $12 salad, $4.50 tax total → Deepak pays $2.70 tax, Raj pays $1.80.

---

## Split Types

- **Equal** — divide total evenly
- **Percentage** — each person pays a set %
- **Exact amount** — manually enter each person's share
- **By item** — item-level assignment (receipt scanning flow)
- **By shares** — e.g. 2 shares vs 1 share

---

## Recurring Expenses

- Toggle on any expense to make it recurring
- Frequencies: daily, weekly, bi-weekly, monthly
- Auto-creates expense at interval, notifies all group members
- Ideal for rent, subscriptions, utilities

---

## Interac e-Transfer Flow

Canadian banks do not expose public deep-link APIs for pre-filling transfers. The flow is:

1. Tap "Settle Up" on any balance
2. Exact amount **auto-copies to clipboard** (toast confirmation shown)
3. Recipient's Interac email/phone displayed on screen
4. "Open Bank App" button — user selects their bank from a list
5. Bank app opens; user pastes amount, enters recipient, sends
6. Back in Chip In: tap "I've sent it" → balance marked settled
7. Confetti animation + satisfying sound

**Supported banks:** TD, RBC, Scotiabank, BMO, CIBC, Tangerine, EQ Bank, Wealthsimple Cash

Each user stores their Interac contact info in their Profile for others to see during settle-up.

---

## Custom Sounds

Distinct audio + haptic feedback per event type:

| Event | Sound |
|---|---|
| Adding an expense | Neutral "faaah" chime |
| Someone owes you / you get paid back | Celebratory "haiyo!" |
| You owe someone | Subtle uh-oh tone |
| Settle up complete | Big satisfying sound + strong haptic |

All sounds toggleable individually in Profile → Sound Settings.

---

## iOS Widgets & Lock Screen

- **Home Screen widget (small):** Net balance — "You're owed $240"
- **Home Screen widget (medium):** Top 3 pending balances
- **Lock Screen widget:** Balance indicator, glanceable
- Configured in Profile → Widgets

---

## Offline Mode

- SwiftData mirrors all user data locally
- Full app functionality available offline (add, view, edit expenses)
- Changes queued locally, synced to Supabase on reconnection
- Supabase Realtime pushes live updates to all group members when online
- Conflict resolution: last-write-wins with server timestamp

---

## Push Notifications

- Settle-up reminders (user-configurable timing)
- "X added an expense" in your groups
- "X marked a debt as settled"
- Smart nudge: not spammy, respects quiet hours
- All notification types individually toggleable

---

## Multi-Currency

- Default: CAD
- Add travel currencies per expense or per group
- Auto-converts to CAD using exchange rate at time of expense (via frankfurter.app — free, no API key required)
- Settlement always shown in CAD

---

## Spending Insights

- Monthly totals: spent, owed, settled
- Category donut chart (animated, tap to drill down)
- 6-month bar chart trend
- Per-group spending breakdown
- "Top spender" social stat per group
- Full settlement history

---

## Data Model (Supabase / PostgreSQL)

```
users             — id, name, avatar_url, email, default_currency, interac_contact
groups            — id, name, emoji, colour, created_by, created_at
group_members     — group_id, user_id, joined_at, role (admin/member)
expenses          — id, group_id, paid_by, title, total_amount, currency, category,
                    receipt_url, is_recurring, recurrence_interval, created_at, updated_at
expense_items     — id, expense_id, name, price, tax_portion, assigned_to (user_id)
expense_splits    — id, expense_id, user_id, owed_amount, split_type, is_settled
settlements       — id, from_user_id, to_user_id, amount, group_id, settled_at, method
comments          — id, expense_id, user_id, body, created_at
notifications     — id, user_id, type, reference_id, is_read, created_at
```

---

## Personalization Summary

| Feature | Options |
|---|---|
| Appearance | Dark / Light / System |
| Accent colour | 5 warm palettes |
| App icon | 4 variants |
| Default split | Per group |
| Sounds | Per event type, on/off |
| Notifications | Per type, timing |
| Privacy | Biometric lock, hide balances |
| Widgets | Home Screen + Lock Screen |
| Currency | CAD + travel currencies |

---

## Distribution Plan

1. **Now (testing):** Free Xcode direct install on 2–3 iPhones
2. **After validation:** Apple Developer Program ($99 USD/year) → TestFlight link for friends
3. **Future:** App Store submission (no additional cost)
