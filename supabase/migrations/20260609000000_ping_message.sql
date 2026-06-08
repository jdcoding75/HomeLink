-- [5/5] Optional short message attached to a thought.
-- Apply: `supabase db push` (or run in the SQL editor).
alter table public.pings
  add column if not exists message text;

-- Keep it short — the UI caps at 30 chars; enforce a sane server bound too.
do $$
begin
  if not exists (
    select 1 from information_schema.constraint_column_usage
    where table_name = 'pings' and constraint_name = 'pings_message_len'
  ) then
    alter table public.pings
      add constraint pings_message_len check (char_length(message) <= 140);
  end if;
end $$;
