# Pointward — RLS Policy Audit  [7/6 · 2]

Audit of every table in `public`, derived from `supabase/setup.sql`. Re-run
the live check after `supabase login` with the SQL in the last section.

## Status: ✅ All tables have RLS enabled. No table is unintentionally exposed.

| Table | RLS | SELECT | INSERT | UPDATE | DELETE | Notes |
|-------|-----|--------|--------|--------|--------|-------|
| `users` | ✅ | public (`true`) | self only (`auth.uid() = id`) | self only | — (no policy ⇒ denied) | public read is intentional: names/emoji for pairing |
| `connections` | ✅ | public (`true`) | owner only | claim: friend fills self in | — | see ⚠️ below |
| `pings` | ✅ | from **or** to only | sender = self | recipient marks felt | — | correctly private to the two parties |
| `device_tokens` | ✅ | owner only (`for all`) | owner only | owner only | owner only | fully private ✓ |
| `compass_bearings` | ✅ | public (`true`) | owner only | owner only | owner only (added by client cleanup) | public read is intentional: partner presence |
| `giving` | ✅ | public (`true`) | — (denied) | — (denied) | — | read-only donation total ✓ |

### Gaps / observations

- ⚠️ **`connections` SELECT is `using (true)`** — any authenticated user can
  read every pairing row, which includes `code`, `person_name`, `person_emoji`.
  Pairing codes are short-lived claim tokens, but this does leak invitee names
  to anyone who scans the table. **Recommended tightening** (optional, behavioural
  change — a stranger redeeming by code must still be able to read the row):

  ```sql
  drop policy "connections read" on public.connections;
  create policy "connections read"
    on public.connections for select
    using ( auth.uid() in (owner, friend)            -- the two parties
            or friend is null );                      -- still-open invites (redeemable)
  ```

- ✅ No table is missing `enable row level security`.
- ✅ No `for all using (true)` (world-writable) policy anywhere.
- ✅ The only write paths are self-scoped (`auth.uid() = …`); the public
  `using (true)` policies are **SELECT-only** and intentional (presence + pairing).
- ✅ `device_tokens` (the most sensitive — APNs tokens) is fully owner-scoped.

### Live verification query (run in the SQL editor after `supabase login`)

```sql
-- Any table WITHOUT row-level security is a red flag:
select relname as table, relrowsecurity as rls_enabled
  from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r'
 order by relrowsecurity, relname;

-- Every policy, with its USING / WITH CHECK expressions:
select schemaname, tablename, policyname, cmd, qual, with_check
  from pg_policies
 where schemaname = 'public'
 order by tablename, cmd;
```

Expected: `rls_enabled = true` for **every** row of the first query.
