create policy "authenticated users upload snap media"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'snap-media'
  and owner = (select auth.uid())
);

create policy "authenticated users read snap media"
on storage.objects for select
to authenticated
using (
  bucket_id = 'snap-media'
);

create policy "users update own snap media"
on storage.objects for update
to authenticated
using (
  bucket_id = 'snap-media'
  and owner = (select auth.uid())
)
with check (
  bucket_id = 'snap-media'
  and owner = (select auth.uid())
);

create policy "users delete own snap media"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'snap-media'
  and owner = (select auth.uid())
);

create policy "authenticated users upload avatars"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and owner = (select auth.uid())
);

create policy "public avatar read"
on storage.objects for select
to public
using (
  bucket_id = 'avatars'
);
