-- Pointward — owner profile on invites
-- The invite a person creates now carries THEIR profile (name · emoji ·
-- location), so accepting auto-builds a pre-filled person card. Name & emoji
-- already ride in person_name / person_emoji; this adds the owner's location.
--
-- Run in the Supabase SQL editor (Dashboard → SQL). All statements are
-- idempotent — safe to run more than once. The app degrades gracefully if
-- these columns are absent (it just omits the location until they exist).

-- ── connections: the owner's location, shared on accept ─────────────────
alter table public.connections add column if not exists owner_latitude  double precision;
alter table public.connections add column if not exists owner_longitude double precision;

-- ── users: the self profile (optional mirror of the SwiftData profile) ──
alter table public.users add column if not exists display_name text;
alter table public.users add column if not exists emoji        text;
alter table public.users add column if not exists latitude     double precision;
alter table public.users add column if not exists longitude    double precision;
