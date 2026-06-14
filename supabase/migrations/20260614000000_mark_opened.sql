-- Pointward — Phase 2 Build 4a: mark_opened(p_id) — flip a message's opened flag
--
-- Apply with:  supabase login  &&  supabase db push   (or paste into the Supabase
-- SQL editor: Dashboard → SQL).
--
-- ⚠️ NOT YET APPLIED — flag for Joshua to run (same as Build 2's migration). The
-- CLI login tokens are revoked, so this build cannot run it. Opening a /m/ link
-- will still fetch + animate (get_message landed in Build 2's migration), but the
-- opened-flip is a DB no-op until THIS function exists — the message simply stays
-- recoverable, which is the intended fail-safe.
--
-- Idempotent: create-or-replace + revoke/grant are safe to run repeatedly.
-- ADDITIVE ONLY. Does NOT touch pairing (connections / POINT-XXXX), pings, the
-- messages table, or the existing read functions (get_message /
-- get_unopened_for_short_code).

-- mark_opened(p_id): flip a message to opened = true (+ stamp opened_at) exactly
-- once. SECURITY DEFINER so the recipient opening the link — who may be
-- UNAUTHENTICATED, or a DIFFERENT user than the sender (the row owner) — can mark
-- it, bypassing RLS as the function owner. The `and opened = false` guard makes
-- it idempotent: re-opening an already-opened message never re-stamps opened_at.
create or replace function public.mark_opened(p_id uuid)
returns void
language sql
volatile
security definer
set search_path = public, pg_temp
as $$
  update public.messages
     set opened = true,
         opened_at = now()
   where id = p_id
     and opened = false;
$$;

-- Lock down to exactly anon + authenticated (revoke the implicit PUBLIC grant
-- first), mirroring the get_message / get_unopened_for_short_code lockdown.
revoke all on function public.mark_opened(uuid) from public;
grant execute on function public.mark_opened(uuid) to anon, authenticated;
