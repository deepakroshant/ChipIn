-- ============================================================
-- Fix: "infinite recursion detected in policy for relation expenses"
--
-- Cause: policies that do SELECT on public.expenses from inside
-- expense_splits / expense_items / comments RLS re-enter expenses
-- RLS, which again touches expense_splits → loop.
--
-- Fix: read paid_by / group_id via SECURITY DEFINER helpers only
-- (same pattern as has_expense_split + expense_group).
-- ============================================================

-- Who paid this expense? (bypasses RLS — breaks expenses ↔ splits cycle)
create or replace function public.expense_paid_by(eid uuid)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select paid_by from public.expenses where id = eid limit 1;
$$;

-- Ensure other helpers exist (idempotent if 006 already ran)
create or replace function public.is_group_member(gid uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid and user_id = auth.uid()
  );
$$;

create or replace function public.has_expense_split(eid uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from public.expense_splits
    where expense_id = eid and user_id = auth.uid()
  );
$$;

create or replace function public.expense_group(eid uuid)
returns uuid language sql security definer stable
set search_path = public as $$
  select group_id from public.expenses where id = eid limit 1;
$$;

-- Replace child-table policies: no "select id from expenses ..." in RLS
drop policy if exists "expense_splits_access" on public.expense_splits;
create policy "expense_splits_access" on public.expense_splits
  for all
  using (
    user_id = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or (
      expense_group(expense_id) is not null
      and is_group_member(expense_group(expense_id))
    )
  )
  with check (
    user_id = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or (
      expense_group(expense_id) is not null
      and is_group_member(expense_group(expense_id))
    )
  );

drop policy if exists "expense_items_access" on public.expense_items;
create policy "expense_items_access" on public.expense_items
  for all
  using (
    assigned_to = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or (
      expense_group(expense_id) is not null
      and is_group_member(expense_group(expense_id))
    )
  )
  with check (
    assigned_to = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or (
      expense_group(expense_id) is not null
      and is_group_member(expense_group(expense_id))
    )
  );

drop policy if exists "comments_access" on public.comments;
create policy "comments_access" on public.comments
  for all
  using (
    user_id = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or has_expense_split(expense_id)
    or (
      expense_group(expense_id) is not null
      and is_group_member(expense_group(expense_id))
    )
  )
  with check (
    user_id = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or has_expense_split(expense_id)
    or (
      expense_group(expense_id) is not null
      and is_group_member(expense_group(expense_id))
    )
  );

-- Expenses: never use a raw subquery on expense_splits here (that re-enters splits RLS).
drop policy if exists "expenses_access" on public.expenses;
create policy "expenses_access" on public.expenses
  for all
  using (
    paid_by = auth.uid()
    or has_expense_split(id)
    or (group_id is not null and is_group_member(group_id))
  )
  with check (
    paid_by = auth.uid()
    or has_expense_split(id)
    or (group_id is not null and is_group_member(group_id))
  );
