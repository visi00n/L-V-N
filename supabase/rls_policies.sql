create policy "profiles readable"
on public.profiles for select
to authenticated
using (
  is_private = false
  or id = (select auth.uid())
  or exists (
    select 1 from public.follows f
    where f.follower_id = (select auth.uid())
    and f.following_id = profiles.id
    and f.status = 'approved'
  )
);

create policy "users insert own profile"
on public.profiles for insert
to authenticated
with check (id = (select auth.uid()));

create policy "users update own profile"
on public.profiles for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy "follows readable"
on public.follows for select
to authenticated
using (true);

create policy "users follow as themselves"
on public.follows for insert
to authenticated
with check (follower_id = (select auth.uid()));

create policy "users remove own follows"
on public.follows for delete
to authenticated
using (follower_id = (select auth.uid()));

create policy "events readable"
on public.events for select
to authenticated
using (true);

create policy "users create events"
on public.events for insert
to authenticated
with check (host_id = (select auth.uid()));

create policy "hosts update own events"
on public.events for update
to authenticated
using (host_id = (select auth.uid()))
with check (host_id = (select auth.uid()));

create policy "event members readable"
on public.event_members for select
to authenticated
using (true);

create policy "users join events as themselves"
on public.event_members for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy "users leave own events"
on public.event_members for delete
to authenticated
using (user_id = (select auth.uid()));

create policy "event chat readable by members"
on public.event_messages for select
to authenticated
using (
  exists (
    select 1 from public.event_members em
    where em.event_id = event_messages.event_id
    and em.user_id = (select auth.uid())
  )
);

create policy "event members send messages"
on public.event_messages for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1 from public.event_members em
    where em.event_id = event_messages.event_id
    and em.user_id = (select auth.uid())
  )
);

create policy "snaps visible by privacy"
on public.snaps for select
to authenticated
using (
  is_public = true
  or creator_id = (select auth.uid())
  or exists (
    select 1 from public.follows f
    where f.follower_id = (select auth.uid())
    and f.following_id = snaps.creator_id
    and f.status = 'approved'
  )
);

create policy "users create own snaps"
on public.snaps for insert
to authenticated
with check (creator_id = (select auth.uid()));

create policy "users update own snaps"
on public.snaps for update
to authenticated
using (creator_id = (select auth.uid()))
with check (creator_id = (select auth.uid()));

create policy "users delete own snaps"
on public.snaps for delete
to authenticated
using (creator_id = (select auth.uid()));

create policy "snap media readable"
on public.snap_media for select
to authenticated
using (
  exists (
    select 1 from public.snaps s
    where s.id = snap_media.snap_id
  )
);

create policy "users insert snap media for own snaps"
on public.snap_media for insert
to authenticated
with check (
  exists (
    select 1 from public.snaps s
    where s.id = snap_media.snap_id
    and s.creator_id = (select auth.uid())
  )
);

create policy "dm conversations readable by members"
on public.direct_conversations for select
to authenticated
using (
  exists (
    select 1 from public.direct_conversation_members dcm
    where dcm.conversation_id = direct_conversations.id
    and dcm.user_id = (select auth.uid())
  )
);

create policy "dm members readable by members"
on public.direct_conversation_members for select
to authenticated
using (
  exists (
    select 1 from public.direct_conversation_members mine
    where mine.conversation_id = direct_conversation_members.conversation_id
    and mine.user_id = (select auth.uid())
  )
);

create policy "dm messages readable by members"
on public.direct_messages for select
to authenticated
using (
  exists (
    select 1 from public.direct_conversation_members dcm
    where dcm.conversation_id = direct_messages.conversation_id
    and dcm.user_id = (select auth.uid())
  )
);

create policy "dm members send messages"
on public.direct_messages for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1 from public.direct_conversation_members dcm
    where dcm.conversation_id = direct_messages.conversation_id
    and dcm.user_id = (select auth.uid())
  )
);

create policy "users create reports"
on public.reports for insert
to authenticated
with check (reporter_id = (select auth.uid()));

create policy "users manage own device tokens"
on public.device_tokens for all
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
