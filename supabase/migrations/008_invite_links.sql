create table if not exists group_invites (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references groups(id) on delete cascade,
  created_by  uuid not null references users(id) on delete cascade,
  expires_at  timestamptz not null default now() + interval '7 days',
  created_at  timestamptz not null default now()
);

alter table group_invites enable row level security;

create policy "group members can create invites" on group_invites for insert
  with check (
    exists (
      select 1 from group_members
      where group_members.group_id = group_invites.group_id
        and group_members.user_id = auth.uid()
    )
  );

create policy "anyone authenticated can read invites" on group_invites for select
  using (auth.uid() is not null);
