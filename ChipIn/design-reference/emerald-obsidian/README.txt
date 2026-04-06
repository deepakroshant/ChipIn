ChipIn — Stitch export "Emerald Obsidian" (HTML reference)
========================================================

These HTML files are design references (Tailwind + Material Symbols + Manrope).
They are NOT the live SwiftUI app; use them to align colors, typography, and layout.

Generated files (01–05) are self-contained mocks aligned with theme-colors.json.
Open any .html in a browser (double-click or drag into Chrome/Safari).

Screens (filenames):
  01-home.html       — Home: net balance hero, stats bento, recent activity, tab bar
  02-add-expense.html — Add Expense: amount, title, split chips, participants, recurring/receipt
  03-groups.html     — Groups list: "Expense Squads" cards, outstanding / owed / settled
  04-profile.html    — Profile: impact score ring, security, Interac, social toggles, logout
  05-auth-login.html — Sign in: email/password, Sign in with Apple, create account link

Shared design tokens: see theme-colors.json (matches Tailwind extend.colors in each file).

Notes vs production ChipIn (SwiftUI):
  — Real app tab order: Home, Groups, Search, Insights, Profile + floating + for add expense.
  — Stitch Home mock puts a FAB in the tab bar center; app uses Search as its own tab.
  — "Emerald" secondary #4EDEA3 is the mint/green accent in these mocks; Swift ChipInTheme uses
    success #34D399 for similar semantics — map as needed.

How to archive your Stitch HTML paste
---------------------------------------
1. Paste the ENTIRE multi-screen export into:  stitch-full-export.html  (same folder as this file).
2. Run:  python3 split_export.py stitch-full-export.html
3. You should get 01-home.html … 05-auth-login.html

If split counts are wrong, your paste may be missing a <!-- Screen Name --> line before a <!DOCTYPE>.
