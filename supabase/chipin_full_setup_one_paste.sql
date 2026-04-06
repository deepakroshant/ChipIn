-- =============================================================================
-- CHIPIN — ONE PASTE FOR SUPABASE SQL EDITOR (BRAND-NEW EMPTY PROJECT ONLY)
-- =============================================================================
-- • If you already have public.users / groups / expenses → DO NOT run this file.
--   You will get: ERROR: relation "users" already exists
--   Use instead:  chipin_existing_db_one_paste.sql  (same folder)
-- • Brand-new empty Supabase project: run this entire file once (Role: postgres).
-- • Migrations 002 and 005 are NOT included — superseded by 006 + 010.
-- =============================================================================

-- STOP: If your project already has tables, Postgres will error on CREATE TABLE.
-- This guard fails first with a clear message (instead of "users already exists").
DO $chipin_schema_guard$
BEGIN
  IF to_regclass('public.users') IS NOT NULL THEN
    RAISE EXCEPTION
      'ChipIn: public.users already exists. Do NOT use this file. In the repo open supabase/chipin_existing_db_one_paste.sql (or RUN_THIS_ON_PRODUCTION_CHIPIN.sql), copy ALL of it, paste here, Run.'
      USING ERRCODE = 'P0001';
  END IF;
END;
$chipin_schema_guard$;

-- =============================================================================
-- SECTION 1 — Schema + initial RLS (was 001_initial_schema.sql)
-- =============================================================================

create extension if not exists "uuid-ossp";

create table public.users (
  id uuid references auth.users on delete cascade primary key,
  name text not null,
  avatar_url text,
  email text not null,
  default_currency text not null default 'CAD',
  interac_contact text,
  created_at timestamptz not null default now()
);

create table public.groups (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  emoji text not null default '👥',
  colour text not null default '#F97316',
  created_by uuid references public.users(id) not null,
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid references public.groups(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  role text not null default 'member' check (role in ('admin', 'member')),
  primary key (group_id, user_id)
);

create table public.expenses (
  id uuid primary key default uuid_generate_v4(),
  group_id uuid references public.groups(id) on delete cascade,
  paid_by uuid references public.users(id) not null,
  title text not null,
  total_amount numeric(10,2) not null,
  currency text not null default 'CAD',
  cad_amount numeric(10,2) not null,
  category text not null default 'Other',
  receipt_url text,
  is_recurring boolean not null default false,
  recurrence_interval text check (recurrence_interval in ('daily','weekly','biweekly','monthly')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.expense_items (
  id uuid primary key default uuid_generate_v4(),
  expense_id uuid references public.expenses(id) on delete cascade,
  name text not null,
  price numeric(10,2) not null,
  tax_portion numeric(10,2) not null default 0,
  assigned_to uuid references public.users(id) not null
);

create table public.expense_splits (
  id uuid primary key default uuid_generate_v4(),
  expense_id uuid references public.expenses(id) on delete cascade,
  user_id uuid references public.users(id) not null,
  owed_amount numeric(10,2) not null,
  split_type text not null check (split_type in ('equal','percent','exact','byItem','shares')),
  is_settled boolean not null default false
);

create table public.settlements (
  id uuid primary key default uuid_generate_v4(),
  from_user_id uuid references public.users(id) not null,
  to_user_id uuid references public.users(id) not null,
  amount numeric(10,2) not null,
  group_id uuid references public.groups(id),
  method text not null default 'interac' check (method in ('interac','cash','other')),
  settled_at timestamptz not null default now()
);

create table public.comments (
  id uuid primary key default uuid_generate_v4(),
  expense_id uuid references public.expenses(id) on delete cascade,
  user_id uuid references public.users(id) not null,
  body text not null,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  type text not null,
  reference_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.users enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_items enable row level security;
alter table public.expense_splits enable row level security;
alter table public.settlements enable row level security;
alter table public.comments enable row level security;
alter table public.notifications enable row level security;

create policy "users_own" on public.users for all using (auth.uid() = id);

create policy "group_member_access" on public.groups
  for all using (
    id in (select group_id from public.group_members where user_id = auth.uid())
    or created_by = auth.uid()
  );

create policy "group_members_access" on public.group_members
  for all using (
    group_id in (select group_id from public.group_members where user_id = auth.uid())
  );

create policy "expenses_access" on public.expenses
  for all using (
    group_id in (select group_id from public.group_members where user_id = auth.uid())
  );

create policy "expense_items_access" on public.expense_items
  for all using (
    expense_id in (select id from public.expenses where group_id in (
      select group_id from public.group_members where user_id = auth.uid()
    ))
  );

create policy "expense_splits_access" on public.expense_splits
  for all using (
    expense_id in (select id from public.expenses where group_id in (
      select group_id from public.group_members where user_id = auth.uid()
    ))
  );

create policy "settlements_access" on public.settlements
  for all using (from_user_id = auth.uid() or to_user_id = auth.uid());

create policy "comments_access" on public.comments
  for all using (
    expense_id in (select id from public.expenses where group_id in (
      select group_id from public.group_members where user_id = auth.uid()
    ))
  );

create policy "notifications_own" on public.notifications
  for all using (user_id = auth.uid());

-- =============================================================================
-- SECTION 2 — Auth trigger + user policies (003); find_user defined in section 3
-- =============================================================================

drop function if exists public.find_user_by_email(text);

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
create policy "users_modify" on public.users for all    using (auth.uid() = id);

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
-- SECTION 8 — Explicit WITH CHECK on expenses (010) — same helpers, tighter policy
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
-- Done.
-- =============================================================================
