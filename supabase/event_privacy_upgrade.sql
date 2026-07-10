-- L!V!N event privacy + event feed polish support.
-- Rerunnable in the Supabase SQL Editor.
-- Safe/additive: does not drop tables, reset data, delete rows, or delete storage objects.

begin;

alter table public.events
  add column if not exists is_public boolean not null default true,
  add column if not exists invite_token text;

create unique index if not exists events_invite_token_key
on public.events(invite_token)
where invite_token is not null;

create index if not exists events_visibility_starts_idx
on public.events(is_public, starts_at desc);

create index if not exists events_ends_at_idx
on public.events(ends_at);

create index if not exists events_created_at_idx
on public.events(created_at desc);

create index if not exists events_location_idx
on public.events(latitude, longitude);

alter table public.events enable row level security;

drop policy if exists "events readable" on public.events;
drop policy if exists "public or member events readable" on public.events;
drop policy if exists "users create events" on public.events;
drop policy if exists "hosts update own events" on public.events;
drop policy if exists "hosts delete own events" on public.events;

create policy "public or member events readable"
on public.events for select
to authenticated
using (
  is_public = true
  or host_id = (select auth.uid())
  or exists (
    select 1
    from public.event_members em
    where em.event_id = events.id
      and em.user_id = (select auth.uid())
  )
);

create policy "users create events"
on public.events for insert
to authenticated
with check (host_id = (select auth.uid()));

create policy "hosts update own events"
on public.events for update
to authenticated
using (host_id = (select auth.uid()))
with check (host_id = (select auth.uid()));

create policy "hosts delete own events"
on public.events for delete
to authenticated
using (host_id = (select auth.uid()));

grant select, insert, update, delete on public.events to authenticated;

commit;
