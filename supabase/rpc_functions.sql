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

create or replace function public.create_direct_conversation(target_user_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_current_user_id uuid := auth.uid();
  v_target_user_id uuid := target_user_id;
  v_existing_conversation_id uuid;
  v_conversation_id uuid;
begin
  if v_current_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if v_target_user_id is null or v_target_user_id = v_current_user_id then
    raise exception 'Choose another profile to message.' using errcode = '22023';
  end if;

  if not exists (select 1 from public.profiles where id = v_current_user_id) then
    raise exception 'Current profile not found.' using errcode = 'P0002';
  end if;

  if not exists (select 1 from public.profiles where id = v_target_user_id) then
    raise exception 'Target profile not found.' using errcode = 'P0002';
  end if;

  select mine.conversation_id
  into v_existing_conversation_id
  from public.direct_conversation_members mine
  join public.direct_conversation_members target
    on target.conversation_id = mine.conversation_id
  where mine.user_id = v_current_user_id
  and target.user_id = v_target_user_id
  limit 1;

  if v_existing_conversation_id is not null then
    return v_existing_conversation_id;
  end if;

  insert into public.direct_conversations default values
  returning id into v_conversation_id;

  insert into public.direct_conversation_members (conversation_id, user_id)
  values (v_conversation_id, v_current_user_id);

  insert into public.direct_conversation_members (conversation_id, user_id)
  values (v_conversation_id, v_target_user_id);

  return v_conversation_id;
end;
$$;

revoke all on function public.create_direct_conversation(uuid) from public, anon;
grant execute on function public.create_direct_conversation(uuid) to authenticated;
