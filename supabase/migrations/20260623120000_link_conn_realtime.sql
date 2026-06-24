-- P3 realtime: broadcast link_connections INSERTs so the sender gets a live event
-- (the publication was missing this table → no realtime broadcast → sender never re-greened).
-- APPLIED LIVE 2026-06-23 (via Supabase SQL); this file tracks it in the repo.
-- Idempotent: skips if the table is already in the publication (re-runnable safely).

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'link_connections'
  ) then
    alter publication supabase_realtime add table public.link_connections;
  end if;
end $$;
