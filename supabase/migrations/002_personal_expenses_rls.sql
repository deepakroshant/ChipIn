-- Fix RLS to allow personal (groupless) expenses where group_id IS NULL.
-- The original policies blocked all NULL group_id rows.

drop policy if exists "expenses_access" on public.expenses;
drop policy if exists "expense_items_access" on public.expense_items;
drop policy if exists "expense_splits_access" on public.expense_splits;

-- Expenses: you paid it, OR you're in a split, OR it's in a group you belong to
create policy "expenses_access" on public.expenses
  for all using (
    paid_by = auth.uid()
    or id in (select expense_id from public.expense_splits where user_id = auth.uid())
    or (group_id is not null and group_id in (
      select group_id from public.group_members where user_id = auth.uid()
    ))
  );

-- Expense items: follow expense access
create policy "expense_items_access" on public.expense_items
  for all using (
    expense_id in (
      select id from public.expenses where
        paid_by = auth.uid()
        or id in (select expense_id from public.expense_splits where user_id = auth.uid())
        or (group_id is not null and group_id in (
          select group_id from public.group_members where user_id = auth.uid()
        ))
    )
  );

-- Expense splits: you are the debtor OR you paid the parent expense
create policy "expense_splits_access" on public.expense_splits
  for all using (
    user_id = auth.uid()
    or expense_id in (select id from public.expenses where paid_by = auth.uid())
  );
