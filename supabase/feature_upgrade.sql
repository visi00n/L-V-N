-- L!V!N scoped DM upgrade: mutual-follower conversations and inbox RPC.
-- Rerunnable in the Supabase SQL Editor. Does not modify or delete user data.

begin;

create schema if not exists private;
grant usage on schema private to authenticated;

create or replace function private.are_friends(user_a uuid, user_b uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, pg_temp
as $$
  select user_a is not null
    and user_b is not null
    and user_a <> user_b
    and exists (
      select 1
      from public.follows
      where follower_id = user_a
        and following_id = user_b
        and status = 'approved'
    )
    and exists (
      select 1
      from public.follows
      where follower_id = user_b
        and following_id = user_a
        and status = 'approved'
    );
$$;

revoke all on function private.are_friends(uuid, uuid) from PUBLIC, anon;
grant execute on function private.are_friends(uuid, uuid) to authenticated;

create or replace function private.can_access_direct_conversation(
  target_conversation_id uuid,
  viewer_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private, pg_temp
as $$
  select viewer_id is not null
    and exists (
      select 1
      from public.direct_conversation_members
      where conversation_id = target_conversation_id
        and user_id = viewer_id
    )
    and (
      select count(*)
      from public.direct_conversation_members
      where conversation_id = target_conversation_id
    ) = 2
    and not exists (
      select 1
      from public.direct_conversation_members other_member
      where other_member.conversation_id = target_conversation_id
        and other_member.user_id <> viewer_id
        and not private.are_friends(viewer_id, other_member.user_id)
    );
$$;

revoke all on function private.can_access_direct_conversation(uuid, uuid) from PUBLIC, anon;
grant execute on function private.can_access_direct_conversation(uuid, uuid) to authenticated;

create or replace function private.create_direct_conversation_for_authenticated(target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, private, pg_temp
as $$
declare
  v_current_user_id uuid := auth.uid();
  v_existing_conversation_id uuid;
  v_conversation_id uuid;
begin
  if v_current_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if target_user_id is null or target_user_id = v_current_user_id then
    raise exception 'Choose another profile to message.' using errcode = '22023';
  end if;

  if not private.are_friends(v_current_user_id, target_user_id) then
    raise exception 'Direct messages are only available between mutual followers.' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtext(least(v_current_user_id::text, target_user_id::text)),
    hashtext(greatest(v_current_user_id::text, target_user_id::text))
  );

  select mine.conversation_id
  into v_existing_conversation_id
  from public.direct_conversation_members mine
  join public.direct_conversation_members target
    on target.conversation_id = mine.conversation_id
  where mine.user_id = v_current_user_id
    and target.user_id = target_user_id
    and (
      select count(*)
      from public.direct_conversation_members member_count
      where member_count.conversation_id = mine.conversation_id
    ) = 2
  limit 1;

  if v_existing_conversation_id is not null then
    return v_existing_conversation_id;
  end if;

  insert into public.direct_conversations (created_by)
  values (v_current_user_id)
  returning id into v_conversation_id;

  insert into public.direct_conversation_members (conversation_id, user_id)
  values
    (v_conversation_id, v_current_user_id),
    (v_conversation_id, target_user_id);

  return v_conversation_id;
end;
$$;

revoke all on function private.create_direct_conversation_for_authenticated(uuid) from PUBLIC, anon;
grant execute on function private.create_direct_conversation_for_authenticated(uuid) to authenticated;

create or replace function public.create_direct_conversation(target_user_id uuid)
returns uuid
language sql
security invoker
set search_path = pg_catalog, public, private, pg_temp
as $$
  select private.create_direct_conversation_for_authenticated(target_user_id);
$$;

revoke all on function public.create_direct_conversation(uuid) from PUBLIC, anon;
grant execute on function public.create_direct_conversation(uuid) to authenticated;

create or replace function public.get_recent_conversations()
returns table (
  conversation_id uuid,
  target_user_id uuid,
  target_handle text,
  target_display_name text,
  target_avatar_url text,
  target_bio text,
  last_message text,
  updated_at timestamp with time zone
)
language sql
security invoker
set search_path = pg_catalog, public, pg_temp
as $$
  select
    c.id as conversation_id,
    p.id as target_user_id,
    p.username as target_handle,
    p.display_name as target_display_name,
    p.avatar_url as target_avatar_url,
    p.bio as target_bio,
    coalesce((
      select m.body
      from public.direct_messages m
      where m.conversation_id = c.id
      order by m.created_at desc
      limit 1
    ), 'Tap to chat') as last_message,
    coalesce((
      select m.created_at
      from public.direct_messages m
      where m.conversation_id = c.id
      order by m.created_at desc
      limit 1
    ), c.created_at) as updated_at
  from public.direct_conversations c
  join public.direct_conversation_members mine
    on mine.conversation_id = c.id
  join public.direct_conversation_members other
    on other.conversation_id = c.id
  join public.profiles p
    on p.id = other.user_id
  where mine.user_id = (select auth.uid())
    and other.user_id <> (select auth.uid())
  order by updated_at desc;
$$;

revoke all on function public.get_recent_conversations() from PUBLIC, anon;
grant execute on function public.get_recent_conversations() to authenticated;

alter table public.direct_conversations enable row level security;
alter table public.direct_conversation_members enable row level security;
alter table public.direct_messages enable row level security;

drop policy if exists "dm conversations readable by members" on public.direct_conversations;
drop policy if exists "members can read direct_conversations" on public.direct_conversations;
drop policy if exists "users create own direct_conversations" on public.direct_conversations;
drop policy if exists "dm conversations readable by friends" on public.direct_conversations;

drop policy if exists "dm members readable by members" on public.direct_conversation_members;
drop policy if exists "members can read direct_conversation_members" on public.direct_conversation_members;
drop policy if exists "users can insert direct_conversation_members safely" on public.direct_conversation_members;
drop policy if exists "users can delete own direct_conversation_members" on public.direct_conversation_members;
drop policy if exists "dm members readable by friends" on public.direct_conversation_members;

drop policy if exists "dm messages readable by members" on public.direct_messages;
drop policy if exists "members can read direct_messages" on public.direct_messages;
drop policy if exists "dm members send messages" on public.direct_messages;
drop policy if exists "members can insert direct_messages" on public.direct_messages;
drop policy if exists "dm messages readable by friends" on public.direct_messages;
drop policy if exists "friends send direct messages" on public.direct_messages;

create policy "dm conversations readable by friends"
on public.direct_conversations for select
to authenticated
using (private.can_access_direct_conversation(id, (select auth.uid())));

create policy "dm members readable by friends"
on public.direct_conversation_members for select
to authenticated
using (private.can_access_direct_conversation(conversation_id, (select auth.uid())));

create policy "dm messages readable by friends"
on public.direct_messages for select
to authenticated
using (private.can_access_direct_conversation(conversation_id, (select auth.uid())));

create policy "friends send direct messages"
on public.direct_messages for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and private.can_access_direct_conversation(conversation_id, (select auth.uid()))
);

grant select on public.profiles,
  public.direct_conversations, public.direct_conversation_members, public.direct_messages
to authenticated;
grant insert on public.direct_messages to authenticated;

commit;

select schemaname, tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('direct_conversations', 'direct_conversation_members', 'direct_messages')
order by tablename, policyname;

-- Snap Likes and Comments
create table if not exists public.snap_likes (
  id uuid primary key default gen_random_uuid(),
  snap_id uuid not null references public.snaps(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (snap_id, user_id)
);

create table if not exists public.snap_comments (
  id uuid primary key default gen_random_uuid(),
  snap_id uuid not null references public.snaps(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists snap_likes_snap_id_idx on public.snap_likes(snap_id);
create index if not exists snap_likes_user_id_idx on public.snap_likes(user_id);
create index if not exists snap_comments_snap_id_created_at_idx on public.snap_comments(snap_id, created_at);

alter table public.snap_likes enable row level security;
alter table public.snap_comments enable row level security;

drop policy if exists "snap likes readable" on public.snap_likes;
drop policy if exists "users create own snap likes" on public.snap_likes;
drop policy if exists "users delete own snap likes" on public.snap_likes;
drop policy if exists "snap comments readable" on public.snap_comments;
drop policy if exists "users create own snap comments" on public.snap_comments;
drop policy if exists "users delete own snap comments" on public.snap_comments;

create policy "snap likes readable"
on public.snap_likes for select
to authenticated
using (
  exists (
    select 1 from public.snaps s
    where s.id = snap_likes.snap_id
  )
);

create policy "users create own snap likes"
on public.snap_likes for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy "users delete own snap likes"
on public.snap_likes for delete
to authenticated
using (user_id = (select auth.uid()));

create policy "snap comments readable"
on public.snap_comments for select
to authenticated
using (
  exists (
    select 1 from public.snaps s
    where s.id = snap_comments.snap_id
  )
);

create policy "users create own snap comments"
on public.snap_comments for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy "users delete own snap comments"
on public.snap_comments for delete
to authenticated
using (user_id = (select auth.uid()));

grant select, insert, delete on public.snap_likes, public.snap_comments to authenticated;

create or replace function public.get_snap_stats(p_snap_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_likes_count int;
  v_comments_count int;
  v_has_liked boolean;
begin
  select count(*) into v_likes_count from public.snap_likes where snap_id = p_snap_id;
  select count(*) into v_comments_count from public.snap_comments where snap_id = p_snap_id;
  select exists(select 1 from public.snap_likes where snap_id = p_snap_id and user_id = p_user_id) into v_has_liked;

  return jsonb_build_object(
    'likes_count', v_likes_count,
    'comments_count', v_comments_count,
    'has_liked', v_has_liked
  );
end;
$$;

create or replace function public.get_public_snaps_with_stats(p_user_id uuid)
returns setof jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, pg_temp
as $$
begin
  return query
  select jsonb_build_object(
    'snap', to_jsonb(s),
    'likes_count', (select count(*) from public.snap_likes sl where sl.snap_id = s.id),
    'comments_count', (select count(*) from public.snap_comments sc where sc.snap_id = s.id),
    'has_liked', exists(select 1 from public.snap_likes sl where sl.snap_id = s.id and sl.user_id = p_user_id)
  )
  from public.snaps s
  where s.is_public = true
  order by s.created_at desc
  limit 100;
end;
$$;

revoke all on function public.get_snap_stats(uuid, uuid) from PUBLIC, anon;
revoke all on function public.get_public_snaps_with_stats(uuid) from PUBLIC, anon;
grant execute on function public.get_snap_stats(uuid, uuid) to authenticated;
grant execute on function public.get_public_snaps_with_stats(uuid) to authenticated;
