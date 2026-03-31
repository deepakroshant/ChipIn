-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Users (extends Supabase auth.users)
create table public.users (
  id uuid references auth.users on delete cascade primary key,
  name text not null,
  avatar_url text,
  email text not null,
  default_currency text not null default 'CAD',
  interac_contact text,
  created_at timestamptz not null default now()
);

-- Groups
create table public.groups (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  emoji text not null default '👥',
  colour text not null default '#F97316',
  created_by uuid references public.users(id) not null,
  created_at timestamptz not null default now()
);

-- Group members
create table public.group_members (
  group_id uuid references public.groups(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  role text not null default 'member' check (role in ('admin', 'member')),
  primary key (group_id, user_id)
);

-- Expenses
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

-- Expense items (for receipt scanning)
create table public.expense_items (
  id uuid primary key default uuid_generate_v4(),
  expense_id uuid references public.expenses(id) on delete cascade,
  name text not null,
  price numeric(10,2) not null,
  tax_portion numeric(10,2) not null default 0,
  assigned_to uuid references public.users(id) not null
);

-- Expense splits
create table public.expense_splits (
  id uuid primary key default uuid_generate_v4(),
  expense_id uuid references public.expenses(id) on delete cascade,
  user_id uuid references public.users(id) not null,
  owed_amount numeric(10,2) not null,
  split_type text not null check (split_type in ('equal','percent','exact','byItem','shares')),
  is_settled boolean not null default false
);

-- Settlements
create table public.settlements (
  id uuid primary key default uuid_generate_v4(),
  from_user_id uuid references public.users(id) not null,
  to_user_id uuid references public.users(id) not null,
  amount numeric(10,2) not null,
  group_id uuid references public.groups(id),
  method text not null default 'interac' check (method in ('interac','cash','other')),
  settled_at timestamptz not null default now()
);

-- Comments
create table public.comments (
  id uuid primary key default uuid_generate_v4(),
  expense_id uuid references public.expenses(id) on delete cascade,
  user_id uuid references public.users(id) not null,
  body text not null,
  created_at timestamptz not null default now()
);

-- Notifications
create table public.notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  type text not null,
  reference_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- Row Level Security
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
