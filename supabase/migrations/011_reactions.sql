create table if not exists public.reactions (
    id uuid primary key default gen_random_uuid(),
    expense_id uuid not null references public.expenses(id) on delete cascade,
    user_id uuid not null references public.users(id) on delete cascade,
    emoji text not null check (emoji in ('👍','🔥','💀','😂','🙏')),
    created_at timestamptz not null default now(),
    unique (expense_id, user_id, emoji)
);

alter table public.reactions enable row level security;

create policy "reactions visible to authenticated"
    on public.reactions for select
    using (auth.role() = 'authenticated');

create policy "users insert own reactions"
    on public.reactions for insert
    with check (auth.uid() = user_id);

create policy "users delete own reactions"
    on public.reactions for delete
    using (auth.uid() = user_id);

create index reactions_expense_id_idx on public.reactions(expense_id);
