-- Fixes avatar upload / profile photo URL errors:
-- • users: explicit WITH CHECK on updates (avoids "new row violates row-level security" on public.users)
-- • storage.objects: case-insensitive folder match (path uses lowercase UUID from the app)

drop policy if exists "users_modify" on public.users;
create policy "users_modify" on public.users
  for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "avatars insert own folder" on storage.objects;
drop policy if exists "avatars update own folder" on storage.objects;
drop policy if exists "avatars delete own folder" on storage.objects;

create policy "avatars insert own folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and lower(split_part(name::text, '/', 1)) = lower(auth.uid()::text)
  );

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

create policy "avatars delete own folder"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and lower(split_part(name::text, '/', 1)) = lower(auth.uid()::text)
  );
