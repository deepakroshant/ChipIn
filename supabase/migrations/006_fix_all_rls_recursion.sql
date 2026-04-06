-- ============================================================
-- Fix ALL RLS infinite recursion
-- Root cause: group_members policy self-references group_members
-- causing cycles across all joined policies.
-- Solution: security definer helper functions bypass RLS for
-- inner checks, completely eliminating recursion.
-- ============================================================

-- Drop ALL existing policies that could recurse
drop policy if exists "users_own"              on public.users;
drop policy if exists "users_read"           on public.users;
drop policy if exists "users_modify"          on public.users;
drop policy if exists "users_update_own"       on public.users;
drop policy if exists "users_select_all"       on public.users;
drop policy if exists "group_member_access"    on public.groups;
drop policy if exists "group_members_access"   on public.group_members;
drop policy if exists "expenses_access"        on public.expenses;
drop policy if exists "expense_items_access"   on public.expense_items;
drop policy if exists "expense_splits_access"  on public.expense_splits;
drop policy if exists "settlements_access"     on public.settlements;
drop policy if exists "comments_access"        on public.comments;
drop policy if exists "notifications_own"      on public.notifications;

-- ============================================================
-- Security-definer helpers (bypass RLS, no recursion)
-- ============================================================

-- Is the current user a member of this group?
create or replace function public.is_group_member(gid uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid and user_id = auth.uid()
  );
$$;

-- Does the current user have a split on this expense?
create or replace function public.has_expense_split(eid uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from public.expense_splits
    where expense_id = eid and user_id = auth.uid()
  );
$$;

-- What group does this expense belong to?
create or replace function public.expense_group(eid uuid)
returns uuid language sql security definer stable
set search_path = public as $$
  select group_id from public.expenses where id = eid limit 1;
$$;

-- Who paid this expense? (avoid "select from expenses" inside splits/items RLS)
create or replace function public.expense_paid_by(eid uuid)
returns uuid language sql security definer stable
set search_path = public as $$
  select paid_by from public.expenses where id = eid limit 1;
$$;

-- ============================================================
-- Clean simple policies using the helpers
-- ============================================================

-- Users: anyone authenticated can read all profiles (needed for name lookup)
--        only you can modify your own row
create policy "users_read"   on public.users for select using (auth.uid() is not null);
create policy "users_modify" on public.users for all    using (auth.uid() = id);

-- Groups: you can access groups you created or are a member of
create policy "groups_access" on public.groups
  for all using (
    created_by = auth.uid()
    or is_group_member(id)
  );

-- Group members: you can see/modify members of groups you belong to
create policy "group_members_access" on public.group_members
  for all using (
    user_id = auth.uid()
    or is_group_member(group_id)
  );

-- Expenses: you paid it, you have a split, or it's in your group
create policy "expenses_access" on public.expenses
  for all using (
    paid_by = auth.uid()
    or has_expense_split(id)
    or (group_id is not null and is_group_member(group_id))
  );

-- Expense splits: your split, or expense you paid, or expense in your group
create policy "expense_splits_access" on public.expense_splits
  for all
  using (
    user_id = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or (expense_group(expense_id) is not null and is_group_member(expense_group(expense_id)))
  )
  with check (
    user_id = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or (expense_group(expense_id) is not null and is_group_member(expense_group(expense_id)))
  );

-- Expense items: assigned to you, or expense you paid, or expense in your group
create policy "expense_items_access" on public.expense_items
  for all
  using (
    assigned_to = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or (expense_group(expense_id) is not null and is_group_member(expense_group(expense_id)))
  )
  with check (
    assigned_to = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or (expense_group(expense_id) is not null and is_group_member(expense_group(expense_id)))
  );

-- Settlements: you sent or received
create policy "settlements_access" on public.settlements
  for all using (from_user_id = auth.uid() or to_user_id = auth.uid());

-- Comments: on expenses you can see
create policy "comments_access" on public.comments
  for all
  using (
    user_id = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or has_expense_split(expense_id)
    or (expense_group(expense_id) is not null and is_group_member(expense_group(expense_id)))
  )
  with check (
    user_id = auth.uid()
    or expense_paid_by(expense_id) = auth.uid()
    or has_expense_split(expense_id)
    or (expense_group(expense_id) is not null and is_group_member(expense_group(expense_id)))
  );

-- Notifications: your own
create policy "notifications_own" on public.notifications
  for all using (user_id = auth.uid());
