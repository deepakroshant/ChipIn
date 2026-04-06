-- Replace foldername() checks with split_part — works on all Postgres versions used by Supabase.
-- Re-run if avatar uploads fail with "new row violates row-level security policy" on storage.objects.
-- (Superseded by 017 for users_modify + lower() path match; safe to re-run.)

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
