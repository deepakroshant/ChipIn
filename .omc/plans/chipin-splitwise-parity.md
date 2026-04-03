# ChipIn → Splitwise Parity Plan
Generated: 2026-04-02

## Gap Analysis Summary

### P0 — Critical (broken/empty)
| Gap | File | Fix |
|-----|------|-----|
| HomeView shows no loading indicator | HomeView.swift | Show ProgressView when vm.isLoading |
| HomeView error never displayed | HomeView.swift | Add error banner |
| FriendsView always empty | FriendsView.swift | Load friends (people with shared expenses) |
| Only Equal split implemented | AddExpenseViewModel.swift | Implement Percent, Exact, Shares logic |

### P1 — High Impact
| Gap | File | Fix |
|-----|------|-----|
| No expense detail/delete | ExpenseRow.swift | Swipe delete + nav to ExpenseDetailView (new) |
| No activity feed | HomeView.swift | Add recent expenses section below balances |
| Group has no member management | GroupDetailView.swift | Add member, remove member, leave group |
| InsightsView no loading/error UI | InsightsView.swift | Add loading + error states |
| No pull-to-refresh on GroupDetailView | GroupDetailView.swift | Add .refreshable |
| PersonDetailView expense list has no delete | PersonDetailView.swift | Swipe to delete |

### P2 — Polish
| Gap | Files | Fix |
|-----|-------|-----|
| Generic empty states | Multiple | Richer empty states with icon + CTA |
| No search | HomeView / GroupDetailView | Search bar on HomeView balances |
| Missing expense edit | — | Edit sheet from ExpenseDetailView |

## Execution Streams (parallel)

### Stream 1 — HomeView + FriendsView
- HomeView.swift: loading indicator, error banner, recent-activity section
- FriendsView.swift: load people with shared expense history, show balances

### Stream 2 — Expense Detail + Delete
- New: ExpenseDetailView.swift (title, payer, splits breakdown, delete button)
- ExpenseRow.swift: NavigationLink wrapper, swipe-to-delete
- ExpenseService.swift: add deleteExpense() method

### Stream 3 — Group Management
- GroupDetailView.swift: add member (by email), remove member, leave group
- GroupService.swift: addMember(), removeMember(), leaveGroup() methods

### Stream 4 — UI Polish
- InsightsView.swift: loading spinner + error banner
- GroupDetailView.swift: pull-to-refresh
- FriendsView.swift: better empty state
- PersonDetailView.swift: pull-to-refresh

## Acceptance Criteria
- [ ] Home shows spinner while loading, error message on failure
- [ ] Friends tab shows list of people you've split with + net balance
- [ ] Tapping an expense row opens detail showing all splits
- [ ] Swipe left on expense → delete (with confirmation)
- [ ] Group detail has "Add Member" button that accepts email
- [ ] Group detail has swipe-to-remove-member and Leave Group button
- [ ] InsightsView shows spinner while vm.isLoading
- [ ] All list views support pull-to-refresh
