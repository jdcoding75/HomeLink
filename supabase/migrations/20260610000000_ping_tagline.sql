-- Tagline travels with each thought — the sender's per-person tagline.
-- Apply: `supabase db push` (or run in the SQL editor).
alter table public.pings
  add column if not exists tagline text;

do $$
begin
  if not exists (
    select 1 from information_schema.constraint_column_usage
    where table_name = 'pings' and constraint_name = 'pings_tagline_len'
  ) then
    alter table public.pings
      add constraint pings_tagline_len check (char_length(tagline) <= 80);
  end if;
end $$;
