-- [conn-reconnect-fix] record_connection: on reconnect (sender re-sends after a delete), the
-- (sender_id, connected_user_id) row must track the NEWEST connecting message — previously
-- `on conflict do nothing` kept the FIRST via_message_id, leaving the sender un-greened on
-- delete→reconnect (the join key went stale). UPSERT the via + connected_at instead.
-- `create or replace` = idempotent / reversible (re-apply the `do nothing` body to revert).
-- NOTE: supabase_realtime broadcasts INSERTs only, so a conflict-UPDATE does NOT fire a live
-- event — the sender re-greens on the next sync (foreground/relaunch), not live. A follow-up
-- (link_connections UPDATE subscription) would give live reconnect re-green; not built here.

create or replace function public.record_connection(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare s uuid;
begin
  if auth.uid() is null then return; end if;              -- unauth open → no-op
  select sender_id into s from public.messages where id = p_message_id;
  if s is null or s = auth.uid() then return; end if;     -- missing / self-send → skip
  insert into public.link_connections (sender_id, connected_user_id, via_message_id)
  values (s, auth.uid(), p_message_id)
  on conflict (sender_id, connected_user_id)
  do update set via_message_id = excluded.via_message_id,  -- [conn-reconnect-fix] track NEWEST
                connected_at    = now();
end;
$$;
