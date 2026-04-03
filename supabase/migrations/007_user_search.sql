-- ============================================================
-- User search by name, username, or email (for friend picker)
-- ============================================================
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
