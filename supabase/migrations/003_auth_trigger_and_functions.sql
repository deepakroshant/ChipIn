-- ============================================================
-- 1. Auto-create public.users row when a new auth user signs up
-- ============================================================
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

-- ============================================================
-- 2. find_user_by_email — used by Add Expense friend lookup
-- ============================================================
create or replace function public.find_user_by_email(lookup_email text)
returns table(id uuid, name text, email text)
language sql
security definer
set search_path = public
as $$
  select id, name, email
  from public.users
  where lower(email) = lower(lookup_email)
  limit 1;
$$;

-- Allow any authenticated user to call it
grant execute on function public.find_user_by_email(text) to authenticated;

-- ============================================================
-- 3. RLS: allow users to update their own row (name, interac, etc.)
-- ============================================================
drop policy if exists "users_update_own" on public.users;
create policy "users_update_own" on public.users
  for update using (id = auth.uid());

drop policy if exists "users_select_all" on public.users;
create policy "users_select_all" on public.users
  for select using (auth.uid() is not null);
