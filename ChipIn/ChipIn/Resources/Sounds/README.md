# Custom Sounds

These `.caf` files are committed in-repo (converted from macOS system AIFFs via `afconvert`) and are picked up automatically by the Xcode **file-system synchronized** `ChipIn` group (no manual target membership needed).

| File | Meaning |
|------|---------|
| `money_out.caf` | Money **owed** (you owe / balance down) — `SoundService.play(.moneyOut)` |
| `money_in.caf` | Money **gained** (plus / someone paid you or balance up) — `SoundService.play(.moneyIn)` |
| `expense_add.caf` | When adding an expense (`SoundService.play(.expenseAdd)`) |
| `settled.caf` | Settle-up complete (`SoundService.play(.settled)`) |

**Remote push (APNs):** the Edge Function sends `"sound": "money_in.caf"` or `"money_out.caf"`. Apple only plays those if the **same filenames** exist in the main app bundle — without them, pushes may fall back to the default tone or behave oddly.

Convert other formats with:

```bash
afconvert -f caff -d ima4 input.m4a output.caf
```
