-- RLS for Storage bucket `avatars` (path: {user_id}/avatar.jpg).
-- Run after creating the public `avatars` bucket in Dashboard.
-- Match is case-insensitive on the first path segment (UUID casing varies by client).

drop policy if exists "avatars public read" on storage.objects;
create policy "avatars public read"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists "avatars insert own folder" on storage.objects;
create policy "avatars insert own folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and lower(split_part(name::text, '/', 1)) = lower(auth.uid()::text)
  );

drop policy if exists "avatars update own folder" on storage.objects;
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

drop policy if exists "avatars delete own folder" on storage.objects;
create policy "avatars delete own folder"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and lower(split_part(name::text, '/', 1)) = lower(auth.uid()::text)
  );
