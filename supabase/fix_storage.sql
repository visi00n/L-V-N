-- L!V!N scoped Storage upgrade: buckets plus upload/display policies.
-- Rerunnable in the Supabase SQL Editor. Does not modify or delete user files.

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('event-covers', 'event-covers', true, 5242880, array['image/jpeg']),
  ('snap-media', 'snap-media', false, 5242880, array['image/jpeg']),
  ('avatars', 'avatars', true, 5242880, array['image/jpeg'])
on conflict (id) do update
set name = excluded.name,
    public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

grant select on public.snaps, public.snap_media to authenticated;

drop policy if exists "authenticated users upload snap media" on storage.objects;
drop policy if exists "users upload snap media to own folder" on storage.objects;
drop policy if exists "snap_media users can upload own folder" on storage.objects;
drop policy if exists "authenticated users read snap media" on storage.objects;
drop policy if exists "snap_media authenticated can read allowed objects" on storage.objects;
drop policy if exists "users update own snap media" on storage.objects;
drop policy if exists "snap_media users can update own folder" on storage.objects;
drop policy if exists "users delete own snap media" on storage.objects;
drop policy if exists "snap_media users can delete own folder" on storage.objects;

create policy "authenticated users upload snap media"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'snap-media'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and storage.extension(name) = 'jpg'
);

create policy "authenticated users read snap media"
on storage.objects for select
to authenticated
using (
  bucket_id = 'snap-media'
  and (
    (storage.foldername(name))[1] = (select auth.uid()::text)
    or exists (
      select 1
      from public.snap_media sm
      where sm.storage_path = name
    )
  )
);

create policy "users update own snap media"
on storage.objects for update
to authenticated
using (
  bucket_id = 'snap-media'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'snap-media'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and storage.extension(name) = 'jpg'
);

create policy "users delete own snap media"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'snap-media'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

drop policy if exists "authenticated users upload avatars" on storage.objects;
drop policy if exists "users upload avatars to own folder" on storage.objects;
drop policy if exists "avatars users can upload own folder" on storage.objects;
drop policy if exists "users update own avatars" on storage.objects;
drop policy if exists "avatars users can update own folder" on storage.objects;
drop policy if exists "users delete own avatars" on storage.objects;
drop policy if exists "avatars users can delete own folder" on storage.objects;
drop policy if exists "public avatar read" on storage.objects;

create policy "authenticated users upload avatars"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and storage.extension(name) = 'jpg'
);

create policy "users update own avatars"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and storage.extension(name) = 'jpg'
);

create policy "users delete own avatars"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "public avatar read"
on storage.objects for select
to public
using (bucket_id = 'avatars');

drop policy if exists "event covers upload to own folder" on storage.objects;
drop policy if exists "event covers update in own folder" on storage.objects;
drop policy if exists "event covers delete from own folder" on storage.objects;
drop policy if exists "event_covers users can upload own folder" on storage.objects;
drop policy if exists "event_covers users can update own folder" on storage.objects;
drop policy if exists "event_covers users can delete own folder" on storage.objects;
drop policy if exists "public event covers read" on storage.objects;

create policy "event_covers users can upload own folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'event-covers'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and storage.extension(name) = 'jpg'
);

create policy "event_covers users can update own folder"
on storage.objects for update
to authenticated
using (
  bucket_id = 'event-covers'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'event-covers'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and storage.extension(name) = 'jpg'
);

create policy "event_covers users can delete own folder"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'event-covers'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "public event covers read"
on storage.objects for select
to public
using (bucket_id = 'event-covers');

commit;

select id, public, file_size_limit, allowed_mime_types
from storage.buckets
where id in ('event-covers', 'snap-media', 'avatars')
order by id;

select policyname, cmd, roles
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname in (
    'authenticated users upload snap media',
    'authenticated users read snap media',
    'users update own snap media',
    'users delete own snap media',
    'authenticated users upload avatars',
    'users update own avatars',
    'users delete own avatars',
    'public avatar read',
    'event_covers users can upload own folder',
    'event_covers users can update own folder',
    'event_covers users can delete own folder',
    'public event covers read'
  )
order by policyname;
