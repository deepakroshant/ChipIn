-- ============================================================
-- Fix infinite recursion in RLS policies
-- Root cause: expenses policy checks expense_splits (with RLS),
-- expense_splits policy checks expenses (with RLS) → infinite loop.
-- Fix: use a SECURITY DEFINER function that bypasses RLS for the
-- inner check, breaking the cycle.
-- ============================================================

-- 1. Security-definer helper: check expense_splits without triggering RLS
create or replace function public.auth_user_has_split(expense_uuid uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.expense_splits
    where expense_id = expense_uuid
      and user_id = auth.uid()
  );
$$;

-- 2. Drop all recursive policies
drop policy if exists "expenses_access" on public.expenses;
drop policy if exists "expense_splits_access" on public.expense_splits;
drop policy if exists "expense_items_access" on public.expense_items;

-- 3. Expenses policy — uses security definer fn, no direct expense_splits join
create policy "expenses_access" on public.expenses
  for all using (
    paid_by = auth.uid()
    or auth_user_has_split(id)
    or (group_id is not null and group_id in (
      select group_id from public.group_members where user_id = auth.uid()
    ))
  );

-- 4. Expense splits policy — only checks own rows + payer (no recursion:
--    expenses policy doesn't join expense_splits directly anymore)
create policy "expense_splits_access" on public.expense_splits
  for all using (
    user_id = auth.uid()
    or expense_id in (
      select id from public.expenses where paid_by = auth.uid()
    )
  );

-- 5. Expense items policy — same pattern
create policy "expense_items_access" on public.expense_items
  for all using (
    assigned_to = auth.uid()
    or expense_id in (
      select id from public.expenses where paid_by = auth.uid()
    )
  );
