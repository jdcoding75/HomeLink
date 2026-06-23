-- Pointward — Phase 2 P2: one-directional disconnect (Option A).
-- ADDITIVE: a DELETE RLS policy so the SENDER can delete THEIR OWN link_connections
-- rows (sender_id = auth.uid()). One-directional only — the reciprocal row
-- (sender_id = the other user) is PARKED (bilateral would need a SECURITY DEFINER RPC).
-- No table/column/data changes; no SECURITY DEFINER.

drop policy if exists "link_conn delete own" on public.link_connections;
create policy "link_conn delete own" on public.link_connections
  for delete using (auth.uid() = sender_id);
