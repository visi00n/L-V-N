create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text not null,
  bio text default '',
  avatar_url text,
  is_private boolean not null default false,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'approved',
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  details text not null default '',
  category text not null default 'Social',
  starts_at timestamptz not null,
  ends_at timestamptz,
  location_name text not null,
  latitude double precision not null,
  longitude double precision not null,
  is_paid boolean not null default false,
  price_cents integer,
  capacity integer,
  cover_image_path text,
  is_public boolean not null default true,
  invite_token text,
  color_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.event_members (
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  status text not null default 'active',
  joined_at timestamptz default now(),
  primary key (event_id, user_id)
);

create table if not exists public.event_messages (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  message_type text not null default 'text',
  body text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.snaps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  attached_event_id uuid references public.events(id) on delete set null,
  caption text not null,
  location jsonb,
  location_name text not null,
  latitude double precision not null,
  longitude double precision not null,
  first_media_path text not null,
  media_count integer not null default 1,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.snap_media (
  id uuid primary key default gen_random_uuid(),
  snap_id uuid not null references public.snaps(id) on delete cascade,
  storage_path text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.direct_conversations (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.direct_conversation_members (
  conversation_id uuid not null references public.direct_conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.direct_conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null,
  target_id uuid not null,
  reason text not null,
  details text default '',
  created_at timestamptz not null default now()
);

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null default 'ios',
  environment text not null default 'sandbox',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

create index if not exists follows_following_id_idx on public.follows(following_id);
create index if not exists follows_status_idx on public.follows(status);
create index if not exists events_host_id_idx on public.events(host_id);
create index if not exists events_starts_at_idx on public.events(starts_at);
create unique index if not exists events_invite_token_key on public.events(invite_token) where invite_token is not null;
create index if not exists events_visibility_starts_idx on public.events(is_public, starts_at desc);
create index if not exists events_ends_at_idx on public.events(ends_at);
create index if not exists events_created_at_idx on public.events(created_at desc);
create index if not exists events_location_idx on public.events(latitude, longitude);
create index if not exists event_members_user_id_idx on public.event_members(user_id);
create index if not exists event_messages_event_id_created_at_idx on public.event_messages(event_id, created_at);
create index if not exists event_messages_sender_id_idx on public.event_messages(sender_id);
create index if not exists snaps_user_id_created_at_idx on public.snaps(user_id, created_at);
create index if not exists snaps_attached_event_id_idx on public.snaps(attached_event_id);
create index if not exists snaps_is_public_idx on public.snaps(is_public);
create index if not exists snap_media_snap_id_sort_order_idx on public.snap_media(snap_id, sort_order);
create index if not exists direct_conversations_created_by_idx on public.direct_conversations(created_by);
create index if not exists direct_conversation_members_user_id_idx on public.direct_conversation_members(user_id);
create index if not exists direct_messages_conversation_id_created_at_idx on public.direct_messages(conversation_id, created_at);
create index if not exists direct_messages_sender_id_idx on public.direct_messages(sender_id);
create index if not exists reports_reporter_id_idx on public.reports(reporter_id);
create index if not exists device_tokens_user_id_idx on public.device_tokens(user_id);

alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.events enable row level security;
alter table public.event_members enable row level security;
alter table public.event_messages enable row level security;
alter table public.snaps enable row level security;
alter table public.snap_media enable row level security;
alter table public.direct_conversations enable row level security;
alter table public.direct_conversation_members enable row level security;
alter table public.direct_messages enable row level security;
alter table public.reports enable row level security;
alter table public.device_tokens enable row level security;

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
