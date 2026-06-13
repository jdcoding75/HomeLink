-- Pointward — Phase 2: per-user short_code + messages table (link delivery)
--
-- Apply with:  supabase login  &&  supabase db push
-- or paste into the Supabase SQL editor (Dashboard → SQL).
--
-- ⚠️ NOT YET APPLIED — the CLI login tokens are revoked, so this build cannot
-- run it. Build 3 is BLOCKED until this is applied and confirmed.
--
-- Idempotent: every statement guards with IF NOT EXISTS / OR REPLACE /
-- drop-if-exists, so it is safe to run repeatedly.
--
-- ADDITIVE ONLY. Does NOT touch the existing pairing path (connections,
-- POINT-XXXX `code`) or the pings table. short_code is a NEW, SEPARATE random
-- code — it is NOT derived from users.id and is NOT the pairing code.

-- ════════════════════════════════════════════════════════════════════════
-- 1 · SHORT CODE — a per-user, human-typable fallback code
-- ════════════════════════════════════════════════════════════════════════
--
-- Charset (31 chars): uppercase A–Z and digits 2–9, with the visually
-- ambiguous characters removed — no 0/O, no 1/I/L. So:
--   ABCDEFGHJKMNPQRSTUVWXYZ  (23 letters: A–Z minus I, L, O)
--   23456789                 (8 digits: 0 and 1 removed)
-- 6 chars → 31^6 ≈ 887 million combinations.
--
-- Generation is DATABASE-SIDE: gen_short_code() mints a random candidate,
-- mint_unique_short_code() retries until the candidate is unused. The latter is
-- the column DEFAULT (new rows) and the backfill source (existing rows).

-- A single random 6-char candidate from the unambiguous charset.
create or replace function public.gen_short_code()
returns text
language sql
volatile
set search_path = public, pg_temp
as $$
  select string_agg(
           substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789',
                  floor(random() * 31)::int + 1, 1),
           '')
    from generate_series(1, 6);
$$;

-- A guaranteed-unique short code: retry on collision (bounded), the UNIQUE
-- index below is the final backstop against any concurrent race.
create or replace function public.mint_unique_short_code()
returns text
language plpgsql
volatile
set search_path = public, pg_temp
as $$
declare
  candidate text;
  tries     int := 0;
begin
  loop
    candidate := public.gen_short_code();
    exit when not exists (select 1 from public.users where short_code = candidate);
    tries := tries + 1;
    if tries > 100 then
      raise exception 'could not mint a unique short_code after % tries', tries;
    end if;
  end loop;
  return candidate;
end;
$$;

-- Add the column with NO default first (avoids a volatile-default table rewrite
-- whose per-row uniqueness check can't see the in-flight values).
alter table public.users add column if not exists short_code text;

-- Backfill existing rows ONE AT A TIME so each mint sees the codes already set
-- earlier in this same transaction (collision-safe; a single bulk UPDATE could
-- not see its own in-flight rows).
do $$
declare r record;
begin
  for r in select id from public.users where short_code is null loop
    update public.users set short_code = public.mint_unique_short_code()
     where id = r.id;
  end loop;
end $$;

-- New rows mint their own code automatically (single-row insert sees every
-- committed code, so it is collision-safe; UNIQUE index backstops any race).
alter table public.users alter column short_code set default public.mint_unique_short_code();

-- Uniqueness + NOT NULL going forward (safe now that every row is backfilled).
create unique index if not exists idx_users_short_code on public.users (short_code);
alter table public.users alter column short_code set not null;

-- ════════════════════════════════════════════════════════════════════════
-- 2 · MESSAGES — the link-delivery record (the /m/[id] target)
-- ════════════════════════════════════════════════════════════════════════
create table if not exists public.messages (
  id                  uuid primary key default gen_random_uuid(),  -- messageID in /m/[id]
  sender_id           uuid not null references public.users(id) on delete cascade,
  sender_display_name text,           -- snapshot at send time (denormalized:
                                      -- opening a message never reads another
                                      -- user's row)
  content             text,
  emoji               text,
  instrument          text,
  opened              boolean default false,  -- flipped only when the animation
                                              -- truly plays (wired in a later build)
  opened_at           timestamptz,            -- Phase 3 "opened" notification
  created_at          timestamptz default now()  -- enables expiry later
);

-- Index: the short-code fallback fetches a sender's messages.
create index if not exists idx_messages_sender on public.messages (sender_id);
-- Index: "unopened messages for a sender, newest first" (partial — only the
-- rows the fallback actually scans).
create index if not exists idx_messages_unopened_sender
  on public.messages (sender_id, created_at desc)
  where opened = false;

-- NOTE: messages is intentionally NOT added to the supabase_realtime
-- publication — Phase 2 removed push from the send flow; the iOS share-sheet
-- message IS the notification.

-- ════════════════════════════════════════════════════════════════════════
-- 3 · RLS — NO public read. Sender-scoped policies + two SECURITY DEFINER
--     read functions are the ONLY anon-reachable reads (no list/browse).
-- ════════════════════════════════════════════════════════════════════════
alter table public.messages enable row level security;

-- Sender (authenticated) may INSERT and SELECT only their own rows.
drop policy if exists "messages insert own" on public.messages;
create policy "messages insert own" on public.messages
  for insert with check (auth.uid() = sender_id);

drop policy if exists "messages read own" on public.messages;
create policy "messages read own" on public.messages
  for select using (auth.uid() = sender_id);

-- (No SELECT policy for anon — recipients reach messages ONLY through the two
--  SECURITY DEFINER functions below, which bypass RLS as the function owner.)

-- a) get_message(p_id): the single message behind a /m/[id] link.
create or replace function public.get_message(p_id uuid)
returns setof public.messages
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select * from public.messages where id = p_id limit 1;
$$;

-- b) get_unopened_for_short_code(p_code): resolve the typed code to its sender
--    and return that sender's unopened messages, newest first. Case-insensitive
--    (codes are stored uppercase). Returns nothing for an unknown code.
create or replace function public.get_unopened_for_short_code(p_code text)
returns setof public.messages
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select m.*
    from public.messages m
    join public.users u on u.id = m.sender_id
   where u.short_code = upper(p_code)
     and m.opened = false
   order by m.created_at desc;
$$;

-- Lock the functions down to exactly anon + authenticated (revoke the implicit
-- PUBLIC grant first). These two functions are the ONLY anon read surface.
revoke all on function public.get_message(uuid) from public;
revoke all on function public.get_unopened_for_short_code(text) from public;
grant execute on function public.get_message(uuid) to anon, authenticated;
grant execute on function public.get_unopened_for_short_code(text) to anon, authenticated;
