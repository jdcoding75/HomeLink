-- Pointward Phase 2 — minimum backend schema
-- Run in the Supabase SQL editor (Dashboard → SQL).

-- ── users ─────────────────────────────────────────────────────────────
create table if not exists public.users (
  id            uuid primary key references auth.users(id) on delete cascade,
  apple_user_id text,
  last_seen     timestamptz default now(),   -- presence: "active recently"
  created_at    timestamptz default now()
);
alter table public.users add column if not exists last_seen timestamptz default now();
alter table public.users enable row level security;
create policy "users insert self"  on public.users for insert with check (auth.uid() = id);
create policy "users update self"  on public.users for update using (auth.uid() = id);
create policy "users read"         on public.users for select using (true);

-- ── connections (pairing codes) ───────────────────────────────────────
create table if not exists public.connections (
  code            text primary key,
  owner           uuid not null references public.users(id) on delete cascade,
  friend          uuid references public.users(id) on delete set null,
  person_name     text,        -- identity the invite travels with
  person_emoji    text,
  owner_person_id uuid,        -- the owner's local Person.id, to re-link
  created_at      timestamptz default now()
);
alter table public.connections add column if not exists person_name text;
alter table public.connections add column if not exists person_emoji text;
alter table public.connections add column if not exists owner_person_id uuid;
alter table public.connections enable row level security;
create policy "connections read"       on public.connections for select using (true);
create policy "connections insert own" on public.connections for insert with check (auth.uid() = owner);
create policy "connections claim"      on public.connections for update
  using (friend is null or auth.uid() in (owner, friend))
  with check (auth.uid() = friend);

-- ── pings ─────────────────────────────────────────────────────────────
create table if not exists public.pings (
  id           uuid primary key default gen_random_uuid(),
  from_user    uuid not null references public.users(id) on delete cascade,
  to_user      uuid not null references public.users(id) on delete cascade,
  emoji        text not null,
  sender_style text default 'glow',          -- glow | shootingStar | firefly
  opened_at    timestamptz,                  -- read receipt ("felt ✓")
  created_at   timestamptz default now()
);
alter table public.pings add column if not exists opened_at timestamptz;
alter table public.pings add column if not exists sender_style text default 'glow';
alter table public.pings enable row level security;
create policy "pings send as self" on public.pings for insert with check (auth.uid() = from_user);
create policy "pings read own"     on public.pings for select
  using (auth.uid() = to_user or auth.uid() = from_user);
create policy "pings mark felt"    on public.pings for update
  using (auth.uid() = to_user) with check (auth.uid() = to_user);

-- Realtime: the app subscribes to inserts on pings
alter publication supabase_realtime add table public.pings;

-- ── device tokens (for push) ──────────────────────────────────────────
create table if not exists public.device_tokens (
  token      text primary key,
  user_id    uuid not null references public.users(id) on delete cascade,
  platform   text default 'ios',
  updated_at timestamptz default now()
);
alter table public.device_tokens enable row level security;
create policy "tokens own" on public.device_tokens for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
