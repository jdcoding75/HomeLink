-- Pointward — backend hardening [7/6]
--
-- Apply with:  supabase login  &&  supabase db push
-- or paste into the Supabase SQL editor (Dashboard → SQL).
--
-- Idempotent: every statement guards with IF NOT EXISTS / OR REPLACE, so it
-- is safe to run repeatedly.

-- ════════════════════════════════════════════════════════════════════════
-- [7/6 · 3] INDEXES — speed up the hot-path queries at scale
-- ════════════════════════════════════════════════════════════════════════

-- Inbox + offline-sync sweep: "unread pings addressed to me"
create index if not exists idx_pings_to_user_opened
  on public.pings (to_user, opened_at);
-- Felt-receipt + history lookups by sender
create index if not exists idx_pings_from_user
  on public.pings (from_user);
-- Pairing lookups from both sides
create index if not exists idx_connections_owner
  on public.connections (owner);
create index if not exists idx_connections_friend
  on public.connections (friend);
-- Push token lookups + the 60-day cleanup sweep
create index if not exists idx_device_tokens_user
  on public.device_tokens (user_id);
-- compass_bearings.user_id is already the primary key (indexed); this one
-- serves the hourly staleness sweep below.
create index if not exists idx_compass_bearings_updated
  on public.compass_bearings (updated_at);

-- ════════════════════════════════════════════════════════════════════════
-- [7/6 · 1] STALE DATA CLEANUP — called on app launch via RPC
-- ════════════════════════════════════════════════════════════════════════

-- Connections gain an `active` flag so stale pairings can be retired without
-- destroying the row (history/links stay intact).
alter table public.connections
  add column if not exists active boolean default true;

-- SECURITY DEFINER so any signed-in client can trigger maintenance; the body
-- only ever removes objectively-stale rows, so this is safe to expose.
create or replace function public.cleanup_stale_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- 1 · compass bearings older than 1 hour are stale location data → delete
  delete from public.compass_bearings
   where updated_at < now() - interval '1 hour';

  -- 2 · device tokens not refreshed in 60 days are dead → delete
  delete from public.device_tokens
   where updated_at < now() - interval '60 days';

  -- 3a · unclaimed pairing invites older than 30 days are abandoned → delete
  delete from public.connections
   where friend is null
     and created_at < now() - interval '30 days';

  -- 3b · claimed connections with NO ping in 30 days → mark inactive
  update public.connections c
     set active = false
   where c.friend is not null
     and c.active is distinct from false
     and c.created_at < now() - interval '30 days'
     and not exists (
       select 1 from public.pings p
        where p.created_at > now() - interval '30 days'
          and ((p.from_user = c.owner  and p.to_user = c.friend)
            or (p.from_user = c.friend and p.to_user = c.owner))
     );
end;
$$;

grant execute on function public.cleanup_stale_data() to authenticated;

-- OPTIONAL — if pg_cron is enabled, also run the sweep server-side nightly so
-- it never depends on a client opening the app:
--   select cron.schedule('pointward-cleanup', '17 4 * * *',
--                         $$ select public.cleanup_stale_data(); $$);
