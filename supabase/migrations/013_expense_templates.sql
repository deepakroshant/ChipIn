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

create policy "users manage own templates"
    on public.expense_templates
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create index expense_templates_user_id_idx on public.expense_templates(user_id);
