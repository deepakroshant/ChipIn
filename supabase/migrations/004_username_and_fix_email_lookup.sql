-- ============================================================
-- 1. Add username column to users
-- ============================================================
alter table public.users
  add column if not exists username text unique;

-- Auto-generate username from email prefix on existing rows
update public.users
  set username = lower(regexp_replace(split_part(email, '@', 1), '[^a-z0-9_]', '', 'g'))
  where username is null;

-- ============================================================
-- 2. Fix find_user_by_email — return all columns so Swift
--    AppUser can decode without missing fields
-- ============================================================
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

-- ============================================================
-- 3. Update handle_new_user trigger to also set username
-- ============================================================
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
