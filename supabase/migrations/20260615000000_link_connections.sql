-- Pointward — Phase 2 Stage B: link_connections (the bilateral connection signal)
-- ADDITIVE ONLY. References users(id) + messages(id); touches no existing table's data.

create table if not exists public.link_connections (
  sender_id          uuid not null references public.users(id)    on delete cascade,
  connected_user_id  uuid not null references public.users(id)    on delete cascade,
  via_message_id     uuid          references public.messages(id) on delete set null,
  connected_at       timestamptz not null default now(),
  primary key (sender_id, connected_user_id)         -- idempotency (Case 3/4)
);
create index if not exists idx_link_conn_sender on public.link_connections (sender_id);

-- RLS: the SENDER reads only their own rows. No direct INSERT policy — the only
-- writer is record_connection() (SECURITY DEFINER), so receivers can't forge rows.
alter table public.link_connections enable row level security;
drop policy if exists "link_conn read own" on public.link_connections;
create policy "link_conn read own" on public.link_connections
  for select using (auth.uid() = sender_id);

-- record_connection(p_message_id): the receiver records "I (auth.uid) connected to the
-- sender of message p_id." connected_user_id is FORCED to auth.uid() (unforgeable);
-- sender_id is read server-side from the message row (unforgeable). AUTHENTICATED only.
create or replace function public.record_connection(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare s uuid;
begin
  if auth.uid() is null then return; end if;              -- unauth open → no-op (Case 2)
  select sender_id into s from public.messages where id = p_message_id;
  if s is null or s = auth.uid() then return; end if;      -- missing / self-send → skip
  insert into public.link_connections (sender_id, connected_user_id, via_message_id)
  values (s, auth.uid(), p_message_id)
  on conflict (sender_id, connected_user_id) do nothing;   -- idempotent; keeps FIRST via
end;
$$;

revoke all on function public.record_connection(uuid) from public;
grant execute on function public.record_connection(uuid) to authenticated;  -- NOT anon
