create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke execute on function public.set_updated_at() from public, anon, authenticated;

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
      select body from public.direct_messages m
      where m.conversation_id = c.id
      order by created_at desc limit 1
    ), 'Tap to chat') as last_message,
    coalesce((
      select created_at from public.direct_messages m
      where m.conversation_id = c.id
      order by created_at desc limit 1
    ), c.created_at) as updated_at
  from public.direct_conversations c
  join public.direct_conversation_members mine on mine.conversation_id = c.id
  join public.direct_conversation_members other on other.conversation_id = c.id
  join public.profiles p on p.id = other.user_id
  where mine.user_id = (select auth.uid())
    and other.user_id <> (select auth.uid())
  order by updated_at desc;
$$;

revoke all on function public.get_recent_conversations() from PUBLIC, anon;
grant execute on function public.get_recent_conversations() to authenticated;

create or replace function get_snap_stats(p_snap_id uuid, p_user_id uuid)
returns jsonb as $$
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
$$ language plpgsql security definer;

create or replace function get_public_snaps_with_stats(p_user_id uuid)
returns setof jsonb as $$
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
$$ language plpgsql security definer;
