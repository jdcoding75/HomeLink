# Track 2 — Push-Chain Reliability: Stale Device Tokens (audit + fix)

_Audit-then-fix. The permanent fix (edge-function self-prune) IS implemented + deploy-ready. The
app-side `updated_at` gap is REPORTED, not bundled (touches the push-critical registration path —
flagged for a decision). No app code changed → no Xcode build needed; tests unaffected._

## Symptom
APNs logs show **56 device_tokens for one user — 53 dead (410 Unregistered), 3 live (200)**. Tokens
never get pruned. Each push fans out to ALL of a user's token rows (`sendPush` → `Promise.all` over
`tokens`), so a single ping = ~56 APNs calls (dead ones do 2 each via the prod→sandbox fallback ≈
106 calls), 53 failures logged. Delivery still reaches the live tokens, but it's wasteful, noisy,
and risks APNs rate-limiting.

---

## AUDIT FINDINGS

### 1. Edge function LOGS 410s but does NOT delete (confirmed)
`supabase/functions/send-ping-notification/index.ts`, the results handling (pre-fix lines 115-131):
```ts
const results = await Promise.all(tokens.map(async (t) => {
  const first = await pushToDevice(order[0], t.token, jwt, topic, aps);   // prod
  if (first === 400 || first === 410) {
    const second = await pushToDevice(order[1], t.token, jwt, topic, aps); // sandbox fallback
    return { token: t.token.slice(0, 8), first, second };
  }
  return { token: t.token.slice(0, 8), first };
}));
console.log("push chain ⑤ APNs:", JSON.stringify(results));
const failures = results.filter((r) => (r.second ?? r.first) !== 200);
if (failures.length > 0) {
  console.error(`push chain ⑤ APNs: ${failures.length} device(s) FAILED — …`);  // ← only LOGS
}
```
A 410/400 is **only logged** (the `failures` line) — there is **no `delete` on `device_tokens`**.
The full token is also discarded (`t.token.slice(0, 8)`), so even if you wanted to prune you only
had the prefix. → dead tokens persist forever.

### 2. `device_tokens` table + insert/update path
**Schema** (`supabase/setup.sql:65-70`):
| column | type | note |
|--------|------|------|
| `token` | text | **PRIMARY KEY** |
| `user_id` | uuid | NOT NULL → `users(id)` **ON DELETE CASCADE** |
| `platform` | text | default `'ios'` |
| `updated_at` | timestamptz | default `now()` |
Index `idx_device_tokens_user (user_id)` (`hardening.sql:25`). RLS: `auth.uid() = user_id`.

**Insert/update** — `SupabaseService+Maintenance.swift:38-64` `registerDeviceToken`:
`client.from("device_tokens").upsert(DeviceTokenRow(token, userID, platform))`. The upsert key is
the **`token` PK**. So:
- Re-registering the **same** token → conflict-update (idempotent, one row). ⚠️ **BUT `DeviceTokenRow`
  (lines 19-29) does NOT include `updated_at`** → on a conflict-update `updated_at` is **never
  bumped** (stays at first-insert time).
- A **new** token string (fresh install / restore / some OS updates) → a **brand-new row**. The old
  token's row is **never removed** by the app.

### 3. Fresh-install timing + accumulation (honest assessment)
**Timing — adequate.** `AppDelegate.didFinishLaunching` calls `registerForRemoteNotifications()` every
launch (AppDelegate.swift:19); on token receipt → `registerDeviceToken` (AppDelegate.swift:73-80).
`registerDeviceToken` caches the token locally, then upserts **only if signed in**; if not signed in
it **defers** (cached) and is replayed by `registerCachedDeviceTokenIfNeeded` — called **after
`ensureUser`** (post-sign-in, `+Auth.swift:94`) **and on every foreground** (`RootView.swift:179`).
A fresh installer signs in during onboarding (screen 0), so the token uploads right after sign-in —
**before they can meaningfully receive** (you must be a signed-in user to be a recipient). The only
true gap is the brief window between APNs delivering the token and sign-in completing; a push in that
window misses, but the user isn't a known recipient yet.

**Accumulation — CONFIRMED, this is the real problem.** Because the upsert key is the **token string**,
every new token = a new row and **old tokens are never superseded**. Over many installs/reinstalls
(dev testing) one user piles up dozens of rows (56 observed). The only pruning today:
- Client `cleanupStaleData()` (`HomeLinkApp.swift:52`, every launch) deletes **own** tokens where
  `updated_at < 60 days` — but **`updated_at` never bumps on re-upsert** (finding #2), so this is
  unreliable: it won't clear recently-dead tokens for 60 days, and could even age out a **live**
  token whose row was inserted >60 days ago (the app re-adds it on next foreground, so it self-heals,
  but it churns).
- Server `cleanup_stale_data()` RPC (`hardening.sql:54-56`) — same 60-day / same `updated_at` caveat,
  and must be scheduled (pg_cron).
→ Dead tokens accumulate for up to 60 days, and the sweeps are unreliable. Nothing prunes on the
**actual dead signal** (APNs 410).

---

## FIX 1 — Edge function self-prune (IMPLEMENTED, permanent fix)
On the **final** APNs status (after the prod↔sandbox fallback) being **410 Unregistered or 400
BadDeviceToken**, DELETE that token row. Implemented in `index.ts`:
- The per-token map now also carries the **full** token (`full: t.token`) alongside the sliced one.
- **All existing logging is preserved byte-for-byte** — a `logShape` helper strips `full` so logs
  and the HTTP response still show only the sliced token (no full tokens leak into logs).
- After the results, dead tokens (`finalStatus === 410 || 400`) are collected and deleted in one
  `supabase.from("device_tokens").delete().in("token", deadTokens)`. The function client uses the
  **SERVICE_ROLE** key, so the delete bypasses RLS. Best-effort: a prune error is logged
  (`push chain ⑥ prune: FAILED …`) and never blocks the push; success logs
  `push chain ⑥ prune: deleted N dead token(s)`.
- **Correctness guard:** only the **final** status counts — a SANDBOX (dev) token 410s on prod but
  200s on sandbox → final 200 → **kept** (not deleted). Multi-device users keep all their **live**
  tokens; only APNs-confirmed-dead ones are removed.

**Effect:** the next push to a user with dead tokens self-prunes them. John's 56-row account drops to
its 3 live tokens on the very next ping he receives.

**Deploy command (you run it):**
```
supabase functions deploy send-ping-notification
```
_(No new secrets/migrations needed. Existing `APNS_*` secrets + the `pings`-INSERT webhook are
unchanged.)_

## FIX 2 — One-time purge of the already-dead pile (SQL for you to run)
**Recommended (zero-risk): do nothing manual — let the deployed auto-prune clear them.** The next
push to each affected user deletes all their dead tokens in one shot. To clear your own test account
immediately, just send yourself a thought once after deploying.

**If you want an immediate manual sweep** (conservative — keeps the few most-recent per user so a
genuine multi-device user isn't stripped):
```sql
-- Keep the 3 most-recently-updated device tokens per user; delete older rows.
-- One-time pile-clearing for accounts that accumulated dead tokens before the
-- self-prune fix. The deployed edge function keeps it clean going forward.
delete from public.device_tokens d
using (
  select token from (
    select token,
           row_number() over (partition by user_id order by updated_at desc) as rn
    from public.device_tokens
  ) ranked
  where rn > 3
) old
where d.token = old.token;
```
⚠️ Caveat: ranks by `updated_at`, which (finding #2) isn't bumped on re-upsert — so it ranks by
**first-seen** time, a reasonable proxy (older reinstalls = older rows). For internal testing
(~1 device per tester) this safely clears the pile. **The auto-prune (Fix 1) is the real fix;** this
SQL is optional cosmetic cleanup.

## FIX 3 — App-side gap (REPORTED, NOT bundled — your call)
**Gap:** `DeviceTokenRow` omits `updated_at`, so re-registering a stable token never refreshes its
timestamp → the 60-day sweeps (client `cleanupStaleData` + server `cleanup_stale_data`) are
unreliable (could age out a live token; don't promptly clear dead ones).

**Minimal fix (recommended, low-risk):** add `updated_at` to `DeviceTokenRow` and set it to `now()`
on each upsert, so re-registration bumps the timestamp and the 60-day sweeps become correct.
**Flagged, not bundled** because it touches the push-critical registration upsert (a malformed
timestamp string would fail token registration) — worth a deliberate Release build + device check.
**Do NOT** instead make the app "delete all other tokens for this user on register" — that would
break legitimate multi-device users; the edge-function self-prune (Fix 1) is the correct mechanism.

---

## VERIFY
- **Changed file:** only `supabase/functions/send-ping-notification/index.ts` (no app code, no
  schema, no Track-1 files, no link/messages/senderID/animation files touched — confirmed via
  `git status`).
- **App build/tests:** no Swift change → Xcode build unaffected; test suite unchanged (last green:
  **214 tests, 0 failures**). Deno isn't installed locally, so the function was syntax-reviewed
  manually (standard supabase-js v2 `.delete().in(...)` + TS object-rest).
- **Deploy:** `supabase functions deploy send-ping-notification`.

_No DB writes were run, no message sent. The purge SQL is provided for you to run, not executed here._
