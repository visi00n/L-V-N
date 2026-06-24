do $$
declare
  live_table regclass;
begin
  foreach live_table in array array[
    'public.snaps'::regclass,
    'public.events'::regclass,
    'public.event_members'::regclass,
    'public.event_messages'::regclass,
    'public.direct_messages'::regclass,
    'public.follows'::regclass
  ]
  loop
    begin
      execute format('alter publication supabase_realtime add table %s', live_table);
    exception
      when duplicate_object then
        null;
    end;
  end loop;
end $$;
