-- (Same content as chipin_existing_db_one_paste.sql — pick either file.)
-- =============================================================================
-- >>> USE THIS FILE FOR YOUR LIVE CHIPIN PROJECT (Supabase) <<<
-- =============================================================================
-- File names:
--   SAFE (this file):   chipin_existing_db_one_paste.sql
--                       RUN_THIS_ON_PRODUCTION_CHIPIN.sql  (same SQL, copy for visibility)
--   WRONG for prod:     chipin_full_setup_one_paste.sql  → starts with CREATE TABLE users
--
-- This script has NO "create table public.users" — only functions, policies, group_invites.
-- Sections 9–10 add `reactions` + `expense_templates` (replaces separate 011/013 pastes).
-- Section 11 adds `expenses.created_by` + `users.push_custom_sound_enabled` (migration 014).
-- Section 12 adds Storage RLS for bucket `avatars` (migration 015).
-- =============================================================================

create extension if not exists "uuid-ossp";

-- Postgres cannot CREATE OR REPLACE when OUT/return columns change — always drop first.
drop function if exists public.find_user_by_email(text);

-- =============================================================================
-- SECTION 2 — Auth trigger + user policies (003); find_user defined in section 3
-- =============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, name, email)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(coalesce(new.email, ''), '@', 1),
      'User'
    ),
    coalesce(new.email, 'guest-' || substr(new.id::text, 1, 8) || '@local.dev')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own" on public.users
  for update using (id = auth.uid());

drop policy if exists "users_select_all" on public.users;
create policy "users_select_all" on public.users
  for select using (auth.uid() is not null);

-- =============================================================================
-- SECTION 3 — Username column + full find_user + handle_new_user (004)
-- =============================================================================

alter table public.users
  add column if not exists username text unique;

update public.users
  set username = lower(regexp_replace(split_part(email, '@', 1), '[^a-z0-9_]', '', 'g'))
  where username is null;

drop function if exists public.find_user_by_email(text);
create or replace function public.find_user_by_email(lookup_email text)
returns table(
  id uuid, name text, email text, username text,
  avatar_url text, default_currency text,
  interac_contact text, created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select id, name, email, username, avatar_url, default_currency, interac_contact, created_at
  from public.users
  where lower(email) = lower(lookup_email)
  limit 1;
$$;

grant execute on function public.find_user_by_email(text) to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  generated_username text;
begin
  generated_username := lower(regexp_replace(
    coalesce(split_part(new.email, '@', 1), 'user'),
    '[^a-z0-9_]', '', 'g'
  ));

  insert into public.users (id, name, email, username)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(coalesce(new.email, ''), '@', 1),
      'User'
    ),
    coalesce(new.email, 'guest-' || substr(new.id::text, 1, 8) || '@local.dev'),
    generated_username
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- =============================================================================
-- SECTION 4 — RLS helpers + full policy reset (006) — no recursion
-- =============================================================================

drop policy if exists "users_own"              on public.users;
drop policy if exists "users_read"           on public.users;
drop policy if exists "users_modify"          on public.users;
drop policy if exists "users_update_own"       on public.users;
drop policy if exists "users_select_all"       on public.users;
drop policy if exists "group_member_access"    on public.groups;
drop policy if exists "group_members_access"   on public.group_members;
drop policy if exists "groups_access"          on public.groups;
drop policy if exists "expenses_access"        on public.expenses;
drop policy if exists "expense_items_access"   on public.expense_items;
drop policy if exists "expense_splits_access"  on public.expense_splits;
drop policy if exists "settlements_access"     on public.settlements;
drop policy if exists "comments_access"        on public.comments;
drop policy if exists "notifications_own"      on public.notifications;

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

create or replace function public.expense_paid_by(eid uuid)
returns uuid language sql security definer stable
set search_path = public as $$
  select paid_by from public.expenses where id = eid limit 1;
$$;

create policy "users_read"   on public.users for select using (auth.uid() is not null);
create policy "users_modify" on public.users
  for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "groups_access" on public.groups
  for all using (
    created_by = auth.uid()
    or is_group_member(id)
  );

create policy "group_members_access" on public.group_members
  for all using (
    user_id = auth.uid()
    or is_group_member(group_id)
  );

create policy "expenses_access" on public.expenses
  for all using (
    paid_by = auth.uid()
    or has_expense_split(id)
    or (group_id is not null and is_group_member(group_id))
  );

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

create policy "settlements_access" on public.settlements
  for all using (from_user_id = auth.uid() or to_user_id = auth.uid());

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

create policy "notifications_own" on public.notifications
  for all using (user_id = auth.uid());

-- =============================================================================
-- SECTION 5 — search_users RPC (007)
-- =============================================================================

create or replace function public.search_users(query text)
returns table(
  id uuid, name text, email text, username text,
  avatar_url text, default_currency text,
  interac_contact text, created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select id, name, email, username, avatar_url, default_currency, interac_contact, created_at
  from public.users
  where
    auth.uid() is not null
    and id != auth.uid()
    and (
      lower(name)     ilike '%' || lower(query) || '%'
      or lower(coalesce(username,'')) ilike '%' || lower(query) || '%'
      or lower(email) ilike '%' || lower(query) || '%'
    )
  order by
    case when lower(name) ilike lower(query) || '%' then 0 else 1 end,
    name
  limit 8;
$$;

grant execute on function public.search_users(text) to authenticated;

-- =============================================================================
-- SECTION 6 — Group invite links (008) — idempotent policies
-- =============================================================================

create table if not exists public.group_invites (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.groups(id) on delete cascade,
  created_by  uuid not null references public.users(id) on delete cascade,
  expires_at  timestamptz not null default now() + interval '7 days',
  created_at  timestamptz not null default now()
);

alter table public.group_invites enable row level security;

drop policy if exists "group members can create invites" on public.group_invites;
create policy "group members can create invites" on public.group_invites for insert
  with check (
    exists (
      select 1 from public.group_members
      where group_members.group_id = group_invites.group_id
        and group_members.user_id = auth.uid()
    )
  );

drop policy if exists "anyone authenticated can read invites" on public.group_invites;
create policy "anyone authenticated can read invites" on public.group_invites for select
  using (auth.uid() is not null);

-- =============================================================================
-- SECTION 7 — Group budget column (009)
-- =============================================================================

alter table public.groups add column if not exists budget numeric(12,2);

-- =============================================================================
-- SECTION 8 — Explicit WITH CHECK on expenses (010)
-- =============================================================================

create or replace function public.expense_paid_by(eid uuid)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select paid_by from public.expenses where id = eid limit 1;
$$;

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

-- =============================================================================
-- SECTION 9 — Expense emoji reactions (same as migrations/011_reactions.sql)
-- =============================================================================

create table if not exists public.reactions (
    id uuid primary key default gen_random_uuid(),
    expense_id uuid not null references public.expenses(id) on delete cascade,
    user_id uuid not null references public.users(id) on delete cascade,
    emoji text not null check (emoji in ('👍','🔥','💀','😂','🙏')),
    created_at timestamptz not null default now(),
    unique (expense_id, user_id, emoji)
);

alter table public.reactions enable row level security;

drop policy if exists "reactions visible to authenticated" on public.reactions;
create policy "reactions visible to authenticated"
    on public.reactions for select
    using (auth.role() = 'authenticated');

drop policy if exists "users insert own reactions" on public.reactions;
create policy "users insert own reactions"
    on public.reactions for insert
    with check (auth.uid() = user_id);

drop policy if exists "users delete own reactions" on public.reactions;
create policy "users delete own reactions"
    on public.reactions for delete
    using (auth.uid() = user_id);

create index if not exists reactions_expense_id_idx on public.reactions(expense_id);

-- =============================================================================
-- SECTION 10 — Saved expense templates (same as migrations/013_expense_templates.sql)
-- =============================================================================

create table if not exists public.expense_templates (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    name text not null,
    title text not null,
    category text not null default 'other',
    split_type text not null default 'equal',
    currency text not null default 'CAD',
    created_at timestamptz not null default now()
);

alter table public.expense_templates enable row level security;

drop policy if exists "users manage own templates" on public.expense_templates;
create policy "users manage own templates"
    on public.expense_templates
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create index if not exists expense_templates_user_id_idx on public.expense_templates(user_id);

-- =============================================================================
-- SECTION 11 — Expense creator + push sound preference (migrations/014)
-- =============================================================================

alter table public.expenses
  add column if not exists created_by uuid references public.users(id);

update public.expenses
set created_by = paid_by
where created_by is null;

alter table public.users
  add column if not exists push_custom_sound_enabled boolean not null default true;

-- =============================================================================
-- SECTION 12 — Storage policies for `avatars` bucket (migrations/015)
-- Create bucket in Dashboard first: public read, then run these policies.
-- =============================================================================

drop policy if exists "avatars public read" on storage.objects;
create policy "avatars public read"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists "avatars insert own folder" on storage.objects;
create policy "avatars insert own folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and lower(split_part(name::text, '/', 1)) = lower(auth.uid()::text)
  );

drop policy if exists "avatars update own folder" on storage.objects;
create policy "avatars update own folder"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and lower(split_part(name::text, '/', 1)) = lower(auth.uid()::text)
  )
  with check (
    bucket_id = 'avatars'
    and lower(split_part(name::text, '/', 1)) = lower(auth.uid()::text)
  );

drop policy if exists "avatars delete own folder" on storage.objects;
create policy "avatars delete own folder"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and lower(split_part(name::text, '/', 1)) = lower(auth.uid()::text)
  );

-- =============================================================================
-- Done. (Safe to re-run: uses IF NOT EXISTS / DROP POLICY IF EXISTS / CREATE OR REPLACE)
-- =============================================================================
-- Optional (not SQL): Supabase Dashboard → Storage → create bucket `avatars`
--   — public read — then run SECTION 12 policies above.
-- =============================================================================
