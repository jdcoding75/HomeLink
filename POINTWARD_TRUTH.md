# Pointward — Project Truth Document

> ⚠️ **THE ONE LIVE DOC = THIS FILE** (`POINTWARD_TRUTH.md`, repo root). The only other
> truth file — **`POINTWARD_TRUTH_ARCHIVE_2026-06-23.md`** (same folder) — is FROZEN
> HISTORY: read-only, never edit it, never confuse it for the live doc. There are no
> other copies anywhere on disk.

> **This is the ONE document any future Claude Code session reads to understand
> Pointward completely.** It supersedes the fragmented bootstrap paste and is the
> canonical reference going forward. `SESSION_LOG.md` (running history) and
> `POINTWARD_ANIMATION_FRAMEWORK.md` (animation grammar) remain, but this document
> is the top of the hierarchy. When they conflict with reality, the live code +
> this document win.

## ⭐ START HERE — read first (operating manual + current state)

### OPERATING MANUAL (how this project works — for a fresh PLANNING session)
- **ROLES.** John = solo dev. The **planning chat** (claude.ai) = architecture/planning lead — writes
  scoped prompts John pastes into **Claude Code** (the executor, full local repo access on his Mac).
  **Single-writer-per-repo.**
- **HANDOFF LOOP.** Planning writes a prompt → John pastes into Claude Code → Claude Code works + **WRITES
  FINDINGS TO A FILE** → John runs `copyreport <name>` → pastes the clean file back. **ALWAYS have Claude
  Code write findings to a file** (`reports/<name>.md` or temp output) — **NEVER request terminal-only
  answers** (they come back garbled). Aliases: `copyreport <name>`, `copyterm <cmd>`, `copyfile <path>`.
- **EVERY Claude Code prompt:** propose-diff-first for changes (wait for approval); read-only
  investigations write a report; end with "write findings to `HomeLink/reports/<name>.md`". (Claude Code
  reads `CLAUDE.md` for the full standing workflow — repo confirm, git pull, build cmd, tagging, commit
  trailer, migration handoff.)
- **CAPABILITY-AWARENESS — USE YOUR OWN TOOLS, don't make John relay what you can fetch.** The **planning
  chat has a LIVE Supabase MCP connection** to project `jlbgdlgwtrkmqcfnomlr` ("pointward") — read
  schema/tables/rows/RLS/policies/migration-state **DIRECTLY** (use `tool_search "supabase"`, then query).
  **DEFAULT to looking up DB facts yourself** (did a migration apply? are the rows right? what's the
  schema?) instead of asking John to paste. Also: if John pastes a `github.com` file URL (repo
  `jdcoding75/HomeLink` is PUBLIC), you can `web_fetch` it (big files truncate — top-of-file reads
  reliably). Use `web_search` for current external facts. **Reserve John's relay for what only he can do**
  (run Claude Code, apply migrations, two-phone device tests, decisions). NOTE: the Supabase project also
  hosts a separate **"MyDay" app's `myday_*` tables** — stay scoped to Pointward, read-only verification,
  **never modify data** (migrations stay deliberate).
- **CANON = THIS doc** (POINTWARD_TRUTH.md) = durable source of truth. The **conversation is disposable
  scratch** — bank decisions here and start FRESH chats when they get big. To orient a fresh session: read
  **START HERE + WORK CLUSTERS**; for a focused topic go to that cluster.
- **MULTI/TOPIC SESSIONS.** Canon is shared by all; START HERE + WORK CLUSTERS are topic-agnostic (read
  first). Keep concurrent sessions on DIFFERENT clusters (different code/canon areas); bank each promptly;
  single-writer applies to canon too.
- **KEY FACTS.** app repo `~/Developer/HomeLink` (github `jdcoding75/HomeLink`, `-scheme HomeLink`, iPhone
  17 Pro sim, Swift 5). Website `~/Developer/pointward-website` → pointward.app. Supabase
  `jlbgdlgwtrkmqcfnomlr` — log in as **OWNER (GitHub jdcoding)** or "no access"; migrations written to
  `supabase/migrations/`, **owner applies SQL in dashboard**. TestFlight public:
  `testflight.apple.com/join/rjAS4cnk`. **v1 ships 100% FREE.**
- **VERIFICATION IS MOSTLY SELF-SERVICE.** LOGIC → the embedded test harness (`HomeLinkTests`, run anytime,
  no phones); DB/SERVER → the planning chat queries Supabase MCP directly; CODE → git / a pasted URL.
  Reserve the **human two-phone pass for the irreducible only** (real APNs, cold install, actual UI render,
  live socket). Default to self-verifying; surface to John only what needs a **device or a decision**.
- **BATCH verification when safe.** Prefer ONE test run / ONE device pass across several INDEPENDENT changes
  over a cycle per change (the "5-fix batch → one clean test" pattern). Only batch independent/safe changes
  — isolate risky/interacting ones so a failure isn't ambiguous. **Goal: fewest test cycles.**
- **TESTING PHILOSOPHY (standing).** PREFER automated, step-checked tests over manual conversational testing
  (manual two-phone is slow + churn-prone + loses fidelity). **SIMULATE-AT-BOUNDARY, AUTOMATE-DOWNSTREAM:**
  for any flow with one irreducible OS/real-world step (clipboard handoff, APNs, true cold install), verify
  that step manually ONCE, then INJECT the payload it produces and auto-test all consuming logic
  (parse / state-transition / replay / reconciliation) — permanent coverage. **Layers:** unit (logic; has a
  ceiling — passed while tonight's bug existed) → **DB-scenario** (per-side connection states via SQL /
  Supabase MCP — the big unlock) → selective **XCUITest** (single-device, step-checked) → irreducible-manual
  (real APNs to a closed phone, true cold install, visual render). Goal: shrink manual to the 2–3 OS-level
  things; automate all logic.

### CURRENT STATE (what's done / what's next — update each session)
- **✅ RELEASE GATE = PAIRING CLUSTER → CONNECTION GATE CLOSED for v1 (delete→reconnect re-green FIXED +
  VERIFIED end-to-end).** P1/P2/P3 + harness (P3 `366fe79`, P2 `bcee4fe`, P1 `2c2f535`, harness `9cf858f`;
  server policies MCP-verified). **SERVER:** `record_connection` upserts (`07c770c` `[conn-reconnect-fix]`:
  `on conflict (sender_id, connected_user_id) do update set via_message_id = excluded.via_message_id,
  connected_at = now()` — was `do nothing`) → a reconnect re-fires + refreshes the via (stale-via gone);
  migration `20260624000000` applied + MCP-verified. **CLIENT (built + unit-proven):** `stampConnections`
  falls through to `connected_user_id` when the SentLink is dangling/absent (`07c770c`), `deletePerson`
  deletes the contact's SentLinks, `record_connection` re-fires on EVERY open (not gated), realtime
  `onConnection` re-runs `syncConnections`. **VERIFIED:** S1–S5 (within the 16/16 `ConnectionClusterTests`,
  incl. testS2 = the bug) + **DB-scenario S6/S7/S8 PASS via Supabase MCP** (S6 old-link-reopen idempotent ·
  S7 upsert semantics · S8 RLS scoping) + **S9 two-phone DEVICE-CONFIRMED** (clean connect greens; then
  delete→reconnect → sender RE-GREENS, server-verified row reformed with updated via). Re-greens on
  foreground-sync, not live (realtime INSERT-only caveat; acceptable). P3 realtime publication LIVE
  (`link_connections` in `supabase_realtime`). **v1 is no longer blocked on connection grounds.** See WORK
  CLUSTERS P1 + `reports/connection_fix_bank.md` (S6–S8) / `reports/s9_device_result.md` (S9) /
  `reports/audit_perside_client_reconcile.md` (client code). **DEFERRED (post-v1, NOT gating):** the deeper
  per-side-state MACHINE (pending/recorded/consumed/expired/failed per side) + an optional live-DB assertion
  layer vs the hermetic mock.
- **PAIRING DESIGN (decided).** ONE CONTACT PER USER ID (senderID sticks; incoming ID auto-attaches, never
  double-creates; server name never overwrites user name; "let it live, user cleans up" — NO
  auto-merge/merge-tool/name-matching). P1 = visibility only. P2 = one-directional disconnect = the
  linchpin that makes cleanup stick. Contacts-pick PREFERRED (firm name/address/channel; auto-addressed
  first send; stores send-channel = wrong-person PREVENTION; P2+P1 = safety net).
- **NEXT PRIORITIES.** **The connection gate is CLOSED → v1 is no longer blocked on connection grounds.**
  (1) the **iterative/non-blocking clusters** per WORK CLUSTERS (animation-correctness / ARRIVAL PARITY,
  screens-reduction, compass HOLD·LOCK·TAP, contact-UX bugs, pre-launch polish, web teasers). (2)
  **repo-hygiene:** write the already-live realtime + `record_connection`-upsert SQL into
  `supabase/migrations/` for the record (the DB already has both — NOT a DB-state gap). **Deferred (post-v1,
  not gating):** the deeper per-side-state MACHINE; the live-DB assertion layer vs the hermetic mock; the
  realtime UPDATE subscription (live reconnect re-green). _(Canon reduction passes 1–3 DONE.)_
- **CI (GitHub Actions auto-run on push) — SHELVED pre-launch.** Reason: the headless runner launches the
  full app as the test host → unbounded per-subsystem launch crashes (APNs / SwiftData / StoreKit / Supabase
  SDK). Durable fix = host-less tests, which need `ENABLE_DEBUG_DYLIB = NO` on the app target (the Xcode-16
  debug-dylib stub blocks host-less `@testable` linking). Full recipe: `reports/ci_hostless_audit.md` +
  `reports/ci_hostless_result.md`. The 16/16 `ConnectionClusterTests` run **LOCALLY** and are the
  regression-floor safety net; DB-scenario verification via Supabase MCP is unaffected. Workflow is renamed
  `ci.yml.disabled` (not deleted). Revisit CI post-launch. Keeping `be0edee` (in-memory store + StoreKit gate
  + main-thread push-state read) — it fixed real latent launch bugs.
- **EFFICIENCY STACK (this session).** Supabase MCP both sides (planning chat verified working; Claude
  Code add pending auth); CLAUDE.md consolidated standing workflow (`1f89605`); write-to-file→`copyreport`
  is the clean handoff; GitHub URL-fetch works (partial on big files). **GitHub MCP = SKIP** for Claude Code (local git + `gh` cover it); **Supabase MCP = the add.** **Testing aids:** `HomeLinkTests` harness (logic) · **P2 delete doubles as a test-RESET tool** (clear connections on demand) · a **DevTools dev-send**.
- **POINTER.** Full history, design rationale, and the detailed WORK CLUSTERS are below. (Phase-2 reduction
  will archive the oldest history.)

_Last updated: see **START HERE / CURRENT STATE** (top) for the live state. Full session-by-session running log archived in `## ARCHIVE` below + `POINTWARD_TRUTH_ARCHIVE_2026-06-23.md`._

## ⭐⭐ SESSION RECONCILIATION — 2026-06-25 (current true state)

_Reconciles the §A–§O pre-launch correction batch + this session's commits against the live repo. Records
STATUS only — sequencing is the user's call. Build/commit facts cross-checked `git log --since=2026-06-24` +
clean `xcodebuild`._

### ⛔ SHOW-STOPPER — COMPASS MECHANISM IS NON-FUNCTIONAL ON DEVICE
- **State:** at current HEAD (`55dbced`) the compass **does not fire / launch a thought when physically aiming
  on a real device.** Ship-blocking. **NOT resolved.**
- **Sim-verified ≠ working.** The autonomous hands-free attempt (`55dbced`) was committed and passed a 4-phase
  `-compassSelfTest` + `simctl log stream` check — **but the Simulator has no magnetometer/motion; the harness
  force-fed alignment (`forceAlignedTest`) and faked the set-down flags.** So the sim proved the *gate logic*,
  not real-world firing. On device it does not fire.
- **History (factual):** `45bbf0d` dropped the original tap mechanic → auto-fire-on-alignment → false-fire →
  a guard cascade each of which over- or under-blocked: device-upright `gravity.z` (`3560853`) → revert
  (`52b4587`) → stillness (`304dadb`) → still-AND-flat (`e2710d8`) → on-face touch gate (`26e09ed`) → restore
  the original point-hold-**TAP** (`037d0d6`) → autonomous hands-free re-attempt (`55dbced`). None fires on
  device.
- **What the user wants:** **HANDS-FREE** (aim → hold → sends; **no tap, no finger**). He recalls it worked
  hands-free *before* `45bbf0d`. The four requirements: (1) hands-free aim+hold→send; (2) does NOT fire
  repeatedly while held/aimed; (3) set-down does NOT auto-fire; (4) after a send, turn away + re-aim + hold
  sends again.
- **What it needs:** a fresh **device-grounded** fix (real magnetometer/motion in hand), NOT another
  chat-relayed guess and NOT another sim-only "verified." Treat sim self-test as necessary-not-sufficient.
- _DEBUG scaffolding currently in the tree (zero release impact, behind `#if DEBUG` + `-compassSelfTest`):_
  the self-test harness + milestone logs in `CompassView`, and `forceAlignedTest`/`forceMisalignedTest`/
  `setSetDownForTest`/`pokeStateForTest` in `CompassManager`.

### STEP-0 BUILD TRIAGE (read-only)
- **(a) Builds? YES** — clean `xcodebuild` = **BUILD SUCCEEDED**.
- **(b) Errors vs warnings:** **ZERO compile errors.** All output is warnings: Supabase SDK deprecations
  (`subscribe`/`postgresChange`, SupabaseService.swift), Swift-6-mode main-actor `Encodable`/`shared`
  conformance warnings (`SupabaseService.PingPayload` :322/:337; **`PeopleManager.swift:35`** — the cited one —
  is a *warning* on the `SupabaseService.shared` default-arg pattern, not an error), RootView `detectPatterns`
  deprecation, ProSetup/InstrumentOptionPicker init warnings. All pre-existing, none from today's edits.
- **(c) Do any touch compass / animation / send?** **No — none are real errors, and none relate to the compass
  failure.** The compass problem is purely **runtime/behavioral on device**, not a compile issue. (Not fixing
  any of these now; logged for record.)

### §A–§O LAUNCH BATCH — STATUS BY ITEM
| § | Item | Status | Commit / note |
|---|---|---|---|
| **§A** | Wind mic bug — delete `fallbackHoldTick` auto-fire; static no-mic note | ✅ **DONE** | `6d89f63` (remove auto-fire loop) + `2a1cb5d` (no-mic card) + `77c2a90` (leaf/breath tuning). Sim always shows no-mic; real blow = device-only. |
| **§B** | **Compass send screen (B1–B6)** | ⛔ **LARGELY NOT DONE** — see per-item below. Session diverted into the compass MECHANISM saga instead. | |
| §B-B1 | Instruction text on all 9 (spec'd blocks) | ❌ **NOT DONE** | `830964a` only set the compass tail to "point · hold · turn away to reset" — now **stale** (mechanism changed) and ≠ the spec'd 9 blocks. |
| §B-B2 | Drop the dynamic turn-by-turn line (`alignmentInstruction`, `:1417-1422`) | ❌ **NOT DONE** | |
| §B-B3 | Degree readout "{name} is at {N}°" from `rawBearingToTarget` (hide when nil) | ❌ **NOT DONE** | |
| §B-B4 | Alignment model — fixed top mark, use existing needle (no new rim marker) | ❌ **NOT DONE** (design decided) | |
| §B-B5 | Wheel rework — 15° notches / red index mark / Vintage skin only | ❌ **NOT DONE** | |
| §B-B6 | Flick face — drop in-face text, use standard instruction line | ❌ **NOT DONE** | |
| **§C** | Recipient flow → binary onboard-or-view (one CTA, drop 2 doors + menu, viewer-can't-send send-guard) | ❌ **NOT DONE** | no commit; locked spec only (audit `recipient_flow_audit.md`). |
| **§D** | People add+edit | ✅ **DONE** | D1+D2 collapse add to one screen + hide emoji = `0c6969e`; D3 hide edit emoji = `cd089c5`; D4 edit-location-showed-name bug = `892a99d`. |
| **§E** | One `defaultMessage` per emoji, drop suggestion arrays + overline; keep freeform field | ✅ **DONE** | `e22587c` (drop suggestions, unify 🎓 dup, add birthday/firework hints). |
| **§F** | Cut redundant middle "Message from {name}"; add reveal spacing | ✅ **DONE** | `aa0950c`. |
| **§G** | Bucket badge — one line "New thoughts in your bucket", hide at 0, keep numeric icon badge | ✅ **DONE** | `902241e` (+ `083485b` bucket-catch ✦ consistency). |
| **§H** | Disable share-card "share this moment" for v1 (comment, preserve) | ✅ **DONE** | `832bbdb`. |
| **§I** | Cut discovery hint "tap the words to explore" | ✅ **DONE** | `3999a1b`. |
| **§J** | Short code — keep infra, remove recipient-facing text | 🟡 **PARTIAL** | Web removal = `65708a5` (website repo). **App-side suffix STILL PRESENT** — `MessageLink.swift:56` `"· no app? open Pointward and enter {code}"` NOT removed → app-side NOT DONE. 9d "got a code?" People-tab button keep/retire = still open. |
| **§K** | Wand receipt mis-wire | 🔎 **AUDITED, FIX NOT DONE** | Re-audit confirmed (`batch_final_audit.md` Part 1): a dedicated `WandLanding` receipt EXISTS (the Lab "Wand V1" renders it; `InstrumentLandingView.swift:43`), but live `.wand` routes to `standardReceipt` because `AnimationDispatch.receiptKind` maps `.wand → .standard`. Fix = add a `.wand ReceiptKind` + route `.wand → .wand` + bridge `WandLanding`'s single `onComplete`. **Routing fix, not a build. Not applied.** = the "wand fires on device but receipt doesn't show" symptom. |

### THIS SESSION'S OTHER COMMITS (DONE — mapped)
- **WAND mechanic (fires on device now):** `81ff2e4` (restore shake hysteresis gap 1.2→1.5) → `df1147c`
  (gravity-removed `|mag−1|` shake metric — reliable re-arm) → `b3ddd85` (**onFull-driven release — fixed the
  dead `tick` heartbeat timer; release/onSend never fired before**) → `ce64461` (cut full-charge sustain +
  beat ~1.4s→~0.7s). **Wand FIRES on device; the RECEIPT not showing = §K above.**
- **Birthday:** `b562e38` (parametric centered, center-tall candle layout for any count) + `830964a` (3 candles).
- **Pro/paywall hide (v1-free):** `a8801b6` (hide "✦ Pro → paywall" receiver in RootView) + `7633ebe`
  (free `maxPeople` 1→10, people-limit paywall unreachable) + `1625744` (hide Giving Back / Pro / Restore rows
  in Settings).
- **Copy batch:** `008354e` (receipt sender sentence → "{name} sent you something ✦" across Compass/Wind/
  Rocket/Plane/Flick) · `247313b` (connection status → lowercase "connected ✓") · `9b6df1f` (version →
  "version {x}") · `456b829` (Edit "save changes" → "save") · `083485b` (bucket catch ✦) · `eaf4993`
  (AboutView story copy).
- **Feedback table:** Supabase `feedback` table created + verified, **RLS insert-only (anon + auth)** — the
  in-app form build is staged (see NEW below).
- **Wind:** `6d89f63` (remove mic-denied auto-fire loop, ship-blocker) + `2a1cb5d` (no-mic card + Settings pill
  + "breathe into mic") + `77c2a90` (leaf/breath tuning).
- **Declutter batch (§E–§I above are part of it):** `e22587c aa0950c 902241e 3999a1b eaf4993 1625744 832bbdb
  0c6969e cd089c5 892a99d`.
- **Web short-code removal:** `65708a5` (website repo).
- **Mechanism-reset batch (rocket/cancel/wind):** `fd4974b` (uniform post-send `finishSend` reset) · `3054664`
  (tap-outside-the-circle = universal cancel) · `b706ba7` (rocket — remove lock, widen fire cone 5°→10°).

### NEW THIS SESSION — to record in canon
- **🛠 SELF-PROFILE EDIT (NET-NEW, needed — CONFIRMED ABSENT):** there is **no post-onboarding screen where the
  user can edit THEIR OWN name + home address/location.** `OnboardingView`'s about-you screen sets them at first
  run only; `EditPersonView` edits OTHER people; **`SettingsView`/`AboutView` reference no `UserProfile` editor**
  (grep-confirmed). So a returning user cannot change their own name/home. **NET-NEW, needed.**
- **🛠 Feedback form** — Supabase `feedback` table built + verified (RLS insert-only anon+auth); the in-app form
  build prompt is staged (Settings "Send feedback" → sheet; integration audit `feedback_integration_audit.md`).
- **🛠 Permissions tab** — audit done, build prompt staged: **Mic / Location [critical] / Notifications**;
  **Contacts excluded.**
- **🅿️ CompassView.swift SPLIT (POST-TESTFLIGHT, contributor infrastructure):** the ~2700-line monolith blocks
  parallel/outside contribution. Splitting it (per-instrument files / animation-pipeline seams) lets the user's
  son + volunteers each own one instrument's file without colliding. **Enables parallel dev + safe outside
  contribution.** Structural, post-TestFlight.

### v3 / PHASE-3 BANKING (verbatim — lose nothing)
- **10-MECHANIC BRAINSTORM (sender-side embodied initiation):** (1) **voice recording** — `AudioRecorder`
  already BUILT, orphaned in the unreachable `ProSetupView`; **nearest-ready**. (2) yell-to-send. (3) heartbeat
  via camera pulse. (4) photo backdrop. (5) point-at-a-star. (6) drag-to-load. (7) tilt-to-pour. (8) walk.
  (9) camera-gesture (smile / peace). (10) hold-phone-to-heart.
- **DEFERRED TRACKS:**
  - **§K wand receipt re-wire** — add `.wand` `ReceiptKind`, route `.wand → .wand`, bridge `WandLanding`;
    spin-bucket `standardReceipt` → Animation-Lab-only.
  - **Wand orbits-frozen cosmetic** — the orbital rings don't spin (the same unstable `tick` `Timer.publish`
    that broke firing, now bypassed for firing; cosmetic only — make `tick` stable to restore spin).
  - **CompassView Pro-surface hide** — "✦ Pro" badge label (`:1068`), skin paywall (`:1175`), `lock.fill`
    (`:1988`), `InstrumentOptionPicker` (`:111`).
  - **Item 6 Part B — v1-excluded-features hide** — extra skins / mix / emoji-picker / multi-person
    (display-only hide; the gate stays intact).
  - **Onboarding simplification.**
  - **Poetic-libraries consolidation** — `TaglineSystem.poeticLibrary` + `DistanceFun.thoughtTaglines`,
    ~7 duplicates (user reviewing).
  - **CompassManager motion-plumbing battery cleanup** — the `deviceMotion`/`isDeviceStill`/`isDeviceFlat`
    stream is unused if the compass mechanism stops reading it (depends on the device-grounded compass fix).

### STILL-OWED ROLL-UP (for quick scan — status only, no ordering)
- ⛔ **Compass mechanism** — broken on device (show-stopper). · ❌ **§B B1–B6** compass send screen. ·
  ❌ **§C** recipient binary flow. · 🟡 **§J** app-side code-text suffix (`MessageLink.swift:56`) + 9d button. ·
  🔎 **§K** wand receipt routing fix. · 🛠 NEW: self-profile edit, feedback form, permissions tab. ·
  🅿️ CompassView split + the v3/deferred tracks above.

---
_Sources: `git log --since=2026-06-24`, clean `xcodebuild` (BUILD SUCCEEDED, warnings-only), grep of
SettingsView/AboutView (no self-profile editor), `MessageLink.swift:56` (suffix present), the §A–§O batch spec,
+ reports: wind_mic_bug, recipient_flow_audit, batch_final_audit (§K), feedback_integration_audit,
compass_*/wand_* (mechanism history). READ-ONLY reconciliation — nothing implemented; this section only records
current true state._
## What Pointward Is

Pointward is a SwiftUI + SwiftData iOS app for sending small, emotional
"thoughts" to the people you love — pointed in their real-world direction by a
compass. It is built around **three experiences**:

- **Connector** — loving, **compass-led**. The emotional core: a compass that
  points to a saved person, taglines that travel with each thought, quiet
  intimacy. This is the default heart of the app.
- **Expresser** — fun, **instrument-led**. Pick an instrument (bow, rocket,
  wind, …); the *instrument* shapes how the thought is charged, sent, and
  revealed. Playful and expressive.
- **Special Moments** — occasion-grade, **card-quality, premium**. Birthday,
  Firework, and the coming roster. The **animation IS the card** — these are not
  emoji picks; they are full authored moments with a distinct send path.

---

## Architecture — Sources of Truth

Every data type has exactly ONE owning file. **Edit the owner, never duplicate.**
Any UI surface that shows emojis/instruments/copy/colors MUST read from these —
never hardcode.

| Registry / File | Owns |
|---|---|
| **AnimationManifest.swift** | All animations, stages, versions, live-instrument list & ordering. The catalog the test lab + pro setup read. |
| **CuratedEmoji.swift** | All emojis: the live set, tiers (free/pro), defaults, suggestions, and `soundMap` (emoji → sound file). |
| **TaglineSystem.swift** | Poetic tagline library, tagline presets, and **`instrumentHints`** (each instrument's default message tone). |
| **InstrumentSoundPlayer.swift** | Per-instrument sound routing (`playSend` / `playReceipt` / `playCue`) — which `.wav` plays for which instrument/phase. |
| **SoundEngine.swift** | Programmatic synthesis voices (emoji + sender-style + cue voices), cached buffers, `play(for:)`. |
| **RevealAnimationRegistry.swift** | Emoji reveal animations (`RevealKind`) + per-emoji glow colors + full-screen flag. |
| **DesignTokens.swift** | Colors, typography, spacing. The palette source of truth (avoid raw `Color(hex:)`). |
| **ProFeatures.swift** | Pro/free gates. **End-game configuration — do not change without product sign-off.** |
| **InstrumentBoundaries.swift** | Screen-coordinate rules + the instrument generation spec (entry/exit reach, swirl amplitudes, bucket margins). |

**Known wiring gaps (carry forward — do not assume wired):**
- `TaglineSystem.instrumentHints` is the *designated* source of truth for
  instrument copy and **IS wired** into compose (corrected 2026-06-24 — the old
  "not yet wired" was STALE): a suggestion option (`CompassView:1863`) + the LAST
  seed fallback (`:1897`). 7 of 9 styles have a hint; **birthday/firework have none**.
  Seed precedence: manifest `defaultMessage` → per-emoji `CuratedEmoji.defaultMessage`
  → this hint. The traveling poetic tagline still rides from the person, separately.
- `CuratedEmoji.soundMap` and `RevealAnimationRegistry` still list some retired
  emojis and omit live `.pro` 🙏 (falls back to `.bloom`). Reconcile when next
  touching the emoji set.

---

## Instruments (live)

The 7 standard instruments live in `HomeLink/Instruments/<Name>/`. Each has the
full file set: `*CompassFace`, `*SendAnimation`, `*ReceiptAnimation`,
`*Sounds.swift`, and a generator `.py`. Live receipt/send dispatch is via
`ReceiptView.swift` / `CompassView.swift` + `SenderAnimationView.swift`.

| Instrument | Sender style | Compass face | Send (live) | Receipt (live) | Sounds (generator) | Status |
|---|---|---|---|---|---|---|
| **Compass** 🧭 | `glow` (free) | CompassCompassFace | CompassSendAnimation | CompassReceiptAnimation | compass_send/receipt (CompassSoundGenerator.py) | 🔒 Locked (visual + sound) |
| **Wind** 🍃 | `firefly` | WindCompassFace | WindSendAnimation | WindReceiptAnimation | wind_send/receipt/breeze (WindSoundGenerator.py + WindBreezeGenerator.py) | 🔒 Locked (visual + sound) |
| **Rocket** 🚀 | `rocket` | RocketCompassFace (legacy structure) | RocketSendAnimation | **RocketLandingReceiptAnimation** (merged landing) | rocket_send/receipt (RocketSoundGenerator.py) | 🔒 Receipt locked. `RocketReceiptAnimation` (parachute v2) is **test-lab only**. |
| **Bow** 🏹 | `bowArrow` | BowCompassFace (+ two-part draw/release SoundEngine cue) | BowSendAnimationV2 | **BowReceiptAnimationV2** | bow_send/receipt (+ arrow_whistle, sparkle_dissolve) (BowSoundGenerator.py) | 🔒 Locked (visual + sound). V1 files kept, retired. |
| **Flick** 👆 | `fingerFlick` | ⚠️ FACE UNRESOLVED (old `FlickInstrumentView` post-it vs `FlickDeskCompassFace` — verify in the animation-consistency pass) | **FlickSendAnimationV2 (LIVE)** _(path audit `f6ad2b4`, `CompassView:765`)_ | **FlickReceiptAnimationV2 (LIVE)** _(`ReceiptView:122`)_ | flick_send/receipt (FlickSoundGenerator.py) | 🔒 V2 send+receipt LIVE (corrects the prior "V2 parked / standardReceipt" claim); COMPASS-FACE still UNRESOLVED. |
| **Wand** 🪄 | `wand` | WandCompassFace | WandSendAnimation | WandReceiptAnimation | wand_send/receipt (WandSoundGenerator.py) | 🔒 Locked. |
| **Plane** ✈️ | `plane` | PlaneCompassFace | PlaneSendAnimation (LIVE) | **PlaneReceiptAnimationV2 (LIVE)** _(path audit `f6ad2b4`)_ | plane_flight + cue wavs (PlaneSoundGenerator.py + PlaneWindupGenerator.py) | 🔒 V2 locked (visual + sound). |

> **Naming caveats (do not "fix" without intent):** Bow/Flick use `V1`/`V2`
> suffixes; Plane uses base-name + `V1` + `V2` (three schemes);
> Compass/Wind/Wand/Rocket use no suffix. `FlickCompassFace.swift`'s top type is
> the legacy `FlickInstrumentView`. These are documented, not accidents.

---

## Emoji Set (live)

Source of truth: **CuratedEmoji.swift**. UI reads from it — never hardcode lists.

**Free tier:** 🤗 hug · 😘 kiss · 🤜🤛 fist bump · 🖐️ high five · 🫶 heart hands · 💥 boom

**Pro tier:** 💭 thought · 🙏 gratitude · 👏 clapping

**Custom reveals built:** 🤗 squeeze · 🤜🤛 pump · 👏 clap · 🎁 gift unwrap
(🎁 is the **Birthday Special Moment reveal mechanic**, not a standalone emoji)

**Bloom defaults:** Bloom is the default reveal for every emoji without a custom
animation. Bloom is enhanced: **+33% final size, −10% start size**.

**Removed (commented out in CuratedEmoji.swift, reasons inline):**
🙌 celebration (→ 👏) · 💪 muscle · ✨ special · 🤝 thinking of you ·
🎂 birthday emoji (conflicts with Birthday instrument) ·
🎆 firework emoji (conflicts with Firework instrument; renders as box) ·
💌 love note (→ Valentine's Special Moment) · 🎄 holidays (→ Special Moment) ·
💐 for mum (→ Special Moment) · 🎁 gift (→ Birthday Special Moment, not standalone)

---

## Special Moments

Special Moments are **not emoji picks — the animation IS the card.** They are
occasion-grade, card-quality, premium moments with a **distinct send path from
Thoughts**. They currently live under `Instruments/_Shared/EmojiReveal/` (emoji-
mechanic sends), not in their own `Instruments/<Name>/` folders.

- **Built:** 🎂 **Birthday** (V2 live — tap-to-light send, confetti, two-stage
  mic blow-out receipt) · 🎆 **Firework** (live — compass fuse, supernova send,
  receipt to bucket).
- **Coming soon:** 💌 Valentine's Day · 🎄 Happy Holidays · 💐 For Mum ·
  🎇 July 4th · 🎓 Graduation (cap thrown in air; moved here from standalone emoji).

**Architecture TBD (decide before building the next Special Moment):** does a
Special Moment need an emoji attached, or does it send standalone? This ties into
the **Pivot Session** (link delivery). See *Pivot Session* below.

---

## Three Experiences

- **Connector** — loving, **compass-led**. Saved person + real-direction
  compass + per-person taglines that travel with the thought. The emotional
  default.
- **Expresser** — fun, **instrument-led**. The selected instrument owns the
  charge/send/receipt grammar and its own default message tone
  (`TaglineSystem.instrumentHints`).
- **Special Moments** — **card-quality, premium**. The animation is the card;
  distinct send path; fixed authored voice that overrides emoji/instrument copy.

**Message default hierarchy:** Special Moment voice **>** Emoji default **>**
Instrument hint. **The user's own message always overrides.**

---

## Animation Standards

### The canonical 3-stage model
Every instrument is three stages, in this order:

1. **Compass face** — the interactive mechanic (charge/aim/draw on the compass
   tab). NEVER rewritten to static art; the mechanic is sacred.
2. **Send** — full-screen send animation, dispatched via `SenderAnimationView` /
   `CompassView`, handing back to the finish-send pipeline.
3. **Receipt** — full-screen receipt, dispatched via `ReceiptView`, ending in
   `EmojiRevealView(.received)` over the instrument's ambient background.

Full grammar (timeline keyframes 0/25/50/75/100%, easing curves, particle rules,
bucket spec, forbidden list) lives in **POINTWARD_ANIMATION_FRAMEWORK.md** — the
locked "match Wind + Rocket" reference. Read it before touching any animation.

### Screen coordinate rules (InstrumentBoundaries)
Every instrument animation: `GeometryReader` as the outermost root ·
`.ignoresSafeArea()` on the background · ALL positions from `geo.size` · no
`UIScreen.main.bounds` · no hardcoded dimensions. Shared constants live in the
`ScreenCoordinates` enum; the full generation spec is in
`InstrumentBoundaries.swift`.

### Instrument file standard (what every instrument must have)
```
Instruments/<Name>/
  <Name>CompassFace.swift       ← interactive mechanic
  <Name>SendAnimation.swift     ← full-screen send
  <Name>ReceiptAnimation.swift  ← full-screen receipt
  <Name>Sounds.swift            ← sound file references
  <Name>SoundGenerator.py       ← regenerates the .wav(s)
Versioning: V1 = original (always kept, never deleted); V2 = new. V1 stays
wired live until explicitly upgraded. Both appear in the test lab.
```

---

## Sound Standards

- **InstrumentSoundPlayer** — per-instrument routing. Instrument send/receipt and
  cue sounds go through `playSend` / `playReceipt` / `playCue`. No raw
  `AVAudioPlayer` in views.
- **SoundEngine** — programmatic synthesis voices (emoji reveals, sender-style
  voices, cues), pre-cached, played via `play(for:)`. "No audio files" for these
  synthesized voices; everything generated sample-by-sample.
- **Generator `.py` requirement** — every shipped `.wav` must have a generator
  script so it is reproducible. Pure Python stdlib (no numpy/scipy) so it runs
  anywhere. Add the generator alongside the instrument / reveal.
- **Reveal sound rule** — reveal sounds play ONLY at the reveal moment, via
  `EmojiRevealSound`; never during send/receipt, never via legacy SoundEngine for
  reveals. Impact/punch sounds = filtered noise only (no sine waves).

---

## Emoji Reveal Standards

- **Bloom is the default.** Any emoji without a custom reveal blooms + breathes
  (enhanced bloom: −10% start, +33% land). One consistent framework.
- **Custom reveal pattern** (how 🤗 squeeze, 🤜🤛 pump, 👏 clap, 🎁 gift unwrap
  were built):
  1. Add/confirm a `RevealKind` + entry in **RevealAnimationRegistry.swift**
     (kind + glow color + full-screen flag).
  2. Add a `start<Kind>()` in **EmojiRevealView.swift** driving the shared
     transform/effect state; fire the sound at the exact reveal beat.
  3. For art the system glyph can't render (cake, gift, firework), draw a custom
     hero View (e.g. `GiftBoxGlyph`, `BirthdayCakeGlyph`, `FireworkGlyph`) — the
     underlying thought data stays the emoji.
  4. Add the reveal sound to **EmojiRevealSound.swift** + a generator `.py`.
- **RevealAnimationRegistry requirement** — reveal kind is chosen by the registry
  (a `[emoji: kind]` map), NOT by `if/else` scattered in the view.

---

## Lock Ledger (current)

**⭐ Phase-2 animation-track update (later than the entries below — see the
"Phase 2 — Animation Track (canonical commit ledger)" section + `reports/phase3_handoff.md`):**
- **Plane + Flick V2 — ✅ CONFIRMED LIVE (path audit `f6ad2b4`):** `PlaneReceiptAnimationV2` (`ReceiptView:120`)
  + `FlickReceiptAnimationV2` (`:122`) + `FlickSendAnimationV2` (`CompassView:765`) are the live dispatches.
  The residual send/receipt v1/v2 question is CLOSED. _(⚠️ The Flick COMPASS-FACE is still UNRESOLVED — old
  `FlickInstrumentView` post-it vs `FlickDeskCompassFace`; the audit did NOT confirm the face → verify in the
  animation-consistency pass. See the Flick table row.)_
- **Wand receipt — DEFERRED** (`WandReceiptAnimation` is a stub enum, not a View) → wand
  still uses the shared turn-to-catch bucket on arrival. Net-new build, low priority. _(Path audit `f6ad2b4`
  CONFIRMS: wand is the lone instrument with no dedicated receipt — falls to `standardReceipt`/bucket;
  `ReceiptView:130-135`.)_
- **Birthday + Firework — now first-class peer animations, COMPLETE end-to-end**
  (Special Moments Stages 1+2+3, `c38ca9d` → `624b044`): selectable `Instrument`+
  `SenderStyle` cards; **both** sender-side AND recipient (`ReceiptView`) dispatch key on
  style/selection (not the emoji). Birthday's default emoji is the intended **🎁** (the
  interim 🎂 was flipped back at Stage 3). Only **Stage 4** remains — retire the emoji
  fallback branches once the fleet has updated. _(Path audit S2 `f6ad2b4`: the legacy 🎂/🎆 emoji-pick
  fallback in `CompassView case .compass` (`:311-380`) runs parallel to the first-class `.birthday`/
  `.firework` cases — both render correctly; retire with Stage 4.)_
- **Firework + Birthday FREEZE — FIXED** (`380d374`, re-arm CONFIRMED on device): as peer
  instruments their face persisted across sends (no destroy-on-deselect) → frozen after one
  fire; `finishSend` now bumps `instrumentResetID` for `.firework`/`.birthday` after the
  flight, rebuilding the face fresh.
- **Rocket receipt descent — SMOOTHED** (`380d374` + `68de96d`): single fast `easeInOut`
  whip → slow `easeIn` ENTRY (`entryDropDuration` knob, 5.0s) + kept `easeOut` SETTLE,
  beats re-anchored off `land`. Accepted **"good enough."**
- **Settings notifications — REMOVED** (`e6e0608`): the dead "show arrival preview"
  (`380d374`) and the dead/mislabeled "thoughts" toggle are gone → **zero user-facing
  notification controls** (thought-arrival push always-on, iOS system permission only).
  Post-launch: optional relabel/repoint a toggle to the live thought push (PATH-1 + deploy).
- **Bucket per-item DELETE — SHIPPED** (`5cf1d47`): "🗑 delete" on the replay overlay +
  `PingManager.removeFromHistory(id:)` (⭐ reusable Phase-3 backbone). Delete-only — **no
  save/preserve** (deferred to Phase-3 retention). Device-test pending.
- **Replay overlay UX — REWORKED** (`e3438a5`): auto-advance + swipe → explicit
  **PREV · NEXT · CLOSE · DELETE** button row (no auto-exit; reveal keyed on `cur.id` so
  delete-advance re-fires). PersonDetail replays unaffected. Known cosmetic: the inert
  "tap to keep ✦" hint in EmojiRevealView (fenced; later in-reveal cleanup). Device-test pending.
- **Per-instrument default message — SHIPPED** (`277b457`): `AnimationDefinition` gains
  `defaultMessage` + `defaultTagline`; compose seed PREFERS instrument default, FALLS BACK to
  per-emoji `CuratedEmoji.defaultMessage`. **Birthday → "Happy Birthday"** (only one populated;
  others nil → no regression). `defaultTagline` unwired. Receipt unchanged (style-keyed).
  ⭐ This de-risks the uniformity direction: full uniformity is now pure DATA-ENTRY (populate
  per-instrument defaults + retire the per-emoji fallback) — no new plumbing. Device-test pending.

**🔒 Locked this session (visual + sound unless noted):**
Wind · Rocket receipt · Compass · Wand · Flick V2 · Bow V2 · Plane V2 ·
Birthday V2 · Firework compass fuse position.

**🟡 Open / flagged:**
- Firework emoji renders as box — diagnosis running.
- Firework receipt box — likely same root cause as emoji box.
- Emoji lab regression — fuse-burn + preview not playing (heavy, separate session).
- Wind send visual — moves more than ideal (locked as-is).
- Bow compass art — weak illustration (deferred).
- Birthday send rise — didn't land (locked as-is).
- Three-experiences UI audit — running.
- Instrument hints wiring into the live send-flow UI — next build after copy batch.
- Firework receipt sparkling sound — built, not yet phone reviewed.

**⏸ Deferred (do not change without product sign-off):**
- Pro/Free tier configuration → end-game session.

---

## Pivot — DONE
Pivot DONE — link delivery is live, pairing removed (codes / `connections` table / `PairAcceptView`
gone); the link carries the sender's identity. See WORK CLUSTERS. _(Original "Pivot Session" archived below.)_

## Never Touch

- **AppGroupStore `suiteName`** — baked into both targets.
- **Widget target bundle ID.**
- **Associated domains entitlement.**

---

## Phase 2 — Link Delivery Model (IN PROGRESS — builds 1–9 safe-half shipped)

### Phase 2 — Link Delivery: COMPLETE (builds 1–9 shipped + verified)
The link-era delivery model shipped end-to-end: `short_code` + `messages` table; `/m/<id>` links
(insert → share sheet → open → fetch-by-id → receipt → opened-on-completion); cold-launch replay;
short-code fallback; contact auto-create on receive; unified sender-agnostic history bucket;
dead-pairing cleanup. `senderID` (= `users.id`) is the routing key. _(Per-build detail archived below.)_

### THE LINK SEND — SUPERSEDED (now LIVE)
**SUPERSEDED** — link send is **LIVE / un-gated (PATH 2)**; pings = PATH 1 (connected only). _(The old
"#if DEBUG / legacy pings is the only release delivery" note was true pre-link-era; original archived below.)_

### ⭐ SEND / CONNECTION MODEL — FINAL (link era)
Two send paths: **PATH 1** (connected → `senderID`) = direct ping (APNs/realtime, named push, lands
in-app); **PATH 2** (not-yet-connected) = `/m/<id>` link + share sheet, recording a `SentLink` so the
connection later stamps the contact. **Connection signal:** `record_connection` on link-open writes
`link_connections` (RLS read-own); sender reads via `fetchMyConnections` + `stampConnections`.
**Read-receipt:** `messages.opened` flips at receipt completion. This is now the LIVE pairing cluster
(see WORK CLUSTERS). _(Original SEND-MODEL lock + CONNECTION-SIGNAL build-spec + Stage-B two-phone
findings archived below.)_

### ⭐ IDENTIFIER BACKBONE (framing principle)
The identity layer is the set of **stable joints** — tightly defined, expensive to
change, therefore **kept stable**. Everything else builds on top and may flex; the
identity layer must never need re-architecting.
- **sender `users.id`** — written as `messages.sender_id` (immutable account id).
- **receiver `users.id`** — exists once they sign in (the opt-in threshold).
- **message id** — `messages.id` (the `/m/<id>` PK): **the JOIN KEY** tying the
  sender's local contact ↔ the receiver who opened it.
- **the connection record** — `link_connections` (below): links sender ↔ receiver
  via the message they opened.

### ⭐ REMAINING BUGS (unphased) — no phase home (stragglers)
The bugs above are folded into their phase homes (11b/Stage C · 9b · 10) + the separate
double-tap audit. These have **no phase home** — they ride a different track:

**ANIMATION TERRITORY** (⚠️ the *"never touch without care"* set — careful, AUDIT-FIRST,
**batched separately** in an animation-chat session, NOT in the Phase-2 build line):
- **#12 — Plane v1/v2 — ✅ RESOLVED = V2 (path audit `f6ad2b4`):** `PlaneReceiptAnimationV2` is the LIVE
  receipt dispatch (`ReceiptView:120`); `PlaneSendAnimation` is the live send (`CompassView:744`). The
  deferred version question is CLOSED — V2 is live. Not a bug. (Stale `ReceiptView` comments still *say*
  "standardReceipt" → see DEAD-CODE cluster R5.)
- **#13 — Animation aiming-order** (load emoji **before** aim feels broken): the
  emoji-then-aim sequencing reads wrong in the send mechanic. Animation-chat; audit-first.
- **#14 — Send-sound distortion.** ⚠️ Reported under a **DEBUG** build — **VERIFY in a
  release/TestFlight build BEFORE treating as real** (likely a debug-mode artifact). If
  real in release → animation-chat (sound files are animation territory). If debug-only →
  ignore.

**NOTES** (confirm / observe — not necessarily real work):
- **#10 — Alex Demo disappears → ✅ RESOLVED (2026-06-23):** now **"Demo Dan", persists correctly.**
  Closed; kept here for record.
- **#11 — First-send-only animation breakup/noise** — 1st send after launch stutters, 2nd
  is clean: a **cold-start / warm-up** pattern (asset/first-run priming), not a logic bug;
  observe. (If pursued → animation territory.)

### PATH-1 preserve-list (survives 9b, re-keyed to senderID)
`pings` · `sendRemote` · `sendPing` · realtime+felt · `syncMissedThoughts` · `Person.senderID` · push
chain · `markPingOpened` · `markAllMyPingsOpened` · `stampConnections` · `link_connections`. _(Full
session-continued narrative — PersonDetailView reconcile, unread-badge fix, 9b audit — archived below.)_

### Three LOCKED bucket decisions (Joshua, this session)
1. **Replay-from-history does NOT flip opened** — replay = re-feel, not consume.
2. **Bucket is ALL senders** — per-person scoping dropped ("fill my bucket" intent).
3. **50-cap stays**; opened link messages count toward it.

### ⭐ BUILD 10 — OUTCOME + LOCKED DECISIONS (shipped `b10190f`)
Onboarding = **sign-in → about-you** (name at the send-moment; location 3-option skip/type/use-current;
showcase optional/deferred). **Link-arriver path:** tap → message plays (no gate) → 3-door landing
(send-one-back / see Pointward / I'm good) → compose-back + fill-via-link. Governing principle:
**friction-free + require-when-used + tutorial-as-setup**. Patch-not-rebuild (paged TabView trimmed).
_(Full design-session reasoning, link-arriver structure, and phone-walkthrough findings archived below.)_

### ⭐ WEB PAGE (Build 12) — DONE (the `/m/<id>` page)
Live in the `pointward-website` repo (GitHub Pages at pointward.app). Locked decisions:
- **Serving:** `404.html` at repo root (no path-wildcard on Pages) → path-style `/m/<id>` resolves; no app-side link-format change.
- **Data:** anon `get_message` RPC (emoji/content/sender; `[]` → empty state; anon key public/shippable).
- **Does NOT `mark_opened`** — a web glance is not a read (read = opened-in-full in-app).
- **Install button LIVE** → `testflight.apple.com/join/rjAS4cnk`; web funnel verified end-to-end on device.
- **Brand:** dark purple; trust-line "free · no ads · for real" — true: **v1 ships 100% FREE (no paywall).**
_(Full shipped copy, og-tags, three-tier animation ladder + original write-up archived below — stale "monetizes via paywall" corrected to v1-100%-free.)_

### ⭐ PATH-1 NOTIFICATION + LIFESPAN + GROWTH
- **PATH 1 push:** reuse the **EXISTING notification setup** (already mocked up). Copy
  TBD at build. The push is **PART of the experience** (pulls them in to see the
  animated arrival), not just transport.
- **LIFESPAN + SAVE/DELETE:** ordinary thoughts **fade ~30 days**; the recipient can
  easily **SAVE** (keep past fade) or **DELETE** — type-agnostic, in-app only.
  **PRINCIPLE:** if cheap + low-risk + not-feedback-dependent → **JUST BUILD IT** (no
  heavy test setups); exact fade timing / cap details don't matter until real usage
  reveals problems. Possibly **Phase-2-able** — decide at build. **Special packs/cards**
  (super-animations) = more permanence + likely **app-required** (the web gets ordinary
  thoughts only).
- **GROWTH (a noted dynamic, not a to-do):** no-app receivers convert via **accumulated
  thoughts** (the *relationship* converts them, not marketing) + the short-code claim
  **hands them the whole piled-up set on install** = a rewarding first experience.
  **Conversion threshold = sign-in.**

### ⭐ STANDING PRIORITIZATION PRINCIPLE (Joshua)
**Cheap + low-risk + not-feedback-dependent → just build it** (no long test setups).
The problems worth pausing for are **"looks crappy / people won't use it"** — NOT
exact-config details (fade timing, caps), which are *good* problems that wait for real
usage. More use → more people → don't pause for edge-perfection.

---

## ⭐ WORK CLUSTERS (prioritized) — PAIRING = RELEASE GATE

_The live priority view (supersedes the POST-TEST QUEUE (now archived) as the "what's next" ledger; that queue is
kept for history). **One cluster gates the release; the rest is iterative polish — batch-test, cut a line
for v1 whenever satisfied.**_

### ★ PRIORITY 1 — PAIRING / CONNECTION (RELEASE-GATING — the only cluster that blocks shipping)
The connection **MECHANISM works** (forms / persists / displays — proven). The **CONTACT-LIFECYCLE layer**
on top is now **DESIGNED + DECIDED**. The three pieces **INTERLOCK** (one display funnel —
`stampConnections` — over `syncConnections` / `link_connections`); **build order: P3 → P2 → P1.**
(Full design: `reports/pairing_completion_plan.md`.)

**★ THE CORE RULE (decided): ONE CONTACT PER USER ID.**
- The **user ID (`senderID`) is the durable routing key** — it SURVIVES and STICKS.
- An incoming connection for an ID you ALREADY have on a contact → **AUTO-ATTACHES** to that contact (via
  `person(forSenderID:)`) — **NEVER creates a second contact for the same ID.**
- The **NAME** is whatever the user set (or what was picked up on send/connect if unset) and is **ALWAYS
  user-editable**; the incoming server name (e.g. "Alice") **NEVER overwrites** the user's name (e.g. "Mom")
  — **fill-empty-only.**
- This **KILLS ONGOING duplicates.** **EDGE (accepted):** the FIRST connection from a never-connected
  **manual** contact (no ID yet) can create ONE dup; user cleans it **once** via delete/rename, then the ID
  rule keeps it clean forever.
- **DECIDED: NO auto-merge, NO merge tool, NO name-based matching** — the app cannot know two
  differently-named contacts are the same person (Mom vs Alice), so it never guesses. **"Let it live, user
  cleans up."** _(SUPERSEDES the earlier "WARN — which to keep? — merge/discard" sketch.)_

**P1 — RECONCILIATION = VISIBILITY ONLY (no merge).**
- **Dedupe automatically ONLY on same ID** (`person(forSenderID:)` — already does this; **harden** so an
  incoming ID can never double-create).
- **SAME-ID ANNOTATION:** if two contacts somehow carry the same ID, annotate so the user SEES it — e.g.
  *"Mom (same id as Jess)"* / *"Jess (same id as Mom)"* — **visibility only, no action taken.**
- **SAME-NAME DIFFERENT-PEOPLE:** a **"(2)" display suffix** to disambiguate in the People list / picker —
  **DISPLAY-ONLY, computed at render, NEVER written into `Person.name` or into messages/thoughts.**
- The **People tab is the human resolution surface**: user resolves any duplicate via **RENAME** (exists) +
  **DELETE** (P2 makes it stick).

**P2 — DELETE-DISCONNECT (THE LINCHPIN — "let it live" only works if delete STICKS).**
- **Option A — ONE-DIRECTIONAL (DECIDED):** delete clears **MY** `link_connections` row — RLS delete policy
  `for delete using (auth.uid() = sender_id)` + client delete in `SupabaseService.deleteConnection(other:)`.
  Removes them from my list + **STOPS the re-surface.** Smallest; **no SECURITY DEFINER.**
- **Bilateral (Option B) PARKED** (a deliberate later product/consent call — does deleting forcibly
  disconnect them too?).
- **Ordering:** `deletePerson` → **async**; when `senderID != nil`, **await the server disconnect BEFORE the
  local delete**; guard re-surface on failure. Update swipe-delete callers.

**P3 — SYNC-LAG (smallest, independent — BUILD FIRST).**
- No realtime/poll for `link_connections` today (sync only on `RootView` `onAppear` + foreground).
- **FIX:** piggyback the existing **`"pointward"` realtime channel** (`SupabaseService.startRealtime`) — add
  a `link_connections` INSERT subscription (filter `sender_id=eq.me`) → on insert, trigger
  `stampConnections`. RLS already permits. **No SQL.** _(Old #3 sender-reinstall re-stamp = **FIXED** by
  `256e854`.)_

**INTERLOCKS:** `stampConnections` is the **single display funnel** — P3 adds a trigger, P1 hooks
annotation/dedupe, P2 prevents re-surface via ordering. **Don't regress the `256e854` fallback.**

**✅ STATUS (2026-06-23): the cluster's HAPPY PATH is BUILT + VERIFIED (logic + server) — but see the KNOWN GAP below.** P3 realtime (`366fe79`), P2
delete-disconnect (`bcee4fe`, migration APPLIED + verified live), P1 same-id guard + visibility (`2c2f535`),
9/9 test harness + `[conn-di-seam]` (`9cf858f`). Supabase MCP confirms `link_conn delete own`/`read own`
policies live, `record_connection` SECURITY DEFINER, no bilateral RPC. REMAINING = ONE manual two-phone
pass (real APNs-to-closed-app, true cold install, UI render incl. "(2)"/"same id as" rows, P3 live socket;
`reports/connection_test_harness.md`).

**✅ CLOSED for v1 — delete→reconnect re-green FIXED + VERIFIED end-to-end (was: MISSING PER-SIDE CONNECTION
STATE).** **SERVER:** `record_connection` upserts (`[conn-reconnect-fix]`, `07c770c`: `on conflict do update
set via_message_id = excluded.via_message_id, connected_at = now()` — was `do nothing`) → reconnect re-fires
+ refreshes the via (stale-via gone); migration `20260624000000` applied + MCP-verified. **CLIENT (built):**
`stampConnections` falls through to `connected_user_id` on a dangling/absent SentLink (`07c770c`),
`deletePerson` deletes the contact's SentLinks, `record_connection` re-fires on EVERY open, realtime
`onConnection` re-runs `syncConnections`. **VERIFIED:** S1–S5 (within 16/16 `ConnectionClusterTests`, incl.
testS2 = the bug) + **DB-scenario S6/S7/S8 PASS via MCP** (`reports/connection_fix_bank.md`) + **S9 two-phone
DEVICE-CONFIRMED** (`reports/s9_device_result.md`: clean connect greens → delete→reconnect → sender RE-GREENS,
server-verified). Client-code trace: `reports/audit_perside_client_reconcile.md`. **DEFERRED (post-v1, NOT
gating):** an explicit per-side state MACHINE (pending/recorded/consumed/expired/failed per side) + an
optional live-DB assertion layer vs the hermetic mock. _(Symptom/root-cause kept below for the record.)_
- **Symptom:** John sends Jess a link → she opens → SHE greens John; FIRST-CLEAN connection → John ALSO
  greens (both sides aligned). Then **John deletes Jess (P2 clears only HIS row) + re-sends; Jess's phone
  still thinks they're connected → her open reports nothing new → John never re-greens.** Diverged sides
  never reconcile (Jess: "already connected, nothing to report"; John: "waiting for a signal that never comes").
- **What's missing:** each side tracks its OWN connection state to the other; a re-send to someone who
  already has you must STILL re-confirm back to the (now-disconnected) sender.
- **⭐ STRATEGIC FOLLOW-ON — per-side state enables DB-LEVEL TESTING:** per-side state in the DB makes
  connection scenarios SQL-testable (set "John-deleted/Jess-didn't", "both connected", "one-sided" → assert
  the app reconciles) WITHOUT two phones — the planning chat drives them via Supabase MCP. Shrinks the
  two-phone pass to the truly-irreducible (real APNs, real cold install).
- **🧭 GENERAL PATTERN — HANDOFF BOUNDARIES NEED EXPLICIT STATE (audit each when touched):** every
  cross-system handoff — connection signal (sender↔receiver), clipboard/pending-link (web→app), push/APNs
  (server→closed app) — should track explicit per-side status (pending/recorded/consumed/expired/failed),
  NOT fire-and-forget one-shot. Tonight's sender-not-green = a missing-per-side-status case; the **clipboard
  pending-link LIKELY has the same latent gap (predicted — will surface).** Explicit boundary status is BOTH
  the robustness fix AND the automation enabler (set status → assert transition).
- **NEXT SESSION (AUDIT + DESIGN, not a one-liner):** (1) AUDIT the model (single `link_connections` row vs
  per-side; where `fetchMyConnections`→`stampConnections` / `SentLink` / `via_message_id` breaks on
  reconnect). (2) DESIGN per-side status (reconcile on divergence; re-send re-confirms back) — consider
  `record_connection` UPDATE-on-conflict + `stampConnections` match on `connected_user_id` (robust to
  reconnect / old-link / re-add). (3) BUILD the fix. (4) **DB-SCENARIO TEST SUITE = AN EXPLICIT
  DELIVERABLE** — the fix ships WITH its automated connection-scenario tests (clean-connect · delete→reconnect
  · one-sided · both-sided · churn) so the manual phone-dance is never needed for connection logic again.

**P3 REALTIME — publication FIX LIVE (DB-verified).** `link_connections` IS in the `supabase_realtime`
publication (verified live; publication: `compass_bearings`, `link_connections`, `pings`) → INSERTs
broadcast. **NOTE — REPO HYGIENE ONLY, not a DB-state gap:** Supabase's migration tracker is empty (this +
the `record_connection` upsert were applied via the dashboard SQL editor, not the migration system), so
writing `supabase/migrations/<ts>_link_conn_realtime.sql` + the upsert `.sql` is REPO-RECORD hygiene — **the
live DB already has both.** **Realtime-LIVE** (green pops without relaunch) still owes one clean two-phone
re-confirm.

**✅ VERIFIED WORKING (2026-06-23 two-phone test):** item-3 same-name **"(2)" suffix** in People + compose
shows the **RAW name** (P1 d) · **P2 delete-disconnect** — deleting a *properly-stamped* connected contact
cleared the server row (MCP-verified empty) + did NOT re-surface on relaunch (the earlier "didn't clear"
was the churn / broken-stamp case → local-only delete, **consistent with the per-side gap, NOT a P2 bug**) ·
**one-directional disconnect confirmed by design** (after John deletes, Jess still shows John connected —
sender-only RLS delete; bilateral PARKED Option B — v1-acceptable) · **connection row forms reliably on
receiver open** (server-verified, multiple fresh rows) · **first-clean sender-green worked once**
post-publication-fix.

**✅➡ This cluster is CLOSED for v1: HAPPY path (P3→P2→P1) + the delete→reconnect re-green fix
(server upsert `07c770c` + client reconcile, built) VERIFIED end-to-end — S1–S5 (16/16) + S6–S8 (MCP) + S9
two-phone device-confirm. v1 is SHIPPABLE on connection grounds. (Deeper per-side-state MACHINE = post-v1,
not gating.)**

### PRIORITY 2+ — ITERATIVE / NON-BLOCKING (batch-test after several changes; cut a line for v1 whenever satisfied)

**✅⭐ ARRIVAL PARITY — CODE-COMPLETE (every arrival path → one shared `ArrivalSequenceView`); ⚠️ Stage-3
two-phone verify OWED.** Principle (John): an arrival should feel like an EVENT — **envelope → transit
("watch it fly in") → receipt → reveal** — regardless of how it arrived. **R1 fragmentation gap CLOSED.**
ALL four arrival paths now route through the shared **`ArrivalSequenceView`** (`HomeLink/Views/`):
- **PATH-1 (connected / direct ping)** — `RootView:622` `nowPlaying` cover → `ArrivalSequenceView` (`b7fdd24`).
  POLICY stays at the call site: `onOpened: markOpened` (**PATH-1 CONSUMES** — read-receipt/`recordCaught`),
  `onFinished: finishedPlaying + appState.idle`, `.onAppear: catchMode + select-sender + compass.start`.
- **PATH-2 (link / short-code)** — `IncomingMessageView` builds an `Arrival`, presents `ArrivalSequenceView`,
  then does its own landing/compose-back/opened-flip (`ea4f4b0`). Byte-identical (strict same-instant).
- **HISTORY REPLAY (bucket)** — `ReplaySwipeContainer` → full sequence on ENTRY, instant reveal on
  PREV/NEXT/DELETE-nav (`15c60f5`); **opened-flip SUPPRESSED** (`onOpened: {}`, `remoteID nil` = re-feel,
  locked bucket decision #1).
- **HISTORY REPLAY (PersonDetail)** — single-item cover → full sequence, dismiss on tap/6s; opened-flip
  suppressed (`884d785`).
**Architecture:** `AnimationDispatch` (pure send/receipt dispatch, `00e97b6`) → `ArrivalSequenceView`
(envelope→transit→receipt→reveal from a neutral `Arrival { ping, senderBearing }`; transit via
`AnimationDispatch`). The POLICY (fetch/side-effects, opened-flip/consume, landing, catch-mode, dismiss,
badge/queue) stays with each caller; the shared view emits only `onOpened`/`onFinished`. Stages: **0** pure
dispatch (`00e97b6`) · **1** `ArrivalSequenceView`/PATH-2 (`ea4f4b0`) · **2** bucket replay (`15c60f5`) ·
**2b** PersonDetail (`884d785`) · **3** PATH-1 backbone (`b7fdd24`). Tests: dispatch + `Arrival` builder
locked (`AnimationDispatchTests` + `ArrivalSequenceTests`); full `HomeLinkTests` 238/238.
- **⚠️ OPEN — Stage 3 (PATH-1) NEEDS TWO-PHONE VERIFY (backbone; real devices):** (1) warm-foreground
  realtime → full sequence plays; (2) closed-app **push** (real APNs) → tap → full sequence; (3)
  `markOpened`/read-receipt fires ("opened ✦" + history); (4) dismiss + **queue advance** +
  `appState→.idle` (no stranded catch-mode); (5) cold-launch restore still **badge-only** (user taps → full
  sequence); (6) **F2** receipt sound/haptic now lands WITH the receipt (after the 1.6s envelope+transit,
  like PATH-2) — confirm not "late"; (7) **F1** transit flies from the current compass bearing (like PATH-2;
  the receipt still aims at the sender) — confirm acceptable. _(reports/arrival_stage3_applied.md.)_
- **Optional cleanup (future pass):** hard-delete the `#if false [arrival-parity]` originals (the relocated/
  replaced bare-arrival blocks in `IncomingMessageView`, `CompassView`/`ReceiptView` dispatch ladders,
  `SenderAnimationView` ReplaySwipeContainer, `PersonDetailView`, `RootView:622`).
_(Refs: reports/arrival_stage{0,1,2,2b,3}_applied.md.)_

**ANIMATION CORRECTNESS & VERIFICATION** — verify the full sequence plays correctly at ALL stages, across
ALL send+receive paths + ALL instruments. **✅ PATH AUDIT DONE (2026-06-24, `f6ad2b4`, reports/path_audit.md)
— these feared bugs are DISPROVEN by code (stale canon, NOT regressions; do not chase):** ~~birthday cake
renders the ARROW~~ (FALSE — `BirthdayCakeSendAnimationV2` renders the cake), ~~candles double-fire~~ (FALSE
— single `ForEach`, 0.4s blow debounce), ~~firework box~~ (FALSE — custom `FireworkGlyph`), ~~foreground
direct-ping plays NO animation~~ (FALSE — the FULL send animation plays on BOTH paths; `flightToken` is set
`CompassView:2258`, BEFORE the path branch `:2336`), ~~#12 Plane v1-not-v2~~ (RESOLVED = **V2**;
`PlaneReceiptAnimationV2` is LIVE). **The real arrival gap "A2 is LINK-path only" is reframed + promoted →
see ⭐ ARRIVAL PARITY below.** STILL OPEN (unverified, lower priority): **#13 aiming-order**; **#14
send-sound distortion** (⚠️ verify in **Release** first — may be debug-only); residual **device-test debt**
(thoughts-toggle removal, bucket-delete, replay rework, compose-uniformity, birthday default msg, mic-denied
wind, Special Moments stages). _(Replicated-dispatch extraction folded into ARRIVAL PARITY + the harness item.)_

**RECEIVE-PATH / SCREENS REDUCTION** (principle: **FEWER SCREENS THE BETTER**) — map every screen across
the scenario matrix (cold/warm × paired/unpaired × has-app/no-app), then **ELIMINATE to the fewest
necessary**. Includes: **3-door landing reconsidered per install method** (some doors nonsensical per
arrival — e.g. "install Pointward" to someone who just installed; **R2/R3:** the 3-door landing is reachable
ONLY on PATH-2 × not-onboarded, and an `enteredViaLink` guest can desync the gate so a later link re-shows
the doors — `IncomingMessageView:336-344,:150-153`); **foreground-ping presentation** (→ ARRIVAL PARITY).
**✅ 2c compose-back routing — RESOLVED CORRECT (path audit):** it routes to SEND-OUT (compass, pre-aimed at
the sender via `.pointwardOpenCompass`), NOT the receipt — there is no reply affordance inside `ReceiptView`.
The "RECEIPT-not-send-out / needs device-repro" worry is closed. _(Screen inventory: ~30 surfaces; no
elimination beyond the 3 dead files in DEAD-CODE; `PaywallView` inert-but-kept for monetization revert.)_

**COMPASS INTERACTION** — **HOLD → LOCK → TAP TO SEND** (hold aims/points at the person, locks on-target,
single **TAP** sends — NOT auto on lock; update the instruction copy to show all 3 steps). **OVERLAPS
parked Compass v2** (red marker + haptic + lock-on-target) — same work, do together.

**CONTACT MODEL / UX** — per-person emoji maybe unnecessary (review); **PHOTO on the contact list** (may
SUPERSEDE the emoji — pair these decisions).

**PEOPLE / CONTACT UX BUGS (2026-06-23 device test):** (a) **TAP-NAME-OPENS-EDIT** — tapping a person's name
in People opens EDIT; should SELECT / switch the send-target (edit only via the edit affordance) — real
change. (b) **ADD-PERSON FORCES ADDRESS** — can't skip address on add (ties to the parked "don't force
address"). (c) **CONTACTS-PICK OVERWRITES TYPED NAME** — picking from Contacts clobbers a typed name;
decide precedence. _(NOT a bug: post-receipt "type a message" was user error — compose hit at receipt end.)_

**ADD-PERSON — CONTACTS-PICK PREFERRED** (design — **verify build-state; may need building**) — **bump
toward the TOP of this cluster** given the connection-correctness benefit (PREVENTION for the pairing
cluster, though non-pairing itself):
- Adding a person offers **"pick from Contacts" vs "manual entry"** — **Contacts-pick PREFERRED** (richer/
  firmer info). A picked contact pre-fills in ONE shot: **contact name** (firm) + **address** (firm — feeds
  the compass) + **DELIVERY CHANNEL** (phone/email, firm) + **display name** (editable on top; name/address
  are firm).
- **AT FIRST SEND** the app already knows WHERE the link goes (the contact's phone/email) → **no picker, or
  AUTO-SELECTED** → fewer clicks. _(Impl note: pre-addressed compose via `sms:`/`mailto:` — a modest
  send-flow change vs the current share sheet; channel auto-selected but overridable.)_
- **RESOLVES canon's open "send-channel fork":** YES — **store the send channel on the `Person`** from the
  Contacts pick.
- **ALSO REDUCES WRONG-PERSON CONNECTIONS:** auto-addressing to the contact's real phone/email tightens the
  bind between "who I selected" and "who receives it" → fewer mis-sends → fewer surprise duplicates. So
  **Contacts-pick = PREVENTION; P2 delete-that-sticks + P1 same-id annotation = SAFETY NET.** _(Caveat:
  reduces, doesn't eliminate — forwarding / shared numbers / other-account opens still possible.)_
- **Manual entry remains the fallback** (no pre-filled channel → picker as today).
- **ALSO FILED (friction):** the "Apple choice screen" at first send after a Contacts-pick — **VERIFY which
  screen**: Sign in with Apple (Apple-mandated, not skippable) vs the app's own name/info step
  (pre-populatable from the Contacts data). **If it's the app's own → pre-fill, don't re-ask.**

**PRE-LAUNCH POLISH** — **free-for-now messaging screens** (intentional-free + honest future-**1×**-pay
heads-up to avoid bait-and-switch; `PaywallView`/Pro section repurposed; define **core-vs-special**); **WEB
message background animations on the `/m/` page** (entice install — visual works great on web); **Settings
review** (Help/FAQ/feedback picker); **copy pass** ("mini card" voice); **health-audit Tier-1 deletes**
(dead `ProSetupView` ~1019 lines); **structural cleanup map** (SupabaseService split, CompassView
extraction, `pairedUserID` migration); **receive-path regression harness** (old BUILD #4). **HONEST
DELIVERY (S1, path audit `f6ad2b4`):** the "sent to [Name] ✦" toast fires from `finishSend` UNCONDITIONALLY
(`CompassView:2339`); a PATH-1 `sendRemote` failure only surfaces later via `sendFailedNotice`
(`PingManager:290-304`) — so the animation + "sent" can both show while the insert later fails. Tie the
confirmation to actual insert success (or downgrade the toast until confirmed). Small, pre-launch.

**CODE CLEANUP (END-STAGE, CONDITIONAL — do LAST, only if it eases future dev or speeds runtime):** dead
`ProSetupView` ~1019 lines · structural map · A2-dispatch → shared `SendStageView` · hard-delete the
preserved comment blocks · test audit · AND the private/one-off **SQL scratch scripts** (nothing needs
saving — but KEEP `supabase/migrations/`, toss only scratch).
  **+ path-audit dead code (`f6ad2b4`):** 3 orphan view files — **BucketCatchView** (extract
  `BucketShape`/`BucketHandleShape` FIRST, reused by BucketTipView), **SkinPickerView**, **SkinQuickPicker**
  (0 refs each; superseded by `InstrumentOptionPicker`); **R5** stale `ReceiptView` comments
  (`:96-100,:229-256` say bow/flick/plane use `standardReceipt` but they dispatch V2); **X1** dead emitter
  `.pointwardOpenThoughts` (`CompassView:1577,1599`, receiver commented `RootView:660`); **X2** commented
  `/pair`,`/join` branch (`RootView:270-285`, AASA still lists `/pair/*`); **R6** Birthday/Firework dead
  receipt helpers (`FireworkReceipt:268-383`, `BirthdayCakeReceiptV2:92-102`).
  **+ test-hardening (path audit):** extract pure `sendAnimationKind(for:)` / `receiptKind(for:)` from the
  inline `CompassView` flightToken ladder + `ReceiptView` switch → makes "path X stage Y → animation Z"
  UNIT-assertable with NO device (path selection, instrument→style→dispatch, share-defer, 3-door gate,
  short-code split). Highest-value harness add; pairs with the ARRIVAL PARITY extraction.

**DEFERRED ENHANCEMENT** — **"send one back" auto-select-sender** (auto-switch the selected person to the
sender for an easy reply).

**⭐ WEB MESSAGE TEASERS (conversion / `pointward-website`) — own focused web session, distinct from
app-side work.** GOAL: the `/m/[id]` page shows a **2s looping per-style TEASER** — an *incomplete ritual*
(e.g. rocket counts "3…2…" never reaching 1 + a **blurred hidden-message** rect + "*Tap to see what [Name]
sent ✦*") that visually **echoes the app send animation** → drives install. This is THE conversion surface.

- **⭐ PREREQUISITE ALREADY MET (verified live via Supabase MCP — NO app change, NO migration):**
  `messages.instrument` exists, the app populates it on EVERY link send (`CompassView:2351` = `style.rawValue`),
  and `get_message` returns it (`select *`). Real rows confirmed carrying `glow / bowArrow / rocket / plane /
  birthday / firefly / fingerFlick / wand`. The web page just needs to **READ `msg.instrument` and pick a
  teaser** — it currently ignores the field (renders one generic emoji+halo for every send).
- **KEY = `SenderStyle.rawValue`** (the camelCase wire string == `pings.sender_style` == `messages.instrument`;
  the column is *named* `instrument` but stores the STYLE). 9 in-scope: `glow, bowArrow, firefly, fingerFlick,
  rocket, wand, plane, birthday, firework` + legacy `shootingStar` + `null` → generic. Keys MUST be the exact
  camelCase strings; unknown → generic (mirrors `SenderStyle.from()` → glow).
- **ARCHITECTURE (all inline in `pointward-website/404.html`; no build system, no external assets):**
  (a) **TEASERS registry** `{ style → core }`; (b) **ONE shared template frame** — kicker "[Name] sent you a
  thought" + a swappable **animated-core slot** + the sealed/blurred **hidden-message rect** + "Tap to see
  what [Name] sent ✦" + the **2s never-completing loop** + the existing install CTA / clipboard bridge
  (untouched); (c) **9 swappable inline core builders + 1 GENERIC fallback** (today's emoji+halo render IS the
  fallback). `teaserFor(msg.instrument)` → core; unmapped/null → generic.
- **VISUAL DNA:** reuse exact `DesignTokens` hex (the page already half-matches: bg `#0d0d14`, accentSoft
  `#c4a8d4`); each core echoes its app send file's shapes/palette/motion (per-style capsules in
  `reports/web_teaser_architecture.md`); preserve the per-style sky — **7 night/space**, **wind/firefly =
  daytime `#87CEEB` outlier**, **birthday/firework near-black `#06–08`**.
- **BUILD ORDER (de-risked):** shared frame → registry + GENERIC fallback (ship FIRST — every message gets the
  generic teaser, zero regression) → cores one at a time by *wow* (**rocket, firework, birthday first**), each
  independently shippable (unmapped → generic).
- **⭐ PENDING PRODUCT DECISION (website-repo call):** the `/m/` page currently shows `msg.content` in CLEAR
  text; the teaser implies HIDING it (blurred rect → tap to reveal). Decide **(i) seal/blur the content**
  (stronger conversion — RECOMMENDED) vs **(ii) keep a short preview + the teaser core above it.**
- **MINOR LIVE-PAGE BUG (flag, unrelated):** `404.html render()` reads `msg.short_code` but `messages` has no
  `short_code` column (it's on `users`) → dead branch; safe to remove.
- **TESTABILITY:** `teaserFor(style) → core` is a **pure JS function — unit-assertable** (9 keys → their
  cores; null/unknown → generic). Visual fidelity (does the web teaser echo the app) is **irreducibly manual**
  (eyeball web vs app side-by-side). The mapping needs no network; end-to-end render needs one live
  `get_message` row.
- Refs: `reports/web_teaser_architecture.md` (full); `pointward-website/404.html` (current /m/ page);
  app key sources `SenderStyle.swift`, `Instrument.swift`, `CompassView:2351`, `migrations/…short_code_messages.sql`
  (messages + get_message). _(Edit the website in `pointward-website`, NEVER in HomeLink.)_

**ANIMATION-ARCHITECTURE CONSISTENCY PASS (app-side; SEPARATE future thread — flagged by the web-teaser
audit §7, NOT the web work).** Structural drift in the animation system, banked for a dedicated pass (none
blocks the web teasers — the wire key is stable):
- **3 live sends are inline in `SenderAnimationView.swift`** (glow `:286`, rocket `:1353`, firefly/wind `:413`)
  while bow/flick/plane/wand have dedicated `Instruments/*` files — inconsistent "where the send lives."
- **No uniform V1/V2 scheme:** bow/flick/birthday are `*V2.swift` (V1 retired-but-present), plane/wand/firework
  are single un-versioned files, glow/rocket/wind are inline.
- **Special Moments mis-housed** under `Instruments/_Shared/EmojiReveal/` rather than their own folder like the
  7 instruments.
- **`SenderStyle.shootingStar` is an orphan** (`SenderStyle.swift:12`) — legacy inline `shootingStarSend`, no
  instrument, not in the live dispatch; still carried through every exhaustive switch.
- **Dispatch — send+receipt SELECTION now CONSOLIDATED** into the pure `AnimationDispatch` (`00e97b6`,
  unit-tested), consumed by `CompassView` flightToken + `ReceiptView` + `ArrivalSequenceView`. REMAINING:
  `SenderAnimationView.body`'s inner inline-send switch (the `.shared` styles glow/shootingStar/firefly/rocket
  + dead birthday/firework arms) + `RevealAnimationRegistry` (the reveal layer).
- **`firefly` vs `wind` naming drift** — the live wind instrument runs under `SenderStyle.firefly` /
  `fireflySend`; user-facing name still "firefly."
- **`messages.instrument` stores the STYLE rawValue, not an instrument** (`CompassView:2351`) — column name
  implies instrument; contents are style (wind→`firefly`, special moments→`birthday`/`firework`). A future
  rename to **`sender_style`** would align it with `pings` (⚠️ migration + web-key + app coordination — NOT
  the web teaser work, which keys on the value as-is).
- **Wand uniquely presents `EmojiRevealView(.sent)` internally** (`WandSendAnimation.swift:52-59`) while every
  other send file's header says it does NOT — a violated shared contract.
- **Timing truth duplicated** across `SenderStyle.sendDuration`, `InstrumentBoundaries`, and each view's own
  hardcoded `total` (e.g. Bow 2.30 decoupled from the enum).
- **Manifest live-row LABEL vs DISPATCH mismatch:** `AnimationManifest.liveInstruments` filters out
  `V2`/`Parachute`/`Legs-down` → labels **V1** as the live row for bow/flick/plane/birthday, but the views /
  `AnimationDispatch` actually dispatch **V2**. (Cleanup C4 fixes the labels.)
- **Under-wired manifest data:** `defaultEmoji` is a blanket `🤗` for 7 of 9 (only birthday 🎁 / firework 🎆
  override); `defaultTagline` was unwired (0 readers) → **REMOVED 2026-06-24 (cleanup C3)**; `instrumentHints`
  is wired only as the fallback (see SOURCES OF TRUTH). **Wand has no dedicated receipt (R4)** →
  `standardReceipt` (`ReceiptView:130-135`).
- **➡ ROADMAP = `reports/animation_consistency_map.md`** — the per-style bundle + the ranked,
  independently-shippable cleanup plan (C1–C10) for THIS pass. **Pre-launch-safe slices DONE (this commit):
  C1 (docs) + C3 (drop unwired `defaultTagline`).** The rest are **post-TestFlight, AUDIT-FIRST** (they touch
  animation/instrument/receipt/reveal files): C2 hard-delete the `#if false [arrival-parity]` originals (after
  the arrival two-phone verify) · C4 manifest version labels · C5 inline sends→dedicated files · C6 re-house
  special moments · C9 `shootingStar` · C10 wand receipt · C7 per-style bundle. ⚠️ **C8 (`firefly`→`wind`
  rename) is WIRE-BREAKING** — `SenderStyle.rawValue "firefly"` is PERSISTED (history) + on the WIRE
  (`pings.sender_style`, `messages.instrument`) + the WEB-TEASER key → **post-launch ONLY, with a migration.**
  None of C2–C10 is a v1 blocker (the system works — path audit + arrival parity confirmed).

---

## ⭐ FUTURE / POST-V1 — ANIMATION TIER FRAMING + IDEAS (clearly separated; not v1 work)

**THE TIER LINE — "is there an interactive mechanic":**
- **GENERIC SEND = FREE (passive):** rocket / fling / wind / arrow + a **CATCH-BUCKET free-tier receipt**
  (tilt/move to catch, from a direction) — the bucket **already exists in code** as
  `ReceiptView.standardReceipt`.
- **INTERACTIVE RECEIPT = PAID ("the cool ones"):** **COMPASS** (pointing/aim/lock — the signature
  interactive mechanic; **PRICING NUANCE:** maybe Compass stays **FREE as the hook** while active-receipt
  ones are paid), **BIRTHDAY CAKE** (blow the candles), **BALLOON** (pump → float → pop on receipt),
  **HEARTBEAT / valentines** (finger-on-camera pulse, sender + receiver), **NEW YEARS** (yell into the mic
  after a countdown).
- Maps to the **1×-pay future model** (non-consumable, NOT subscription).

**ATTACHMENTS (future — later):**
- **VOICE attachment / custom voice on a thought** — was **BUILT then REMOVED**; keep as a future option
  (attach a voice note to a send). _(Consolidates the earlier "custom VOICE messages — keep for future"
  note — one entry now, not two.)_
- **PHOTO / other media attachments (LATER-LATER)** — consider allowing a photo (or other media) attached
  to a thought. Further out, exploratory.
- **Shared note (both):** these are **BIGGER than the current data model** — Pointward today sends
  text + emoji + instrument (small, fit in the `messages`/`pings` rows). Voice + photos are **BINARY MEDIA**
  → need **file storage** (Supabase Storage or similar), upload/download, size limits, and rethinking how the
  `/m/` link **carries** them + how they ride the receive animation. **NOT quick toggles — a
  media-attachment subsystem.** Scope realistically when picked up.

**FEASIBILITY ANCHOR:** the **visual works on WEB** (no app — viral on-ramp); **interactive receipts**
(mic / camera-PPG / haptics / motion) need the **APP** (iOS web mic flaky; camera-PPG / haptics / motion
are native). ➡ **web = lightweight on-ramp; app = the interactive / connected / paid moat.** _(More
business + animation ideas parked for a dedicated future-ideas session.)_

---

# ⭐⭐ PRODUCT DIRECTION DUMP (this session — future work; decided-vs-for-thought)

### ⭐ APP CONCEPT / POSITIONING (canonical — for About + App Store copy)
- **PRIMARY — emotional connection:** elevate the good feeling of a text / emoji to a
  higher level by increasing the **INTENT** put into a send and the **MEANING** for the
  receiver — via **directionality, intentional sending, and animations.**
- **SECONDARY — special occasions:** a reaction *against* card apps (monthly fees, high
  cost, low customization, clunky desktop, snail-mail delay, or impersonal email).

### ⭐ HELP / FAQ / HOW-TO + ABOUT (future build)
A help / how-to system, **accessed from SETTINGS (top), OPTIONAL** (watch if you want,
never forced). It is **the EXPLORABLE HOME the onboarding showcase content moves into**
(see the North-Star: showcase out of the gate → an explorable section). Contains **ALL
functionality explained — requirements AND value/why** (the how-to carries the concept:
e.g. *"send with wind = blow into the mic"* + **WHY** the action adds intent / meaning).
- **FAQ (troubleshooting), e.g.:**
  - *"the compass doesn't point toward the person"* → the app needs an **address** to
    find the pointed location's GPS; ensure the correct address is on that contact in
    the **People** tab.
  - *"do you really give to charity?"* → **yes**; findable on the charity site under
    donor name **"Pointward."**
  - *"I can't send a message"* → you must **select an emoji OR explicitly tap the
    no-emoji option**; some sends require **point-and-lock** toward the recipient
    (compass) or a **directional gesture** (flick, turn bow / rocket); **most require a
    send action** (blow into the mic for wind, tap for rocket, etc.).
- **HOW-TO / full capabilities:** **press on the compass screen to change the
  animation**; step-by-step send sequences; **address & why it matters**; how to **VIEW
  messages (the bucket)** + how to **SAVE / DELETE / how they persist.**
- **Carries the APP CONCEPT (above) woven in** — function + value together.

### ⭐ SETTINGS TAB — REVIEW PROJECT (parallel to the onboarding pass)
Settings already has content. **Do a FULL walk-through / catalogue** (same method as the
onboarding screen pass): walk what's there, catalogue, then plan additions / removals.
**PLANNED ADDITIONS (from this dump):**
- **Help / FAQ / How-To at the TOP.**
- **ADVANCED — "turn off send-actions":** skip the blow / tap / flick / point-lock;
  auto-play the send sequence. ⚠️ **CHECK IF THIS ALREADY EXISTS before building.**
- **FEEDBACK / comments:** *"Pointward's first app — suggestions welcome."* A
  **STRUCTURED category picker that DOUBLES as education** (the categories teach the
  anatomy of a thought-stream): new emoji / tagline suggestions · emoji + animation ·
  animation send mechanism · send + receipt action screens · general app visuals · app
  efficiency · report bug · note.
- **"CATCH THOUGHTS IN BUCKET" toggle** — **build the capability, DEFAULT OFF, do NOT
  surface on screens yet** (until the receipt mechanism is better designed; future
  receipt options may improve for the end user).

### ⭐ OCCASION FEATURES (future idea — parked)
**Birthday / anniversary NOTIFICATIONS** prompting the user to send a Pointward item —
ties to the secondary "special occasions" use case. Parked as a future engagement /
growth idea.

### ⭐ LAUNCH / MONETIZATION STRATEGY — v1 = 100% FREE (no payment of any kind)
**⭐ v1 DECISION — SHIP 100% FREE (2026-06-22, SUPERSEDES ALL earlier pricing framing — both the
"free = compass+emojis / locked = rest" model AND the optional "buy me a coffee" support idea):**
**v1 ships with NO paywall and NO payment of ANY kind** — no IAP, no tip jar / "buy me a coffee," no
commercial setup. **ALL animations/instruments are FREE.**
- **WHY:** any paid item — even a voluntary tip — requires the full **commercial setup** (Paid Apps
  Agreement, banking/tax, IAP products), which is **not worth it for v1.**
- **NEAR-TERM APP WORK (record only — do AFTER the current receive/push two-phone test; NOT a launch
  blocker beyond this):** a small **"unlock everything / disable the live paywall"** change so every
  instrument is free in Release. (`PaywallView` is currently **LIVE in Release**, only
  `#if DEBUG`-suppressed in dev — this change makes Release match "100% free.")
- **REVISIT PAYMENT ONLY ON REAL TRACTION:** watch **App Store Connect Analytics** (free, built-in —
  **no analytics SDK / no code for v1**) for **ACTIVE / RETAINED users, NOT just downloads.** Rough
  bar to even *consider* adding payment later: **~1,000+ active users.** Below that, stay 100% free.
- **TESTER-UNLOCK SUPERSEDED:** everything is free, so internal testers exercise ALL animations with
  no special unlock (`reports/tester_unlock_spec.md` kept but **marked SUPERSEDED-FOR-V1**, only
  relevant if a paywall ever returns).

_DEFERRED — the monetization thinking below becomes relevant ONLY if/when traction crosses the bar
above and payment is reconsidered. It is NOT a v1 plan._
**PRINCIPLE (endorsed, IF payment is ever revisited):** **seed the network FREE before monetizing.** An
emotional-connection app is **worthless to a new user if no one they know is on it**, so
charging before the network exists would kill it. **Be generous early** (cheap when few
users); **monetize only once the product is genuinely valuable to that user** (connected
+ engaged).
**DIRECTION (Claude's lean — for a later decision):**
- **Founding cohort** (e.g. first 100) get **Pro FREE permanently** (gratitude +
  lock-in).
- **Free Pro PROPAGATES one hop** — invite someone, they (and maybe their first ~2
  connections) get Pro free — so **free-ness travels along connections**, incentivizing
  the **CONNECTING** behavior the network needs. A small viral start.
- **Don't enforce the paywall while the network is sparse** — ideally **per-user** (a
  user doesn't hit a wall until they have real connections / engagement), rather than a
  **global threshold** (hard to define / communicate).
**OPEN (for a dedicated session):** exact cohort size; how many hops free propagates;
how the paywall threshold is defined; abuse / tracking of "free" status; revenue timing.
**Joshua's variants captured:** first-100-free; invitees-free-up-to-5; first-100 + their
first-2-connections-free; paywall down only when "enough connected."

---

### Build-9 LEFT-INTENTIONALLY (flagged; for the cleanup pass / focused follow-ups)
- **4 PeopleManager pairing funcs** (`addFromInvite` / `bindConnection` /
  `insertFromInvite` / `person(forPairedUserID:)`) are **APP-ORPHANED** (Sarah
  repointed; pairing UI `#if false`) but **LEFT** — `PairingScenarioTests` (~12 of
  18) exercise them, interleaved with `redeem`/`claimOutcome` tests that STAY.
  Remove + migrate tests at the **cleanup pass** (with the test audit) — zero
  behavioural gain to do sooner.
- **Mutual-pointing — more entangled than audited**: retired at the **SOURCE** (no
  events generated) but the **dormant consumers LEFT intact** — `presenceFelt`
  (also called by **push** `NotificationHandler`), `partnerPointing*` / `mutualMoment`,
  the **CompassView ambient edge-glow** (~899-909), and `CompassManager`
  `presenceTimer` / `reportPointingIfNeeded` (now call a no-op `reportPointing`).
  Focused follow-up; the feature doesn't operate, so not urgent.
- **SupabaseService orphans** (`redeemCode` / `createProfileInvite` / `lookupInvite`,
  `PairingServiceProtocol` / `MockPairingService` + the `ServiceContainer` field) —
  LEFT (commenting the protocol/mock means editing the composition root). Cleanup.

### Onboarding Notes (bank for build 10, from live walkthrough)
Current flow is ~8 screens: Apple-messages allow → cover/begin → Sign in with
Apple → set home (name + city; **address is OPTIONAL/skippable** — confirmed
live) → emoji selection (a default emoji that does **NOT** align with
`CuratedEmoji` — likely remove) → **"your connection code"** screen (shows
**BLANK** — reads the old pairing code field, not `short_code` — repoint or
remove) → "3 ways to connect" (connector/expresser/special-moments framing, needs
refinement) → unlock-all-instruments paywall screen → 50%-to-charity tagline →
"all set" → enter app.

Build 10 should: trim ad-like screens (paywall/charity mid-onboarding is friction
for link-arrival users); keep **address OPTIONAL** (honors "more info = better,
never required" + enables build-7 degradation); fix/remove the blank
connection-code screen; fix the off-registry onboarding emoji; capture sender
display name with the agreed warning copy ("this is how everyone who receives
your messages will see you ✦").

### Infrastructure / Gotchas (bank so future sessions don't re-trip)
- **WEBSITE lives in the SEPARATE `jdcoding75/pointward-website` repo** (GitHub Pages →
  custom domain pointward.app), **NOT in HomeLink.** The old `HomeLink/website/` folder was a
  **DEAD duplicate** (served nothing, 0 Xcode refs) and has been **DELETED this session
  (2026-06-22).** Edit the website in `pointward-website`, never in HomeLink.
- **DOMAIN/DNS — ICANN gotcha (2026-06-22):** pointward.app went **down** when an **ICANN
  contact-verification lapse** made the registrar (Namecheap) **auto-change the nameservers** →
  the site stopped resolving (GitHub Pages reported the custom domain "improperly configured").
  **Resolved** by completing the verification → nameservers reverted → DNS propagated → site
  serves again. **LESSON: watch for ICANN verification emails on the domain — a lapse silently
  breaks DNS.** _(diagnosis: `reports/webpage_funnel_audit.md`.)_
- **AASA** (apple-app-site-association) is hosted in the `pointward` repo and now
  lists `/pair/*`, `/join/*`, **AND `/m/*`** (live, verified via curl).
- **iOS caches AASA hard** — device link tests may require delete+reinstall to
  pick up `/m/*`.
- **Identity — NOT forking (audit premise was WRONG; identity IS stable in practice).**
  The identity-stability audit (`reports/identity_stability_audit.md`) flagged a
  "CRITICAL" reinstall fork, **but its premise was wrong.** The two `users` rows are
  **TWO DIFFERENT APPLE IDs**, not one forked identity — confirmed by their **different
  `apple_user_id`** values:
  - Joshua's main: `3ef2a987…` / short_code **DS2CVW** / name **"John"** — 16 msgs · 1 conn · 46 tokens.
  - His **WIFE's**: `b3d85a30…` / **Y9HNEF** / name **NULL** — 0 msgs · 0 conns · 6 tokens.
  Joshua's reinstall **correctly re-resolved to his SAME account** (kept all 16 messages)
  → `users.id` / `senderID` **is stable** across reinstall. **No fork. No orphan to merge**
  (the second row is the wife, a real user — **do NOT merge/delete**). The IDENTIFY-first
  (read-only) step caught the wrong premise *before* any delicate RLS/migration touch —
  worked as intended.
- **Identity hardening = OPTIONAL/LATER (deprioritized).** The audit's fix
  (`apple_user_id` UNIQUE anchor + `ensure_identity` RPC + `auth_id` decouple + RLS
  rewrite) is **defensive hardening** against edge cases (e.g. `auth.users`-row deletion,
  Apple provider-config change), **NOT an urgent pre-family-test fix.** Revisit only if
  **real forking is ever observed in normal use.** (`users.id = auth.uid()`; `apple_user_id`
  is stored but not used as a resolution key — that's the hardening surface if ever needed.)
- **Wife's NULL `display_name` explains the "Someone" arrivals** (she has no name set) →
  reinforces **require-display-name-at-onboarding** + the arrival-name fix (display-polish
  batch #1 below).
- **The duplicate contact Joshua's wife saw was NOT identity-forking** — re-examine
  separately (likely reinstall-churn / contact-matching), **LOWER priority.**
- **`-skipOnboarding` launch arg** exists (now unchecked) — remember it when
  testing onboarding (build 10), or it skips the thing under test.
- **Retention:** time-based expiry ("x days") **NOT** implemented (`created_at`
  enables it, Phase 3). The **50-message cap is CONFIRMED** (build 9):
  `PingManager.maxCaughtHistory = 50`, FIFO drop-oldest; it now governs the unified
  bucket and opened link messages count toward it (locked decision #3).

### Banked Items (findings pass 2 — tagged with trigger build)
- **[build 8+ styling] Location-hint legibility.** The build-6 hint ("add
  location…") is too small / low-contrast on device — it's the action we want, yet
  the *least* visible, while the soon-removed pairing status row is the *most*
  visible. Increase its visual weight — but **design against the POST-pairing card**
  (build 8 removes the competing status rows), so style it after pairing removal to
  avoid doing it twice.
- **[build 9 — ✅ DONE] Sarah dev-seed repointed.** Was keyed on
  `person(forPairedUserID:)` + `insertFromInvite`; now dedups + inserts via the
  link-era `upsertContact(senderID: mockFriendID)` (mirror-write keeps her
  `pairedUserID`, so `testSkipOnboardingInjectsSarah` passes unchanged).
  `setMockDistance` repointed to `person(forSenderID:)`. Sarah remains
  **⚠️ DO-NOT-REMOVE**.
- **[build 2 / identity hardening — RESOLVED: no fork] "Duplicate `users` rows" was a
  MISREAD.** The two rows are **two different Apple IDs** (Joshua `3ef2a987…`/DS2CVW/"John"
  + WIFE `b3d85a30…`/Y9HNEF/null-name) — **different `apple_user_id`s**, not a forked
  identity. Normal returning-user sign-in **re-resolves to the SAME account** (Joshua's
  reinstall kept all 16 msgs). Identity is **stable**; hardening is **optional/later**
  (see Infrastructure/Gotchas → "Identity — NOT forking"). The wife's null name (never
  onboarded with a display_name) is the **"Someone"-arrival** source, not an orphan.
- **[build 8 or 10 audit] Onboarding emoji screen + `UserProfile.emoji`.** Joshua
  wants the emoji-selection screen removed (purposeless onboarding distraction). **Do
  NOT cut blind** — first audit what consumes `UserProfile.emoji`; if orphaned,
  remove the screen + field. Surface at whichever build first touches
  onboarding/UserProfile.
- **[Phase 3 polish] Share-sheet (sender side).** Sends via the raw iOS share sheet.
  Text content is correct (name + link + shortCode — verified) but the **sender's
  preview truncates it** (normal iOS clipping; the recipient gets the full text). The
  raw share sheet "seems sloppy" as Pointward's sending moment — polish is Phase 3.
  **NOT a bug; NOT a recipient-side visibility gap** (confirmed sender-side only).
- **[verify; animation-chat if real] Send-sound distortion.** Send sound reported
  distorted on device under a **DEBUG Xcode build** — likely a debug-mode artifact
  (consistent with the earlier "choppy animation" observation). **MUST verify in a
  release/TestFlight build** before treating as a regression. If distorted in release
  → **animation-chat** item (sound files are animation-chat territory, not Phase 2).
  If debug-only → ignore.
- **[reminder] `-skipOnboarding` is currently CHECKED** for testing convenience —
  **UNCHECK before any onboarding test** (build 10) or it skips the thing under test.
  It also **bypasses name capture** — the source of the null-name-orphan + the
  display-name-NULL bug class (see the display-name fix above).

### Banked Items (findings pass 3 — session lock-up)
- **[build 10 / People-polish — taste] Launch opens to the most-recent SENDER**, not
  the last-manually-selected person (build 6's recency launch default — Joshua
  noticed). Taste call — revisit with the People-tab polish.
- **[B1 follow-up] `MessageComposerView`** (the iMessage wrapper, defined in
  `ConnectView.swift`) is a **SHARED helper kept LIVE for PersonDetailView's connect**
  flow — it sits **outside** ConnectView's `#if false`. When B1 (PersonDetailView
  connect) is cut, **re-check if it's then orphaned**.
- **[cleanup pass] Xcode warnings — 14 total, build ships clean.** Build 9 cleared
  **2** (`compass_bearings` + `connections` `postgresChange`). Remaining for cleanup:
  hoist `PingPayload`/`ConnectionRow` (MainActor `Encodable`); `@MainActor`-annotate
  `InstrumentOptionPicker`/`ProSetupView` init calls; `subscribeWithError` + the new
  filter syntax (with an SDK bump); MapKit `placemark` → `location`/`address`; 1
  unused-var is in **locked animation territory** (animation chat). **DECISION: stay
  in Swift 5 language mode THROUGH LAUNCH** — do not flip to Swift 6 pre-launch (the
  concurrency warnings would become hard errors).
- **[Joshua-requested] Pre-App-Store CLEANUP PASS** — tighten + consolidate
  transitional logic (the mirror-write bridge etc.), **hard-delete** the commented
  code, test audit (remove dead pairing tests **only after confirming not-live**; ADD
  coverage for the link-model paths), final doc cleanup. (Now an explicit step in the
  back-half build order.)

### ⭐ PARKED / DEFERRED (session lock-down — keep visible)
- **Build-6 styling pass (post-pairing):** location-hint legibility (too small on
  device) + launch-opens-to-most-recent-SENDER (vs last-selected) — style against the
  post-pairing card.
- **Build-9 bucket device re-verify** (sender-agnostic) — a clean install wiped test
  history before confirmation; **will self-verify during later multi-sender use**, no
  special staging.
- **Build-12 reframe committed twice** (`a7c360c` + `baaf5d6`) — squash / note at the
  cleanup pass.
- **Cleanup-pass roster (consolidated):** the 4 app-orphaned PeopleManager funcs +
  `PairingScenarioTests` migration (see *Build-9 LEFT-INTENTIONALLY*); the dormant
  mutual-pointing cluster; the SupabaseService orphans; **gitignore `reports/`**; Xcode
  warnings (**stay Swift 5 through launch** — don't flip to Swift 6 pre-launch).

### Phase 2 Scope & Decisions (this session)
- **Scope — explicitly EXCLUDED** (animation-chat / parked; NOT part of the
  Phase 2 link-delivery pivot, and not gating it): **CatchMode rework**,
  **Birthday auto-blow-out + download prompt**, and **Special Moments send-path
  architecture** (the "Architecture TBD"). These remain tracked as deferred —
  removed from the *pivot* framing, not dropped.
- **senderID = the existing Supabase `users` table `id`** (the UserProfile
  account UUID). It is the immutable routing key. **No new field is added.**
- **Deferred deep linking is OUT for Phase 2.** No third-party SDK
  (Branch / Adjust), no clipboard fingerprinting. The no-app path **always**
  lands on short-code entry. Full deferred deep linking is a **Phase 3**
  candidate.
- **Short-code entry recovers the most-recent UNOPENED message** for that
  senderID — a single Supabase query. The contact is created **and** the
  original thought is recovered, so the first experience is never "contact
  created, thought lost."

### Core Model
- Sender sends → Supabase stores message → generates shareable link
- Link format: pointward.app/m/[messageID]?from=[senderID]&name=[displayName]
- Sender shares via iOS native share sheet (Messages, Mail, etc — user chooses)
- Recipient taps link:
  - Has app → opens directly → animation plays → sender auto-created as contact
  - No app → App Store → installs → opens to **short-code entry** (Phase 2: no
    deferred deep linking — see *Scope & Decisions* above): enter the short code
    (last 6 of senderID) → contact created **and** the original unopened thought
    recovered → animation plays
  - *(Phase 3 candidate: deferred deep linking so the no-app path auto-opens the
    thought without a code.)*

### What Travels In The Link
- Message content + emoji + instrument
- SenderID (immutable key, never changes)
- Sender display name (how they want to be known)
- Location does NOT travel in link — shared separately, optionally

### Contact Model
- Every send auto-creates or updates a contact record silently
- SenderID = immutable key for deduplication and routing
- Name = sender's display name, recipient can edit locally
- Location = empty until recipient adds manually
- Sorted by most recent send in People tab
- Recipient owns their local copy — no auto-sync after initial creation
- Delete contact = effectively blocks further appearances

### People Tab
- Auto-created on every send (silent, no prompt)
- Shows: name · last sent timestamp
- Sorted by most recent
- Tap person → straight to send flow
- Edit contact: name (local only, shows warning) · location (local only)
- Gentle hint when no address: "add location for accurate compass · add now ✦"
- Hint shown ONLY on contact card, NEVER in send flow

### Compass Without Location
- No address → seeded random bearing (seeded to senderID — same person 
  always appears from same direction, feels intentional not broken)
- Mutual pointing requires real location on both sides — only feature 
  that genuinely requires it
- Everything else degrades gracefully with seeded fake

### Location Policy Standard
Every component touching location must document:
// LOCATION POLICY:
// REQUIRES_REAL: true/false
// FAKE_STRATEGY: seeded random from senderID / center default / not applicable
// DEGRADES_TO: description of degraded experience
// MUTUAL_ONLY: true/false

### Location Requirement Matrix
- Compass pointing: REQUIRES_REAL=false, FAKE=seeded random
- Send animation direction: REQUIRES_REAL=false, FAKE=seeded random
- Receipt animation direction: REQUIRES_REAL=false, FAKE=seeded random
- Bow/Rocket aim: REQUIRES_REAL=false, FAKE=center default
- Funny distance display: REQUIRES_REAL=false, FAKE=funny distance mode
- Mutual pointing moment: REQUIRES_REAL=true, FAKE=skip feature entirely
- People tab contact card: REQUIRES_REAL=false, FAKE=no map shown

### Notifications — Phase 2
- Push notifications removed from send flow entirely
- The iOS share sheet message IS the notification
- No redundant double-notification
- Phase 3: consider "your message was opened ✦" sender notification

### Sender Display Name
- Set in onboarding — how everyone sees you
- Warning shown when set: "this is how everyone who receives your 
  messages will see you ✦"
- Recipient can edit locally — their copy only
- Warning shown when editing: "editing your local view only ✦"

### The Send Flow Is Sacred
- Nothing interrupts a send. Ever.
- Hints and prompts live on contact cards and settings only
- Missing information never blocks sending
- Graceful degradation: app works at every step without complete information

### Phase 2 Test Scenarios

AUTOMATED (Claude writes):
- Send to existing contact → no duplicate created
- Multiple sends same contact → timestamp updates, no duplicate
- Recipient has app, sender is contact → direct open, no setup
- Recipient has app, sender not contact → auto-create contact
- Recipient sends back → two-way connection established
- Local name edit → sender display unchanged for others
- Delete contact → no further appearances
- Message in history if unopened

LIVE DEVICE (Joshua tests):
- No app → App Store → install → opens to short-code entry (Phase 2: no deferred deep link)
- Short-code entry recovers the most-recent UNOPENED message for that senderID
- Recipient already has app → link opens directly, no App Store
- Sender void feeling → acceptable for Phase 2
- Stale location after move → manual fix acceptable

### Pairing — Removed in Phase 2
- No manual pairing ID entry ever
- No pairing codes
- No wrong-person bugs (ID travels in link, not typed manually)
- PairAcceptView → removed
- connections table → retired
- Every connection starts with a real sent message

### Product Principles (established this session)
1. The send flow is sacred — nothing interrupts it
2. Graceful degradation — app works without complete information
3. More information = better experience, never required
4. Hints live on contact cards, never in send flow
5. SenderID is the immutable key — name and location are editable metadata
6. Auto-create contacts silently — deletion is the exception, keeping is default

### Future — Interactive Animations (logged, not scheduled)
Ball throw / glove catch:
- Sender throws ball (instrument mechanic)
- Ball travels to recipient
- Recipient moves glove to catch spinning ball (interactive receipt)
- Catch = reveal
- First truly interactive receipt mechanic
- Only works for users with app installed (not passive link view)
- Ball landing position seeded to sender bearing if available, random if not
- Fits Expresser archetype perfectly

### Special Moments — Architecture TBD
- Does Special Moment send need emoji attached or standalone?
- Decide before building next Special Moment
- Link delivery makes Special Moments ideal for viral sharing
- Beautiful web preview opportunity (Phase 3)
- Graduation → Special Moment, emoji = cap thrown in air

## STRUCTURAL CLEANUP MAP (post-TestFlight — see reports/structural_map.md)

**GOAL:** better CONTAINMENT → cleaner Claude Code reasoning + safe PARALLEL work. Today the big
shared files force one-writer-at-a-time (a single backend or compass task locks the whole file).
**Timing:** the actual cleanup is **POST-TESTFLIGHT** — cleaning load-bearing files right before
submission is the risky timing we deliberately avoid. This is the **ranked spec**, not a to-do-now.
Full detail + line counts: **`reports/structural_map.md`**.

**RECOMMENDED ORDER** (effort · risk · what it unlocks):

1. **DEAD-CODE DELETE** — zero risk, do FIRST. **✅ DONE** (commits `2899565` + `5429413`). 4 whole-file
   orphans deleted: **ArrivalPreviewView** (79) · **MutualMomentView** (72) · **FireflyInstrumentView** (149)
   · **DirectionResolver** (93). PLUS — **CORRECTION to the original map:** there were **FOUR** dead arrival
   structs inside CompassView, not 2 — `DirectionalArrivalView`, `RevealArrivalView`, `CoreArrivalView`,
   `ThoughtArrivalView` (the map wrongly called `DirectionalArrivalView` "live"). **ALL FOUR were DEAD**
   (zero callers — *"previous arrival flows retired"*); **the LIVE arrival is `ReceiptView`** (an excluded
   animation file, untouched). All 4 were **deleted** (−483 lines, `5429413`); **no `CompassArrivalViews.swift`
   was created** (there's no live arrival view to contain). _Unlocks:_ "Claude sees only live code".

2. **SUPABASESERVICE EXTENSION-SPLIT** — the **#1 parallelism unlock**. 1017 lines, **touched by 25 files**
   = the worst chokepoint (every backend task edits it). Split into `extension SupabaseService` files
   (**+Auth, +Pings, +Realtime, +Messages, +Profile, +Maintenance**) — SAME type, **ZERO API change**,
   callers untouched. ⚠️ the **Pings + Realtime** extensions are PATH-1 → **device-verify**. _Unlocks:_
   backend tasks (auth / messages / profile / maintenance) running **in parallel**.

3. **DUPLICATION CONSOLIDATION** — small, low-risk. (a) **Apple Sign-In handler** (`handleAppleResult` /
   `randomNonce` / `sha256`) triplicated across **OnboardingView / SettingsView / ComposeBackView** → one
   helper. (b) **address-autocomplete cluster** (`addressAutocompleteField` + `geocodeTypedAddress` /
   `selectSuggestion` / `handleAddressInput`) triplicated across **AddPersonView / EditPersonView /
   OnboardingView** → a shared `AddressAutocompleteField` + helpers. _Unlocks:_ removes "synchronized
   multi-file edit" collisions + shrinks 5 views.

4. **COMPASSVIEW SUBVIEW EXTRACTION** — UI parallelism. **✅ PARTLY DONE** (`5429413`): **SkinQuickPicker /
   PersonSwitcherSheet / ShareCardView** extracted to their own files (LOW risk, zero caller change) +
   the 4 dead arrival structs deleted → CompassView **3109 → 2382**. **DEFER** the send-trigger
   (`CompassView+Send`, ⚠️ **PATH-1**) to a careful device-verified pass. _(No "arrival views" remain to
   extract — they were all dead and deleted; the live arrival is `ReceiptView`.)_ _Unlocks:_ compass /
   share / people-switch tasks **in parallel**.

5. **`pairedUserID` → `senderID` MIGRATION** — LAST, careful. `pairedUserID` is a **pure mirror of
   senderID** (no extra info) but still read by ~4 live sites incl ⚠️ **PingManager:264 (PATH-1 delivery
   key)**, RootView:310 (`syncMissedThoughts`), PersonDetailView:40, PeopleListView:158. Read `senderID`
   directly + drop the field. PATH-1-adjacent → deliberate **two-phone-verified** pass. _Unlocks:_ removes
   the last pairing-era field + the "senderID vs pairedUserID?" reasoning ambiguity.

**PARALLELISM NOTES:** **#2 (backend) + #4 (UI)** are the big parallel-work unlocks; **#3** removes the
synchronized-multi-file-edit class of collisions; **#1** makes all subsequent reasoning cleaner; once #2
lands, the cleanup itself can partly parallelize. The **widget target (PointwardWidgets)** is a separate
bounded corner (its iOS-17 WidgetKit use — `containerBackground` / `#Preview` — blocked a 16.0 floor;
that's why the floor is 17.0).

**CARRY-FORWARD (brief):**
- **`placemark` deprecation** (`AddressAutocompleteService:77`) is **LEFT intentionally** — its
  non-deprecated replacement (`MKMapItem.address`) is **iOS-26-only** and would re-raise the deployment
  floor. Revisit only if the floor ever rises.
- **9 Xcode warnings** — **none block submission.** 3 Supabase-SDK deprecations (`postgresChange` ×2,
  `subscribe`) worth a careful **backbone-adjacent** touch when convenient; 5 Swift-6 concurrency (incl the
  **PingPayload PATH-1 pair**) deferred to a deliberate **Swift-6 pass** — **staying Swift 5 through launch.**

---

## Phase 2 — Animation Track (canonical commit ledger)

The pre-launch animation cleanup, in order. One line each; deeper detail lives in the
named `reports/`. (Restore ladder, recent tail: … `c38ca9d` → (birthday-interim `9ab3f6e`) →
`624b044` → `bd285d8` → `380d374` → `68de96d` → `e6e0608` → `5cf1d47` → `e3438a5` →
`684eabc`* → `277b457` → `7ac50bc`* (HEAD). *`684eabc`/`7ac50bc` = Phase-2/pairing track,
interleaved — not animation-track work, listed for ladder accuracy.)

- **`09ba2f5`** — bottom-band redesign: 4-box picker row `[Animation][Emoji][Message][To]`,
  default-emoji framework (send no longer gated on a feeling), helper lines + preview line,
  **no send button**; old `bottomZone`/`sendControl` retired (commented). _(reports/bottom_band_redesign.md)_
- **`b9e2a30`** — R1: plane aim-hint fixed to **compass-only** (`alignsByPhoneRotation`),
  retired the stage-completion dots, moved the mechanism recipe up under the instrument,
  per-session **custom-text lock** (`messageEdited`).
- **`be59c38`** — R2: suppressed the **duplicate sender-side reveal** (arrivalPreview) —
  the emoji/message reveal now happens once, on the receiver (`ReceiptView .received`).
- **`d403584`** — Batch 1: **default emoji reaches all 7 face gates** (faces take the
  defaulted `effectiveToken`; **wind/wand start their sensor on appear** for the non-nil
  value); per-animation defaults in `AnimationManifest`; **compass explicit send**
  (point → hold → lock → tap, no auto-fire); flick/rocket copy. _(reports/batch1_part1_stop.md)_
- **`8fbd7d8`** — wind self-fire + loop fix: exhale-**shape** gate (rejects steady ambient)
  + per-send **single-shot** + thresholds restored (`requiredSeconds` 0.8→1.3, floor lifted).
  _(Item C in reports/review_batch_audit.md)_
- **`e0d7576`** — ROOT-2: **plane + flick promoted to live V2 dispatch** (receipts + flick
  send); **wand deferred** (its receipt is a stub). _(reports/special_moments_selector_build.md)_
- **`7128da7`** — fix: `cancelInstrument` clears the compass **awaiting-tap latch**
  (`compassAwaitingTap = false`). _(reports/cancel_semantics_audit.md)_
- **`c38ca9d`** — **Special Moments Stages 1+2**: Birthday + Firework become first-class
  peer `Instrument`+`SenderStyle` cases, **selectable cards**, sender-side dispatch keys on
  **style/selection** (emoji-keyed branches kept as a transition fallback). Recipient =
  Stage 3. _(reports/special_moments_stage12_build.md, special_moments_peer_architecture_plan.md)_
- **`9ab3f6e`** — interim: Birthday `defaultEmoji` 🎁 → **🎂** so the unchanged emoji-keyed
  recipient routes it correctly. (Flipped back to 🎁 at Stage 3.) _(reports/birthday_default_interim.md)_
- **`624b044`** — **Special Moments Stage 3**: recipient `ReceiptView` re-keyed to dispatch
  on `style == .birthday/.firework` (emoji fallback kept, commented for Stage 4); Birthday
  default flipped back 🎂 → **🎁**. **Peer architecture COMPLETE end-to-end (Stages 1+2+3).**
  _(reports/special_moments_stage3_build.md)_

— _Pre-release fixes batch (this session):_ —
- **`380d374`** — pre-release fixes (3-in-1): (1) **firework + birthday FREEZE fix**
  (approach B) — `finishSend` bumps `instrumentResetID` for `.firework`/`.birthday` after
  the flight, recreating the face fresh (restores the reset the old emoji path gave; no
  animation-face edit); (2) rocket receipt descent smoothing (first pass); (3) **removed the
  dead "show arrival preview" setting** (R2 had suppressed it; all readers were commented).
  _(reports/prerelease_fixes_build.md)_
- **`68de96d`** — rocket receipt **FIRST-DROP fix**: the too-fast top-of-screen drop was the
  fast middle of one `easeInOut(4.0)` curve → split into a slow `easeIn` ENTRY (descend 0→0.5,
  tunable `entryDropDuration` default 5.0s) + the kept `easeOut` SETTLE (0.5→1.0),
  velocity-continuous; post-descent beats re-anchored off `land`, feel unchanged. **Accepted
  "good enough"; one knob if revisited.** _(reports/rocket_firstdrop_fix.md)_
- **`e6e0608`** — **removed the dead/mislabeled "thoughts" notification toggle**: it gated
  the RETIRED `notify_pointing` pref (no pointing pushes exist) and did NOT control the live
  thought-arrival push; section removed cleanly (its only content). `setNotifyPointing` +
  `users.notify_pointing` now unreferenced client-side (harmless dead code; optional future
  server cleanup). ⚠️ App now has **zero user-facing notification controls** (thought-arrival
  pushes always-on, governed by the iOS system permission only). Post-launch option:
  relabel/repoint a toggle to gate the live thought push (cross-track — PATH-1 + deploy).
  _(reports/remove_thoughts_toggle_build.md)_
- **`5cf1d47`** — bucket per-item **DELETE**: `PingManager.removeFromHistory(id:)` (keyed on
  `remoteID ?? id`; ⭐ reusable Phase-3 backbone) + a "🗑 delete" button on the replay overlay
  (`ReplaySwipeContainer`) that deletes the currently-shown thought then dismisses. Additive
  (replay/swipe/dismiss untouched). **Delete-only — NO save/preserve** (Phase-3 retention).
  _(reports/bucket_delete_build.md)_ [UX superseded by `e3438a5`.]
- **`e3438a5`** — **replay overlay UX rework**: replaced auto-advance + swipe with an explicit
  **PREV · NEXT · CLOSE · DELETE** button row (larger/legible). Prev disabled on first, Next on
  last (both on a single item); DELETE removes the current thought then advances to the next
  (closes if last); **no auto-exit**; the reveal is keyed on `cur.id` (not `idx`) so a
  delete-advance re-fires the animation. Non-bucket replays (PersonDetail's separate inline
  cover) unaffected; DELETE hidden when no `historyID`. **Known cosmetic:** EmojiRevealView's
  internal faint "tap anywhere to keep ✦" hint still renders but is now INERT (no-op dismiss) —
  left untouched (fenced shared reveal); flagged for a later in-reveal cleanup.
  _(reports/replay_buttons_build.md)_
- **`277b457`** — **per-instrument default message** (first step toward compose uniformity):
  added `defaultMessage: String?` + `defaultTagline: String?` to `AnimationDefinition`
  (alongside `defaultEmoji`); `CompassView.seedMessage` now PREFERS the selected instrument's
  `defaultMessage` and FALLS BACK to the per-emoji `CuratedEmoji.defaultMessage` (then the
  instrument hint) — exactly today's chain when unset. Set **ONLY Birthday → "Happy Birthday"**;
  every other instrument left nil → no regression. Seed stays user-editable (the `!messageEdited`
  lock is untouched). `defaultTagline` field added but **UNWIRED** (tagline rides from the
  selected person, an entangled path — deferred). **Receipt UNCHANGED** (routes by `style ==
  .birthday`, not the message). _(reports/birthday_default_message_build.md)_
  > **Interleaved (Phase-2 / pairing track — NOT this animation track, ladder-acknowledged
  > only):** `684eabc` "prelaunch fix batch" (demo local-only preview + Demo Dan rename +
  > share-sheet-on-animation-complete + inline add-person) and `7ac50bc` (keep Demo Dan
  > permanently + sole-contact switcher tap fix) — **`7ac50bc` is current HEAD.** Detailed in
  > their own track; listed here so the ladder is accurate.
  > **Device-test status:** firework/birthday re-arm CONFIRMED on device · arrival-preview
  > removal CONFIRMED · rocket descent accepted "good enough" · thoughts-toggle removal +
  > bucket-delete + replay button rework (`e3438a5`) + Birthday default message (`277b457`)
  > shipped, device-test PENDING.

---

## PHASE 3 — DEFERRED WORK

Headlines only — the durable detail (scope, decisions, reasoning, file:line) lives in
**`reports/phase3_handoff.md`**. Ground any build on that doc + a fresh `git status`.

- **History tab** — full feature project, not just a view. Net-new data layer: **sent
  history isn't stored**, no preserve/pin concept, a unified `HistoryItem` store +
  retention engine (50 total, evict unpreserved-first). Tab insert is trivial (additive
  `.tag(3)`). ⭐ **Per-item delete backbone now EXISTS** —
  `PingManager.removeFromHistory(id:)` (`5cf1d47`, used by the bucket's "🗑 delete"); the
  History-tab swipe-delete reuses it. **Save/preserve still deferred** to Phase-3
  retention (delete-only today). _(reports/history_tab_audit.md, bucket_delete_build.md)_
- **Special Moments — Stages 1+2+3 COMPLETE** (`624b044`): the recipient `ReceiptView`
  re-key shipped (dispatch on `style == .birthday/.firework`, emoji fallback kept),
  closing the birthday-as-bucket gap; Birthday default is back to 🎁. Gates were cleared
  (`sender_style`/`messages.instrument` free text; Edge Function forwards style untouched).
  **Only Stage 4 remains** — retire the emoji-keyed fallback branches once the fleet has
  updated (pure cleanup). _(reports/special_moments_stage3_build.md)_
- **Future Special Moments roster** — Valentine's / For Mum / July 4th / Graduation; each
  = Instrument+SenderStyle case + manifest row + InstrumentOption + its animation views.
  Manifest-driven dispatch registry parked for if the roster grows.
- **Wand receipt** — build a real receipt (current `WandReceiptAnimation` is a stub) +
  wire `.wand` into `ReceiptView`. Cosmetic, low priority.
- **Known gaps / device-test debt** — mic-denied wind path, X-button visibility,
  recipient-side arrival correctness (esp. new flick/plane V2), send-sound distortion
  (DEBUG-only?), and a large untested surface (plane/flick V2, Batch 1, wind fix, Stages 1+2).
- **Compass directional strings** — small: reword or leave the "X is to your NE" guidance.
- **Cross-track (Phase-2 backbone — coordinate, don't build alone):** the History
  send-recording is near PATH-1; Stage 3's Edge-Function check may need a Joshua deploy.


---

## ARCHIVE — historical detail (superseded/completed, kept for record)

_Relocated from the live flow in canon reduction pass 1 (additive-move, nothing deleted). The full
unmodified original is `POINTWARD_TRUTH_ARCHIVE_2026-06-23.md`._


_(archived 2026-06-23 from "⭐ WEB PAGE (Build 12) — BUILT · DEPLOYED · LIVE-TESTED ")_
### ⭐ WEB PAGE (Build 12) — BUILT · DEPLOYED · LIVE-TESTED ✅
**STATUS:** the show-the-message page is **DONE and deployed** to the separate
**pointward-website** repo (commit `2d319d4`, "add show-the-message page (404.html,
path-style /m/<id>)"), live on **GitHub Pages at pointward.app**. **Live-tested
working:** a real `/m/<id>` renders the real message; a bad id shows the empty state.
**First production proof** that a static page fetches Pointward messages anonymously.
- **SERVING:** **`404.html` at the repo root.** GitHub Pages has no SPA / path-wildcard,
  so path-style `/m/<id>` links resolve via the 404.html fallback (reads the id from the
  path, renders). **No app-side link-format change** (chosen over a `?id=` query form,
  which would've forced an app change).
- **DATA:** the anon **`get_message` RPC** (`POST …/rest/v1/rpc/get_message`, body
  `{"p_id":"<uuid>"}`, array-wrapped → `rows[0]`; fields `emoji` / `content` /
  `sender_display_name`; `[]` for unknown / expired). CORS verified from the page
  origin. The anon key is public / shippable.
- **BRAND: DARK PURPLE** (matches the live `index.html`: bg `#0d0d14`, text `#e8e0f0`,
  accents `#3a2e50` / `#7c6b8e` / `#c4a8d4`). **SUPERSEDES the earlier "warm cream
  palette" note** (placeholder, written before the real palette was known). Shimmer /
  glow look better on dark.
- **COPY (as shipped):** kicker *"[sender] sent you a thought ✦ it moves when it
  arrives"*; glowing / floating emoji; serif message; *"from [sender]"*; **HERO** *"see
  the full animation — the way [sender] intended ✦"*; **bonuses** *send one back · send
  custom animations to others · save it · and more*; **button "Open Pointward"**;
  **trust-line** *"free · no ads · for real"* (truthful — **v1 ships 100% FREE, no
  paywall**; keep that promise);
  instrument hints.
- **DOES NOT `mark_opened`:** the web page **displays but does NOT flip opened** —
  preserving the locked definition (*read = opened IN FULL IN-APP, the way the sender
  intended*; a web glance is not a read). **The audit's "optional `mark_opened`" was
  deliberately DECLINED.**
- **✅ INSTALL BUTTON — LIVE (2026-06-22).** Both "Open / get Pointward" buttons now point at
  the real public TestFlight link **`https://testflight.apple.com/join/rjAS4cnk`** (the
  `TESTFLIGHT_LINK_PLACEHOLDER`/`XXXXXXXX` were replaced in `404.html` + `index.html`, committed
  to pointward-website). **Web funnel verified END TO END on device:** web page → "get Pointward"
  → TestFlight → install. **Routing (locked):** straight-to-install (no landing-page hop). _(was:
  placeholder pending external review — now resolved; see the 2026-06-22 session block.)_
- **TWO INVITE SURFACES (locked):** (1) the **share-sheet message text** in the
  recipient's Messages thread (*"[sender] sent you a custom animated message ✦ tap to
  preview"*) + the **iOS auto-preview card** (shapeable via the page's `og:` meta tags —
  already added); (2) **this web page.** Surface 1 entices the tap; surface 2 catches
  the no-app tap.
- **Wiring is DONE** (the real, do-once work): message id from URL → anon
  `getMessage(id)` → render. Look / copy is **cheap to change anytime** now that it's
  wired.
- **THREE-TIER ANIMATION LADDER:**
  - **T1 (now):** static + cheap CSS shimmer + simple peripheral hints.
  - **T2 (between Phase 2/3, END of the list):** recreate **simplified
    onboarding-grade** instrument animations in CSS/SVG — **POC ONE instrument first**
    (possibly as an onboarding-screen trial) to gauge easy-vs-painful before committing
    to all.
  - **T3 (Phase 3):** the full in-app animation rebuilt in the browser.
  - ⚠️ The onboarding minis are **100% native SwiftUI — NOT web-portable.** Recreation,
    not reuse; use them as **visual reference** only.


_(archived 2026-06-23 from "Re-sequenced Build Order (back half) — replaces the pri")_
### Re-sequenced Build Order (back half) — replaces the prior 9→10→11
Builds 5–9-safe-half are ✅ DONE (see ledger). The remaining order was re-sequenced
this session — **the safe-half mechanical chunk was front-loaded; what's left is the
decision-heavy, fresh-mind work.**

- **5** ✅ DONE — contact auto-create on receive `[3cd8328]`
- **6** ✅ DONE — People tab rework `[bde566e]`
- **7** ✅ DONE — compass seeded-bearing degradation `[5595104]`
- **8** ✅ DONE — strip pairing UI `[26c59ff]`
- **9 (safe half)** ✅ DONE — unified bucket + pure-pairing retirement + Sarah
  repoint `[2919f1f]`
- **11b — IMPLEMENT THE TWO-PATH SEND** (per the locked SEND MODEL + connection-signal
  spec above) — **THE PIVOT CUTOVER.** Now **STAGED A→B→C** (the design-audit is DONE —
  `reports/connection_signal_build_spec.md`):
  - **A** (no schema, ships): un-gate the link + remove the unconditional legacy send +
    add (S1) `SentLink`. = PATH-2 "a link for everyone."
  - **B**: the `link_connections` migration + receiver write/sweep (S2) + sender stamp.
  - **C**: two-path `if/else` (connected → DIRECT re-keyed; else LINK) + poll receipts.
  - **⚠️ Family-test gate is AFTER C** (link-every-time feels clunky to close contacts).
  - **🐞 FOLDED BUGS (finish the send model's experience):** #1 PATH-1 push not firing
    app-closed [HIGH — keystone] · #2 share/invitation text "Someone" → "[John]" [HIGH] ·
    #3 name on the envelope [MED] · #15 display-polish batch clean device verify [owed].
    (See *CLEAN TWO-PHONE TEST → NEXT-SESSION PRIORITIES*.)
- **9b — retire genuinely-DEAD pairing plumbing ONLY** (NOT the direct-delivery
  channel — that survives as PATH 1, re-keyed to `senderID`). The earlier "retire the
  delivery backbone" wording is **SUPERSEDED** by the locked SEND MODEL. Only the dead
  pairing bits (`connections` remnants, etc.) retire; the pings direct channel +
  realtime receive STAY (re-keyed).
  - **🐞 FOLDED BUGS:** #5 legacy "connect with [name]" screen (bypassable; retire →
    tap-to-compose) · #4 forced-send-on-contact-add + remove the cold "[John] added you"
    notification.
- **10 — onboarding rewrite** — see **ONBOARDING / ARRIVAL NORTH-STAR** below (the
  earlier "subtractive cut" of the dead connection-code screen is **ABSORBED** into
  this redesign, not a separate build). Also touches `redeem`/`createInvite` (B1) and
  `myPairingCode` (B5).
  - **🐞 FOLDED BUGS:** #6 onboarding name-not-persisting + skip lingering-screen
    (re-index artifact; **ROOT of the wife's NULL display_name → "Someone" arrivals**) ·
    #7 Settings profile section (self name/address; Settings-review project) · #9 "someone
    who loves you" caption + bucket-catch old-phase copy cleanup.
- **11 — Phase 2 test suite** (automated scenarios).
- **12 — SHOW-THE-MESSAGE web page** ✅ **BUILT · DEPLOYED · LIVE-TESTED**
  (`pointward.app/m/[id]`, in the separate **pointward-website** repo — commit
  `2d319d4` — live on GitHub Pages). Renders a real `/m/<id>` via anon `getMessage`;
  empty state for a bad id. **One open dependency:** the install button uses a
  TestFlight-link placeholder (no public link until external review / App Store). Full
  status + shipped design/copy in **WEB PAGE (Build 12)** below.
- **cleanup pass** — tighten/consolidate transitional logic (the mirror-write
  bridge etc.), **hard-delete** the commented code, test audit, final TRUTH cleanup.

> b10 / 11b are the **decision-heavy / fresh-mind** builds; b9 safe-half was the
> last mechanical chunk (front-loaded deliberately).


_(archived 2026-06-23 from "⭐ SESSION CONTINUED — contact/unread fixes + 9b AUDIT D")_
### ⭐ SESSION CONTINUED — contact/unread fixes + 9b AUDIT DONE + open threads

**COMMITTED THIS SESSION (beyond the batch + push):**
- **PersonDetailView reconcile (`73cceaa`)** — `isConnected` now **senderID-primary**, compose
  row **ungated**. **Device-verified:** a connected contact shows **"Connected ✓"** + message
  history + reachable compose (was wrongly "not yet linked"). Closes finding #1.
- **Unread-badge fix Option A (`7c0f956`)** — `SupabaseService.markAllMyPingsOpened()` on
  foreground + the kept `setBadgeCount(0)`. **On-device log "marked all opened ✓"** (no RLS
  block; `pings` has no RLS → inherits `markPingOpened`'s permission). **Badge = "unseen since
  open"**; `opened_at` now means **seen/acknowledged** (so the sender's "opened ✦" receipt
  fires on app-open — accepted trade-off). Closes finding #2. _(Both verified committed —
  HEAD `7c0f956`; tree clean.)_

**⭐ 9b CLEANUP AUDIT — DONE** (`reports/ninebee_cleanup_audit.md`) — removal plan ready.
PRESERVE-LIST confirmed (PATH-1 survives, re-keyed to senderID): `pings` / `sendRemote` /
`sendPing` / realtime+felt / `syncMissedThoughts` / `Person.senderID` / push chain /
`markPingOpened` / `markAllMyPingsOpened` / `stampConnections` / `link_connections` / the
connection signal.
- **⚠️ CATCH 1 — `connectedFriendID` is LOAD-BEARING** (read LIVE by `PingView` send-timing,
  `:1094/1171/1195`) → **do NOT remove**; only drop the PersonDetailView *clause* referencing
  it (B5).
- **⚠️ CATCH 2 — `claimOutcome` + its tests are now APP-ORPHANED** (`redeem`'s callers are all
  `#if false`) → TRUTH's earlier "redeem/claimOutcome tests STAY" is **SUPERSEDED.** **DECISION
  for Joshua next session:** retire `redeem`+`claimOutcome`+tests together, **OR** keep
  `claimOutcome` as a tested pure-function island. _(Recommend retire-together.)_
- **RECOMMENDED REMOVAL ORDER (5 batches; won't tangle; each builds + tests green):**
  - **B1 — dead VIEWS hard-delete:** `ConnectView.swift` (incl. the now-orphaned
    `MessageComposerView`), `PairAcceptView.swift`, RootView `#if false 518-679`, AccountView
    `#if false` blocks, PersonDetailView's `#if false` invite code. _(Confirm AccountView's
    Settings presenter is gone first.)_ Zero behavior change (all already `#if false`).
  - **B2 — SupabaseService pairing API + DI:** `redeemCode` / `createProfileInvite` /
    `lookupInvite` / `insertFromInvite` / `redeem`(+`claimOutcome` per decision);
    `PairingServiceProtocol` / `MockPairingService` + the ServiceContainer field (declared +
    assigned but **never read**).
  - **B3 — PeopleManager funcs + TEST migration:** migrate **`SkipOnboardingTests:51` →
    `person(forSenderID:)`** (1 line; Sarah's mirror keeps them equal); retire/split
    `PairingScenarioTests` (18 tests); then delete `addFromInvite` / `bindConnection` /
    `insertFromInvite` / `person(forPairedUserID:)`. **Test count will change.**
  - **B4 — mutual-pointing unwire (NEED-CARE, own batch):** the cluster is DORMANT-WIRED (live
    code that never fires because `reportPointing` is a no-op). PingManager state +
    `presenceFelt` + `checkMutualPointing` → NotificationHandler **"pointing" branch (⚠️ KEEP
    the live thought/PATH-1 `else` branch)** → CompassManager `reportPointingIfNeeded` / timer
    → CompassView **edge-glow (`:897-909`)** → `reportPointing` no-op stub. **Build +
    device-glance** (CompassView touched).
  - **B5 — PersonDetailView `isConnected` simplify:** drop `connectedNow` + the
    `connectedFriendID` clause → collapses to senderID-only.
  - **Server-side (Joshua):** delete the `rapid-action` stray Edge Function; retire the Edge
    Function's `compass_bearings`/"pointing" branch (with B4).

**OPEN THREADS / NOT STARTED:**
- **ANIMATION — queued, NOT started:** a prompt was drafted/sent to a separate animation chat
  but **not worked through** (no audit reviewed, no build — effectively un-started). Items:
  **#12 Plane v1-not-v2 [priority]**, #13 aiming-order, #14 send-sound (**verify in RELEASE
  first**). ⚠️ **Do NOT run an animation BUILD and a 9b BUILD in the repo simultaneously.**
- **NOTES:** **unfeelable-backlog** (missed pings older than the newest aren't replayable —
  future item); `markPingOpened`/`markAllMyPingsOpened` would need a **recipient-UPDATE RLS
  policy IF `pings` RLS is ever enabled** (today it's off).
- **Pending device checks (opportunistic, single-phone/recipient):** the unread visual
  badge-clear (recipient backlog → open → badge clears + stays clear).

**REMAINING WORK:** the **9b removals (B1–B5, plan above — START next session)**, **Build 10**
onboarding + **#6** name-persist, **Settings-tab review**, **Phase-2 test suite (#11)**, final
cleanup (hard-delete remaining commented code, gitignore `reports/`).


_(archived 2026-06-23 from "⭐ DISPLAY-POLISH BATCH — ✅ BUILT + COMMITTED (`90422fd`")_
### ⭐ DISPLAY-POLISH BATCH — ✅ BUILT + COMMITTED (`90422fd`) — needs clean device verify
Three display-only improvements — **built, Release-compiles, 248 tests green, committed**
(`reports/display_polish_build.md`). Identity is stable, hardening deferred. **Still needs
a CLEAN device check** (the churn blocked it — see NEXT SESSION below):
1. **ARRIVAL NAME** (`reports/arrival_name_audit.md`): `IncomingMessageView` —
   `receivedPing` (208–211) + `historyPing` (228–231). Add a **name-precedence** helper:
   (1) recipient's **LOCAL contact name** via `people.person(forSenderID:)` [the "Husband"
   enhancement], (2) `m.senderDisplayName` [baseline], (3) `"someone"` [last resort]. ONE
   shared helper; updates **ALL** receipt captions (they read `ping.fromName`). **Fixes the
   "Someone" arrivals** (root cause = wife's null `display_name`; see Identity gotcha).
2. **CONNECTION INDICATOR** (`reports/connection_indicator_audit.md`): `PeopleListView`
   ONLY. The green "connected" indicator **already EXISTS** but is hidden for link
   contacts — **re-surface it driven by `senderID`** (`isLinkContact = senderID set`) as
   **"connected ✦"** (green **#5dcaa5**); render **nothing for nil** (no false "not yet
   linked"). Display-only. (This IS finding #3 above — the connection-status indicator.)
3. **CONTACT ICON → INITIAL:** standardize the avatar on the INITIAL, stop displaying the
   per-person emoji. ⚠️ The cited `PersonDetailView:338` was the **WRONG target** — that
   line is `prepareInvite()`'s `ownerEmoji` (the **invite payload**, pairing-era), NOT the
   displayed icon — **left intact.** The real avatars were fixed: **`PersonDetailView:56`**
   (header; had NO monogram fallback → emoji-less contacts showed BLANK — now the initial,
   also fixes that gap) + **`PeopleListView.PersonCard`** (list avatar → initial-only;
   emoji branch commented). `UserProfile.emoji` / `Person.emoji` **FIELDS KEPT** (only
   their use as the icon removed; `UserProfile.emoji` still feeds the invite at `:338`, so
   removal is not clean). Ties to the banked "[build 8/10] onboarding-emoji" field audit.


_(archived 2026-06-23 from "Pivot Session (next major)")_
## Pivot Session (next major)

The next major effort is the **Phase 2 — Link Delivery Model** (see that section
below). The pivot is **link-BASED** (`pointward.app/m/[messageID]`): it does
**not** remove link delivery — link delivery *is* the new model. What it removes
is **pairing** — manual codes, typed IDs, the `connections` table, and
`PairAcceptView` — replacing it with a real sent message that carries the
sender's identity in the link.

> The authoritative removal mechanics — the load-bearing step order and the exact
> seams to cut — live in **PAIRING_AUDIT.md §5** ("Suggested order for the
> pivot"). Defer to that file; the order is intentionally **not** reproduced here,
> to avoid drift.

---


_(archived 2026-06-23 — detail behind: Phase 2 — Link Delivery: COMPLETE (builds 1–9 ship)_
### Phase 2 Progress Ledger (DONE + verified)
Builds 1–9 (safe half) are committed and verified. The link-delivery path exists
end-to-end (send → message → /m/[id] link → open/replay → opened-flip), the People
tab reflects the link model, the compass degrades gracefully without location, the
pairing **UI** is stripped, and the history bucket is now **sender-agnostic**.
Pairing's pure-presence data layer is retired; the **delivery backbone is
deliberately KEPT** (see the critical finding below) until the link send ships to
release.

- **Build 1 — canon reconciliation** (link-based model, scope, senderID,
  deep-link deferred to P3). `[12ae0a0]`
- **Build 2 — short_code + messages table + `Message` model** (+ profile
  short_code decode). Migration **APPLIED** in live Supabase. `[6617882]`
- **Build 3 — link-based send**: insert message → build `/m/[id]` link → iOS
  share sheet. Additive; old path intact; DEBUG-gated. `[b86124d]`
- **Build 4a — open `/m/[id]` links**: route + cold-launch replay, fetch by id,
  incoming envelope beat → receipt, **opened flips on COMPLETION** (not on
  interrupt). VERIFIED on device. `mark_opened` migration **APPLIED**.
  `[c0cc87a, 5f56c72]`
- **Build 4b — short-code fallback**: code entry (People-tab tray button) →
  claim ALL unopened → newest plays via the 4a chain → rest to history store.
  Core VERIFIED (drain works, flips correctly). `[3264953]`
- **Build 5 — contact auto-create ON RECEIVE** (rescoped from "on send": no
  recipient identity exists at send time). senderID-keyed, **silent**, dedup (N
  messages from one sender → ONE contact); **NO contact emoji**; mirror-writes
  `pairedUserID = senderID` as a bucket bridge (build-9 must keep senderID). Wired
  to both receive hooks (link open + short-code claim). Device-verified, 4 tests.
  `[3cd8328]`
- **Display-name / shortCode fix** — send now reads `people.profile?.displayName`
  FIRST (UserDefaults mirror as fallback); `cacheProfile` now writes `shortCode`
  (was blanked every cache). Residual NULL only on never-onboarded/orphan accounts
  (Build-10 identity work). `[40529b5]`
- **Build 6 — People tab rework**: recency sort (`lastReceivedAt` desc, **nils
  last**, createdAt-desc secondary) + most-recent sender as the launch default;
  same-name disambiguator (People-tab only); location hint (also **fixes the
  null-island distance bug**); monogram emoji fallback for emoji-less contacts;
  pairing connection-status row **suppressed for link contacts** (senderID-gated,
  NOT pairedUserID — Build 5 mirror-writes it). Device-verified, 7 tests.
  `[bde566e]`
- **Build 7 — compass seeded-bearing degradation**: no real location → a stable
  per-person bearing (**FNV-1a from senderID**, NOT Swift `hashValue`); distance
  hidden for seeded contacts (kills the null-island number); mutual-pointing
  real-location guard. CompassManager-only seam — **no animation file touched**.
  Device-verified, 7 tests. `[5595104]`
- **Build 8 — strip pairing UI** (comment-out, reversible): `/pair`+`/join`
  deep-link branch, `PairAccept`/`Connect`/`MutualMoment`/`PairRequest` views, the
  post-onboarding connect nudge, the inviter-celebration render. `/m/` route
  untouched. Data layer + PersonDetail connect (B1) + onboarding code screen (B5)
  deferred. `[26c59ff]`
- **Build 9 (SAFE HALF)** `[2919f1f]`: **unified sender-agnostic bucket** — built
  from LOCAL `caughtHistory` (all senders, per-person filter + server `fetchPings`
  dropped); **`/m/` opens now record to history** (they were missing) with
  `remoteID = message.id` dedup; per-item `fromName` on `PingRecord`. **Pure-pairing
  retired**: `compass_bearings`/`reportPointing` (no-op'd) + mutual-pointing source
  + `connections` realtime + discover. **Sarah repointed** to `senderID` (via
  `upsertContact`; mirror-write keeps her `pairedUserID` so tests stay green).
  4 new tests. ⚠️ **DEVICE RE-VERIFY of the sender-agnostic bucket is PENDING** — a
  clean install wiped test history before confirmation, and the first device check
  was muddied by 3 stale same-named "Sarah" contacts (since cleared). Logic verified
  by unit tests; re-verify **opportunistically** when a later build (10 / 11b)
  naturally produces multi-sender history — no special staging needed.


_(archived 2026-06-23 — superseded: link-send #if DEBUG note)_
### ⚠️ CRITICAL — THE LINK SEND IS STILL `#if DEBUG` (the delivery backbone)
In a **RELEASE / TestFlight build the ONLY delivery is the LEGACY path**:
`sendThought` → `pings.sendRemote` → `pings` table, recipient =
`selectedPerson.pairedUserID ?? connectedFriendID` (`CompassView` ~1889 gates
`devCreateAndShareLink` behind `#if DEBUG`, so the `/m/` link send **never runs in
release**). **Therefore these are the LIVE DELIVERY BACKBONE and must NOT be retired
yet:** `connectedFriendID`, `sendRemote`, the **pings** realtime insert/felt streams,
`syncMissedThoughts`, `Person.pairedUserID`'s **send-recipient read**, and the
`upsertContact` **mirror-write** (`pairedUserID = senderID`). Retiring any of these
before the link send is un-gated to release ships **an app that cannot deliver a
message.** Un-gating the link send (build **11b**) is the prerequisite cutover.
> **Refined by the SEND MODEL below:** the direct-delivery channel is NOT retired —
> it SURVIVES (re-keyed `pairedUserID → senderID`) as **PATH 1**. Only genuinely-dead
> pairing plumbing retires. The "retire delivery backbone" wording is superseded.


_(archived 2026-06-23 — detail behind: ⭐ SEND / CONNECTION MODEL — FINAL (link era))_
### ⭐ SEND MODEL — LOCKED (link era) (Joshua, this session)
**Replaces the 11b-audit's incorrect "link-only for all sends."** A send chooses ONE
of TWO paths by the recipient's connection state — **they are ALTERNATIVES, never both
(NO double-send).**

**PATH 1 — CONNECTED contact** (a mutual `senderID` contact: they have the app and
have opened a link from me before, so a contact exists keyed on `senderID`):
- → **DIRECT delivery** — the thought lands in their Pointward + a push ("a thought is
  waiting"). **NO link, NO share sheet.** The clean everyday experience; the compass
  still shows them, directed send preserved.
- → **MECHANISM:** the existing direct channel (legacy `sendRemote`/`pings`)
  **SURVIVES** but is **RE-KEYED `pairedUserID → senderID`** (same migration pattern as
  Sarah + the bucket). **It is NOT retired.**

**PATH 2 — NOT-YET-CONNECTED** (covers BOTH "no app" AND "has app but not connected to
me" — **these two cases COLLAPSE into one path**):
- → send the **LINK** (the `/m/<id>` universal link + share sheet).
- → CTA says **"OPEN IN POINTWARD"** — **never "download."** iOS universal-link routing
  handles it transparently: no app → installs then opens; has app → opens directly.
  Either way the receive flow finds no mapped contact and runs **Build-5
  auto-create/connect**. ("Open" is lower-friction + more honest — they're already
  half-in; "download" discourages.)
- → **CASE-3 SOLVED BY NOT DETECTING:** don't try to detect whether a recipient has the
  app (iOS privacy makes it unreliable) — the universal link + "open in Pointward"
  framing makes detection **unnecessary**. The link is universal for everyone
  not-yet-connected.

**COLD-START** (sender has NO person to send to):
- → a **LIGHT, just-in-time "who's this for?"** fill-in appears **ONLY** when there's
  no person to attach (captures/creates the person as part of that one send — the
  sender-side mirror of Build-5's receiver-side auto-create). Once contacts exist,
  sending stays light (select existing → send); the fill-in does **NOT** appear.
  **Never make it heavy or always-present.**

**Consequences for the build order:** 11b and 9b are reframed against this locked
model (see the build order below + the connection-signal spec).


_(archived 2026-06-23 — from "⭐ CONNECTION SIGNAL + PATH 1 + READ-RECEIPT — BUILD SPEC")_
### ⭐ CONNECTION SIGNAL + PATH 1 + READ-RECEIPT — BUILD SPEC
_Full spec: `reports/connection_signal_build_spec.md` (all 10 cases). Summary:_

**THE GAP:** contact auto-create is **one-directional** — the receiver gets the
sender's id on open; **the sender never learns the receiver connected.** So PATH 1
(direct delivery) is **blocked until a connection signal exists.** `senderID` IS
deliverable (a real `users.id`); the `pairedUserID → senderID` re-key is **near-free**
(Build-5 mirror-write already equalises them).

**TWO NEW LOCAL STORES (the hidden build cost):**
- **(S1) sender `SentLink` (`messageID → local contact`)** — `sendThought` currently
  **discards the message id**; it must be stored so the RIGHT contact gets stamped
  when the receiver's id returns (prevents a duplicate name-only + id-only contact).
- **(S2) receiver pending-connection list (opened-message ids)** — drives the
  **post-sign-in sweep** (the fresh-install open is unauthenticated — see below).

**MIGRATION (the one warranted):** a lean new table — do **NOT** reuse the pairing
`connections` table:
`link_connections(sender_id, connected_user_id, via_message_id, connected_at,
PRIMARY KEY(sender_id, connected_user_id))` + index + RLS (`select using auth.uid() =
sender_id`) + RPC `record_connection(p_message_id)` (**authenticated-only**, SECURITY
DEFINER, forces `connected_user_id = auth.uid()`, reads `sender_id` from the message
row → unforgeable). `mark_opened` stays anon (web views); `record_connection` is
auth-only. Apply needs `supabase login` (Joshua applies, like builds 2 / 4a).

**ALL 10 CASES** are spec'd in the report. In brief: authed-open writes the
connection; **fresh-install unauthed-open → post-sign-in sweep (S2)**; idempotent on
repeat / multi-sender (the PK); the sender stamps the right contact via (S1) +
`via_message_id` (no dup); **read-receipt = POLL `messages.opened`** (messages is not
in realtime — not push); never-opens → clean **PATH-2 fallback**; un-gate + a two-path
`if/else` (no double-send); the cold-start fill-in creates the contact to stamp;
forwarding / self-send / deletion edges handled.

**FOUR RESOLVED DECISIONS (Joshua):**
1. **Link-forwarding → first-opener-wins for v1** (forwarding is the user's action; a
   forward that installs is a *win*; recoverable via rename).
2. **Read-receipts → POLL** ("next time you look" is fine; live push = Phase 3).
3. **STAGING A→B→C** (below).
4. **Sign in with Apple** — the tap+consent is **Apple-mandated** (no bypass), but
   it's near-minimal (one tap + FaceID, no forms) and **JUST-IN-TIME** (asked at "send
   one back," not upfront) — that placement IS the friction win. No alt sign-in methods.

**AUTH-TIMING — CORRECT BY DESIGN, not a gap:** open-but-never-sign-in = no persistent
benefits, and **that's fine** — sign-in IS the opt-in threshold; they opted out; the
thoughts sit in `messages`, claimable later via short-code. The fresh-install `/m/`
open happens **before** sign-in (the cover shows over onboarding), so (S2)'s sweep is
the COMMON path, not an edge.

**STAGING (each stage independently sound; no edges dropped):**
- **STAGE A — no schema, ships now:** un-gate the link send (3 files / 4 sites — see
  `reports/build11b_audit.md`) + **remove the unconditional legacy `sendRemote`** (kills
  double-send) + add (S1) `SentLink` recording. = **PATH-2 "a link for everyone."**
- **STAGE B — the signal — ✅ BUILT + DEVICE-VERIFIED** (committed; two-phone test
  passed — see *STAGE B VERIFIED* below). Three independently-testable steps:
  - **(1) MIGRATION `20260615000000_link_connections.sql`** — ADDITIVE: table
    `link_connections(sender_id, connected_user_id, via_message_id, connected_at;
    PK(sender_id, connected_user_id)` idempotent) + index + RLS (sender reads own) + RPC
    `record_connection(p_message_id)` (authenticated-only, SECURITY DEFINER, forces
    `connected_user_id = auth.uid()`, reads `sender_id` from the message,
    on-conflict-do-nothing). Touches no existing table's data. ⚠️ **JOSHUA APPLIES**
    (`supabase login`; like builds 2/4a) — client code can ship ahead; **signal dormant
    until applied.**
  - **(2) RECEIVER WRITE + SWEEP:** `SupabaseService.recordConnection(messageID)` (mirrors
    `markMessageOpened`); hook at IncomingMessageView open (fire at **fetch/upsertContact**,
    NOT at the opened-flip) + ShortCodeEntryView claim; **(S2) `PendingConnections`**
    UserDefaults `[UUID]` appended on every `/m/` open; `drainPendingConnections()` on
    **sign-in success (primary)** + launch-while-authed (backstop) — covers the
    fresh-install-unauthed-open case.
  - **(3) SENDER READ + STAMP:** `fetchMyConnections()` → `PeopleManager.stampConnections()`
    reads Stage A's **S1 `SentLink`** (`messageID→personID`), stamps `Person.senderID =
    connected_user_id` (+ `pairedUserID` mirror). Idempotent; run at launch / scenePhase
    active. The S1 link guarantees **one contact to stamp** (no duplicate).
  - **EDGES handled:** forwarding (first-opener-wins v1), two-contacts-one-person (rare,
    manual merge), self-send skip, message-deleted (`via` set null → skip stamp), offline
    (retry), receiver-also-sender (independent rows), SentLink-missing (skip+log).
  - **PATH 1 send-decision + read-receipt SURFACING are STAGE C** (Stage B only makes the
    stamping/signal work).
  - **⚠️ LIMITATION (named, not blocking):** `SentLink` + contacts are LOCAL SwiftData
    (no sync) → stamping is **PER-DEVICE**; a 2nd device of the same sender can't stamp
    (the contact stays link-only there). An existing per-device limitation, not new;
    flag for a future sync decision; fine for launch.
- **STAGE C — PATH 1 + receipts:** flip `sendThought` to the two-path decision
  (`senderID` set → PATH 1 direct, re-keyed; else PATH 2 link) + surface poll
  read-receipts.
- **⚠️ FAMILY-TEST GATE = AFTER STAGE C, not A.** Test users are friends/family (no
  patience for sloppy); Stage-A link-every-time (even to your wife) feels clunky for
  close contacts you message often. **Test when it's GOOD** (post-C: direct delivery
  for connected contacts), not at first-shippable.
- **RESIDUAL UNKNOWNS (named, not blockers):** forwarding mis-stamp (accept v1);
  poll-not-push receipts (Phase 3 if live wanted); two-contacts-one-person (rare,
  manual merge); the sweep needs sign-in + relaunch (fine — sign-in is the threshold).

> **This SUPERSEDES the earlier "9b retire delivery backbone" framing:** the direct
> channel **STAYS (re-keyed)** as PATH 1; only genuinely-dead pairing plumbing retires.


_(archived 2026-06-23 — from "⭐ STAGE B VERIFIED + TWO-PHONE TEST FINDINGS (this session)")_
### ⭐ STAGE B VERIFIED + TWO-PHONE TEST FINDINGS (this session)

**STAGE B — VERIFIED END-TO-END ✅.** Two-phone test (Joshua + wife, **2 real Apple
IDs**, Xcode-installed both phones): A sends a thought to a real contact → B opens the
`/m/` link (signed in as **her own** Apple ID) → a **`link_connections` row
(sender = A, connected_user = B, via_message = X) FORMED.** The bilateral connection
signal works end-to-end on real devices. **The hardest, most-uncertain piece of the
pivot — the back-channel telling the SENDER the recipient connected — is proven.**
Stage A + B both committed (`d49f503`, `3e02eba`) and now device-verified.

**BUGS SURFACED (pre-existing — the test revealed them; separate from Stage B):**
1. **Arrival shows "Someone sent you a thought" instead of the sender's name.** The
   message carries `sender_display_name` ("John") but the arrival shows generic
   **"Someone"** — the name is IN the data, not displayed. **BUG:** arrival must show
   `sender_display_name`. **ROOT CAUSE confirmed:** the wife's `users.display_name` is
   **NULL** (she never set a name at onboarding) → reinforces require-display-name-at-
   onboarding + the **recipient-local-name** precedence (display-polish batch #1).
   **ENHANCEMENT (Joshua likes; secondary / if-easy):** if the
   RECIPIENT has a local contact for the sender (e.g. she has him as "Husband"), prefer
   **HER local name** over his self-entered name — show the relationship name each side
   chose. Depends on a local contact existing (the connection signal now creates one).
2. **⚠️ WRONG ANIMATION VERSION:** sent with Plane → arrival played **Plane v1**, but
   **Plane v2 was LOCKED** as the gold-standard in the animation work. Send/receive is
   resolving the OLD v1, not v2 — a **real regression.** ⚠️ Animation files are in the
   *"never touch without care"* set → needs a **CAREFUL AUDIT-FIRST** investigation
   (where the version is resolved on send/receive, why v1), **NOT a casual fix.** Future
   session.

**NEW FEATURE / UX FINDINGS:**
3. **CONNECTION-STATUS INDICATOR** (re-derived from use; ties to the old pairing
   "green line"): after a connection forms there's **no visual that you're linked.**
   RE-ADD an indicator on the People list / contact, **DRIVEN BY the `senderID` field
   Stage B stamps** (set = connected → show; nil = not). Value both ways: know you ARE
   linked (direct delivery / PATH-1 available) and know you are NOT (sends still go as
   links; an engagement signal). Surfaces data Stage B already creates. Small build;
   **PAIRS NATURALLY WITH STAGE C** (both read `senderID`).
4. **DON'T SEED ALEX DEMO INTO THE PEOPLE LIST:** having the demo as a contact invites
   the *"just send to the demo"* crutch instead of the real first-person flow. The
   demo's place = **SHOWING how it works** (onboarding / help), **not** occupying a
   People-list slot.
5. **REMOVE the cold "[John] added you" NOTIFICATION** (fires when you add a person):
   mechanical / off-brand (LinkedIn-style), the opposite of Pointward's intimate vibe.
   The link model connects via sent **THOUGHTS** (the message is the invite; opening
   forms the connection). The "add → notify" path is a **PAIRING-ERA leftover** — remove
   it; connect the nice way via a real thought. Likely a contained removal — flag for a
   build.
6. **WIDGET — surface it + Phase-3 payoff:** a widget exists; users may not know. Add it
   to the Help / How-To content (it's kind of cool). **Boring NOW** (static
   location-to-location), but **genuinely cool in PHASE 3** with real / live location
   (how far away someone actually is, live). Surface low-key now; value grows with
   Phase 3.

**ADDRESS / CONTACTS / SEND-CHANNEL CLUSTER (decisions + parks):**
7. **ADDRESS-ON-ADD-PERSON — PARKED** pending real use (Joshua expects to keep
   flip-flopping → **stop re-deciding in the moment**; nail it down deliberately after
   usage). **Lean:** if picking from iPhone Contacts WITH an address, use it; else
   proceed with **NO forced location** (don't force a typed address). **CONSTRAINT:**
   keep the ability to add / pick / change address regardless (questioning
   *forced-upfront*, not removing the capability).
8. **CONTACTS PERMISSION — RESOLVED:** ask **ONLY when the user explicitly chooses
   "pick from Contacts"** (vs. manual entry) when adding a person. The user opted in →
   the prompt is expected / self-explanatory, not an invasive upfront wall.
   Contextual-ask principle applied. (Pick-from-contacts can then pre-fill address +
   possibly a send-handle.)
9. **SEND-CHANNEL FORK (open question):** should a `Person` store a send-channel (phone
   number / handle), pre-filled from Contacts, so *"send to Wife"* texts the link
   **DIRECTLY** vs. the manual share-sheet (the clunky Stage-A step)? Smoother, free
   from Contacts — **BUT** needs Contacts permission + a stored-handle dependency; the
   link model deliberately **avoids needing handles** (share any channel at send-time).
   Decide deliberately, with the address nail-down. (Note: the share-sheet clunkiness
   itself is **fixed by Stage C** — direct delivery to connected contacts, no share
   sheet.)

**MANUAL PAIRING — RESOLVED (do NOT re-add):**
10. The fallback for "the connection didn't happen" is **NOT manual pairing codes** — the
    RECEIVER simply **taps the SAME message link AGAIN** in their Messages thread and
    follows the install. The link **PERSISTS** in the conversation (it's a text) →
    inherently **re-tappable**; the fallback is **built into the medium** (this is WHY
    links beat pairing). So do **NOT** keep / surface manual pairing for fallback.
    **Supersedes** the brief "keep manual pairing as an option" lean. **PRINCIPLE:**
    don't re-add retired complexity for hypothetical fallback worries before seeing the
    link method work — **it just did** (connection verified). Revisit only if real usage
    shows the re-tappable-link fallback is insufficient. (The commented pairing machinery
    stays recoverable per never-delete, but there's **no plan to surface it.**)


_(archived 2026-06-23 — from "⭐ NEXT SESSION — START CLEAN (open items + reset protocol) —")_
### ⭐ NEXT SESSION — START CLEAN (open items + reset protocol) — ✅ EXECUTED
_The reset protocol below WAS run and the clean two-phone test completed — **results +
the resolved notification model + the new prioritized list are in the next section**
("CLEAN TWO-PHONE TEST"). This block is kept as the procedure of record._

**STATUS: all committed, clean tree.** Committed this session: Stage A (`d49f503`),
product dump (`e64833a`), Stage B (`3e02eba`) + device-verified two-phone, Stage B
findings (`66828f2`), onboarding 8→5 trim (`550adcc`), identity correction + display-batch
bank (`c5774c2`), Stage C two-path + read-receipts (`8a8f74f`), display polish
(arrival-name + connection indicator + contact-icon→initial) (`90422fd`). **Nothing
uncommitted.**

**WHY START CLEAN.** The afternoon's device testing got **CHURN-FOGGED**: repeated
deletes/reinstalls, two Apple IDs (Joshua + wife), recreated contacts, mismatched builds
across two phones. **Most "bugs" seen are likely CHURN ARTIFACTS, not regressions** — but
the device/server state is too messy to tell real from artifact. **Reset to a known-clean
state before verifying anything.**

**CLEAN-RESET PROTOCOL (do at the START of next session):**
1. **Delete Pointward from BOTH phones** (Joshua's + wife's).
2. **Supabase:** `delete from link_connections;` (clean connection slate). Optionally clear
   test `messages` / `pings`. ⚠️ **LEAVE `users` / `auth.users` accounts INTACT — do NOT
   delete them.** Deleting auth rows is what caused the identity-fork confusion;
   recreating risks new forks. **Identity is stable when accounts are left alone.**
3. **Fresh-install the CURRENT committed build** (Stage A/B/C + display polish, HEAD
   `90422fd`) to **BOTH** phones via Xcode (so both phones run the SAME build — kills the
   mismatched-build artifact).
4. **Sign in:** Joshua as his Apple ID, wife as hers — ⚠️ **have the WIFE SET A DISPLAY
   NAME this time** (her account's NULL `display_name` is the root of the "someone"
   arrivals).
5. **Recreate ONE clean contact** for her ("Jessica") on Joshua's phone.
6. **Form ONE clean connection:** Joshua sends → she opens → connection forms → his
   contact stamps her `senderID`.
7. **THEN verify methodically (baby steps), one thing at a time:**
   - Arrival shows her name (local label "Jessica" or her now-set display name), **NOT
     "someone"**.
   - Green **"connected ✦"** appears on her contact (`senderID` stamped).
   - Contacts show **initials**, no emoji, no blank avatars.
   - **Stage C PATH 1:** a send to the connected contact goes **DIRECT (no share sheet)** —
     the clean Stage-C verify the churn muddied.
   - **No double-send** (`pings` / `messages` row counts).

**OPEN ITEMS / BUGS TO CHASE (on the clean slate):**
1. **"[Name] connected" STUCK BANNER** — e.g. "Jessica connected" popped, wouldn't
   dismiss, only opened the contact on tap. Likely a **notification-dismiss bug**; may
   relate to / conflict with the "remove the cold added-you notification" decision + the
   connection-indicator work. **Investigate clean.**
2. **Display batch needs CLEAN device verification** — committed on build-strength
   (Release + 248 tests), but the churn prevented a clean device check.
3. **Per-device limitation (again):** recreated contacts after reinstall may have **nil
   `senderID`** (no green) until re-connected — **expected**; ties to the future
   restore-from-server refinement.
4. **"someone who loves you" caption + bucket-catch** = confirmed **OLD-PHASE
   copy/mechanism**, **NOT touched this session** — note for the eventual receipt /
   old-surface cleanup pass.
5. **Double-tap link bug** (link needed 2 taps) = **universal-link cold-start race**
   (separate read-only audit, **medium priority** — per the identity audit §5).


_(archived 2026-06-23 — from "⭐ CLEAN TWO-PHONE TEST — RESULTS + RESOLVED NOTIFICATION MOD")_
### ⭐ CLEAN TWO-PHONE TEST — RESULTS + RESOLVED NOTIFICATION MODEL + NEXT-SESSION PRIORITIES
_Ran the CLEAN-RESET PROTOCOL above (apps deleted both phones; `link_connections` /
`messages` / `pings` cleared; **accounts KEPT**) → a clean Joshua↔Jess two-phone test.
This is now the **current source of truth** for what's verified + what's next (supersedes
the churn-fogged afternoon findings)._

**WHAT VERIFIED CLEAN:**
- ✅ **Connection forms** (Stage B re-verified clean): Joshua sent Jess a link → she
  opened → `link_connections` row formed.
- ✅ **Connection indicator works:** Jess's contact shows green **"connected ✦"** after a
  relaunch (the green line is back; appears on the next `syncConnections`, not instantly).
- ✅ **PATH 1 direct delivery works:** the 2nd send (Jess now connected) went **DIRECT (no
  share sheet)**, played the in-app arrival (envelope → "thought is arriving" → animation).
- ✅ **In-app arrival "from John" is correct** (Joshua is the sender).
- ✅ **New build confirmed on device** (real contacts show **initials**, not emoji).

**⭐ NOTIFICATION / AWARENESS MODEL — RESOLVED** (test-user Jess: _"only notify once a
connection is set"_). One awareness mechanism per path:
- **NOT connected (PATH 2 / link)** → the **SMS/link IS the awareness**; **NO push** (they
  may not even have the app).
- **CONNECTED (PATH 1 / direct)** → a **PUSH fires, NAMED** ("John sent you a thought ✦").
  Tapping it **OPENS the app and ROUTES TO THE ARRIVING THOUGHT** — plays the **full
  arrival** (envelope w/ sender name → animation), **NOT the home screen.** (Joshua
  confirmed: the notification opening the app + playing the thought together is right.)
- **App OPEN** → no push (iOS suppresses); the arrival **plays in-app directly**.
- Net: **app-closed → push → tap → arrival; app-open → arrival plays directly.** Push =
  the "wake them" mechanism; both paths land on the **same animated arrival.** This
  resolves the earlier "notification or message?" open question.

**⭐ NEXT-SESSION PRIORITIES (prioritized; led by the push gap).** Each item is now also
**FOLDED into its phase home** (see *Re-sequenced Build Order* + *REMAINING BUGS
(unphased)* below) so work is organized by phase; this list keeps the cross-cutting
priority order. Phase tag appended to each `→`.
1. **[HIGH] PATH 1 direct-send PUSH NOT FIRING when app closed.** `→ FINISH 11b/STAGE C
   (keystone).` Confirmed a **CODE gap,
   NOT permission** (Jess had notifications ALLOWED + 6 `device_tokens`, app closed → NO
   push, NO message → she was **totally unaware**). Direct delivery lands in-app but
   doesn't notify when closed. **Read-only audit of the send→push path for PATH 1:** does
   the senderID-keyed `sendRemote` trigger a push? is the push wired for the old
   pairing/pings path but not the new PATH 1? does it resolve her **current** device
   token? **The fix delivers exactly Jess's model.** SPEC: named push → tap opens app →
   plays the arrival.
2. **[HIGH] Share/invitation MESSAGE TEXT says "Someone sent you a thought" not "[John]".**
   `→ FINISH 11b/STAGE C.` The designed warm copy ("[John] sent you a custom animated message ✦ tap to preview")
   isn't live — the outgoing SMS uses generic text + doesn't pull `display_name`. Wire the
   designed copy + sender name into the share message body (`createAndShareLink` /
   ShareSheet). **The first impression the recipient sees.**
3. **[MED] Name on the ENVELOPE (decided).** `→ FINISH 11b/STAGE C.` The in-app arrival is name-free; put the
   resolved sender name (`resolvedSenderName`: local-label → `display_name` → "someone") on
   the **ENVELOPE** — the arrival's natural "who's this from" surface.
4. **[MED] Forced-send-on-contact-add friction (hit 3×).** `→ BUILD 9b` (with "remove
   [John] added-you notification"). Adding a contact **forces a
   send** to complete → Joshua repeatedly sent stray links (to daughter Joanna).
   Contact-add must **just add the contact, no forced send.** Ties to "remove cold
   added-you notification / no auto-send on add." **Actively sabotages testing —
   prioritize.**
5. **[MED] Legacy "connect with [name]" pairing screen** `→ BUILD 9b.` Still surfaces on tapping a
   not-yet-connected contact (bypassable via "done", so clutter not block). **Retire it** —
   tapping a contact should go **straight to compose.** Pairing-era-leftover cleanup.
6. **[MED] Onboarding name-not-persisting + skip-transition lingering screen (likely ONE
   bug).** `→ BUILD 10` (ROOT of the wife's NULL display_name → "Someone" arrivals).
   Wife's typed name saved as **NULL** (suspect skip fired **before** the name
   committed); same step's text field **LINGERS** after skip (non-blocking only because the
   skip button sits at top — a lucky near-miss). Likely a **re-index artifact**; check the
   name-entry commit-on-advance + transition teardown in `OnboardingView`. _(This is the
   root of the wife's NULL `display_name` → the "someone" arrivals.)_
7. **[MED] Settings needs a PROFILE section.** `→ BUILD 10` (ties to the Settings-tab
   review project). No way to view/edit your own display name or
   address (hit twice — Joshua + wife both **set-blind**, can't confirm). Slots into the
   Settings-tab review project.
8. **[LOW-MED] Double-tap link bug** `→ SEPARATE SMALL AUDIT` (read-only, per identity §5).
   Reconfirmed clean: the `/m/` link in Messages takes
   **2 taps not 1.** Universal-link cold-start race. Separate read-only audit (per identity
   audit §5: verify cold-launch `userActivity` replay covers the **FIRST** `/m/` open).
9. **[NOTE] "someone who loves you" caption + bucket-catch** `→ BUILD 10` (old-surface
   copy cleanup). = **OLD-PHASE copy/mechanism, not touched** — for the eventual receipt /
   old-surface cleanup pass.
10. **[NOTE] Alex Demo disappeared** once a real contact was added — `→ REMAINING BUGS
    (unphased) / NOTES` — likely intended; confirm.
11. **[NOTE] First-send-only animation breakup/noise** (clean: stutters on the **1st** send
    after launch, **2nd** is clean) — `→ REMAINING BUGS (unphased) / NOTES` —
    cold-start/warm-up pattern; **animation territory, careful.**


_(archived 2026-06-23 — from "⭐ PRE-TEST BATCH — 5 FIXES BUILT — ✅ TESTED + COMMITTED (see")_
### ⭐ PRE-TEST BATCH — 5 FIXES BUILT — ✅ TESTED + COMMITTED (see next section)
_The plan below RAN; all 5 fixes + the push function passed the clean two-phone test and
are **COMMITTED** (`d03eb3e` + `feafe7a`). See **"BATCH + PUSH FIX — COMMITTED +
DEVICE-VERIFIED"** below for the outcome + new findings. This block is the procedure of
record._

_The NEXT-SESSION PRIORITIES above are now BUILT (the HIGH/MED items #1–#5/#8). All sat
**uncommitted** in the working tree (HEAD `c7cfcc7`), batched for **one** clean two-phone
test before commit. Each built green (Release + 248 tests) with its own report under
`reports/`._

**THE BATCH (built, Release + 248 tests green, NONE committed — commit AFTER the test):**
- **#8 DOUBLE-TAP** (cold-launch first-tap routing): NEW `SceneDelegate` + `PendingLink`
  capture the `/m/` link at the **scene boundary**; `RootView` pending-slot +
  `presentPendingMessageIfReady()` gates on `!showSplash` (generalizes the debug 1 s defer).
  Push-tap **NOT** rewired (it's a ping → plays via PingManager's own queue — confirmed
  correct). Files: `PendingLink.swift` (new), `SceneDelegate.swift` (new), `AppDelegate.swift`,
  `RootView.swift`. _(report: `double_tap_fix_build.md`)_
- **#2 SHARE-TEXT**: `MessageLink.shareText` → designed named pitch **"[sender] sent you a
  custom animated message ✦ tap to preview"** (was generic "Someone sent you a thought");
  empty-name → warm generic. File: `MessageLink.swift`. _(report: `share_text_fix_build.md`)_
- **#3 ENVELOPE-NAME**: the arrival envelope shows **"from [name]"** (reuses
  `resolvedSenderName`: local-label → `display_name` → "someone"), faded in mid-beat from
  the existing fetch. File: `IncomingMessageView.swift`. _(report: `envelope_name_build.md`)_
- **#4 FORCED-SEND-ON-ADD removed** (kills #4a + #4b): `AddPersonView` no longer
  auto-presents the invite share sheet; add = create contact + dismiss. No forced share, no
  "I added you" SMS. File: `AddPersonView.swift`. _(report: `contact_connect_cleanup_build.md`)_
- **#5 LEGACY CONNECT SCREEN removed**: `PersonDetailView`'s "connect with [name]" pairing
  CTA + code-entry `#if false`'d; tap a not-yet-connected contact → straight to compose
  (existing select→compass path). File: `PersonDetailView.swift`. _(same report)_

> Also uncommitted: the **benched push function edit** (`send-ping-notification/index.ts` —
> #1: named "[name] sent you a thought ✦" banner + `users.display_name` source, retires
> "someone who loves you"). It needs **Joshua to redeploy** (`supabase functions deploy …`)
> + the webhook/APNs-secrets live (per `path1_push_audit.md`) — server-side, separate from
> the client batch's git commit.

**OBSTACLE-REMOVAL STATUS** (what sabotaged the LAST two-phone test):
- ✅ **Forced-send-on-add** (stray links to daughter Joanna) — FIXED (#4).
- ✅ **Legacy "connect with [name]" detour** — FIXED (#5).
- ✅ **Mismatched builds / churn-fog** — addressed by the clean-reset (delete+reinstall BOTH
  on the SAME build).
- ✅ **"Someone" arrivals** — names set (John + Jessica-via-SQL); #2/#3 surface them.
- ⚠️ **Stuck "[name] connected" banner** — **NO live client code found**
  (`contact_connect_cleanup_audit.md` §4). Likely a **STALE DELIVERED iOS notification**
  (churn residue). **ACTION:** clear Notification Center on the reset; watch if it recurs;
  capture the payload via **Console** if it does. **No code to remove.**

**FOLLOW-UP FLAGS (not blocking the test):**
- `MessageComposerView` (`ConnectView.swift`) now **orphaned** by #5 → confirm + retire in
  the cleanup pass.
- `PersonDetailView`'s linked **"Connected ✓"** card is still **pairing-driven**
  (`isConnected = pairedUserID == connectedFriendID`); reconciling it onto `senderID` (to
  match the link-era **"connected ✦"**) is a future consistency item.
- The **NAMED surfaces** (push banner / share text / envelope) all depend on
  `users.display_name` being set → the **onboarding name-persist bug (#6)** is the upstream
  fix so FUTURE users' names save (**Build 10**). Today's test uses manually-set names.

**⭐ CLEAN TWO-PHONE TEST PLAN (one unobstructed shot; needs Jess's phone):**
- **SETUP:** delete Pointward on **BOTH** phones → fresh-install the current build (with the
  batch) via Xcode → both sign in (Joshua = **John**, Jess = **Jessica**). **Clear
  Notification Center** on both (banner watch). Open the Edge Function logs (dashboard →
  Edge Functions → `send-ping-notification` → Logs) for the push step.
- **STEP 0 — app cold-launches NORMALLY on both** (no black screen) — verifies the
  `SceneDelegate` didn't break launch. _(If black screen: remove
  `configurationForConnecting` from `AppDelegate` — reversible.)_
- **STEP 1 —** create **"Jessica"** contact on Joshua's phone (manual; no Contacts
  permission; skip address) → confirm **NO forced share sheet** (#4 ✓) → send her a thought
  → PATH-2 link → the **share-sheet text reads "John sent you a custom animated message ✦
  tap to preview"** (#2 ✓) → share the link to her phone.
- **STEP 2 —** Jess's app **FULLY CLOSED** → she taps the link → **opens to the arrival on
  the FIRST tap** (#8 ✓) → the **envelope shows "from John"** (#3 ✓). Her opening **forms
  the connection**.
- **STEP 3 —** Joshua foregrounds → the **"Jess" contact shows green "connected ✦"** (+ a
  `link_connections` row). **Tapping the contact goes straight to compose, NO "connect with
  X" screen** (#5 ✓).
- **STEP 4 —** Jess's app **FULLY CLOSED** → Joshua sends again (now connected → **PATH-1
  direct**) → a **NAMED push "John sent you a thought ✦"** fires on her closed phone (watch
  logs **③ tokens / ⑤ APNs**) → she taps it → **opens to the arrival** (#8 push-tap). _[The
  benched push smoke test — `APNS_SANDBOX=true` for dev builds.]_
- **STEP 5 —** if all pass: **COMMIT the batch** (5 fixes) + the push function edit. If any
  fail: **diagnose before committing.**


_(archived 2026-06-23 — from "⭐ BATCH + PUSH FIX — COMMITTED + DEVICE-VERIFIED (session cl")_
### ⭐ BATCH + PUSH FIX — COMMITTED + DEVICE-VERIFIED (session close)

**DONE + COMMITTED:**
- **App batch `d03eb3e`** (5 fixes): **#8** double-tap cold-launch routing
  (`SceneDelegate` + `PendingLink`), **#2** named share-text, **#3** envelope sender name,
  **#4** forced-send-on-add removed, **#5** legacy connect screen retired. **ALL
  device-verified** in the clean two-phone test.
- **Push Edge Function `feafe7a`:** fixed a **pre-existing BOOT CRASH** (duplicate `payload`
  declaration — the function **never could have booted**, which explains the PATH-1 audit's
  "push not live"); **named the banner** from `users.display_name` (retires "someone who
  loves you" = bug #9); **removed the silent badge-only (`unread>1`) branch** so **every**
  PATH-1 send shows a named banner (the Jess model). **DEVICE-VERIFIED:** the named push
  **"John sent you a thought ✦"** fired on a **closed** phone → tap → **opened to the
  arrival** (the heart played). Deployed to `jlbgdlgwtrkmqcfnomlr`.
- **⭐ PATH-1 PUSH IS NOW WORKING END-TO-END — the send model's last functional gap is
  CLOSED.**
- **Infra confirmed live:** trigger `on_ping_insert` → `notify_ping()` →
  `send-ping-notification` Edge Function → APNs; APNs accepts (7/8 tokens 200; 1 stale is
  normal; `APNS_SANDBOX=true` for dev builds).

**NEW BUGS / FINDINGS (all phone-free to work next):**
1. **[MED] PersonDetailView CONNECTION-STATE DISAGREEMENT** — `PeopleListView` shows green
   **"connected ✦"** (senderID-driven), but tapping the contact opens PersonDetailView's
   **"not yet linked"** page, because PersonDetailView's linked check still uses the
   **PAIRING** field (`isConnected = pairedUserID == connectedFriendID`), **NOT senderID**.
   Blocks tap→compose for connected contacts (worked around via the compass tab in testing).
   **FIX:** reconcile PersonDetailView's linked check onto `senderID` to match PeopleListView.
   _(Was flagged as a "future consistency item" — it's actually **load-bearing**.)_
2. **[MED] UNREAD COUNT NEVER CLEARS** — the recipient's badge climbs (3→4…) and doesn't
   reset when she opens/views the app: opening isn't marking thoughts read/opened. Was
   **masking the push test** (kept `unread>1`, which the silent branch keyed on — now moot,
   PATH-1 always alerts). **Diagnose:** where unread is computed (server count of unopened
   pings/messages) + why opening doesn't decrement it.
3. **[LOW] SENDER-REINSTALL RE-STAMP GAP** — a sender who reinstalls loses the local
   `SentLink` (messageID→personID), and the idempotent `link_connections` PK keeps the OLD
   `via_message_id` → `stampConnections` can't match → no green. Re-heals only by deleting
   the connection row + re-connecting. Ties to the future **per-device restore-from-server**
   refinement (the stamp should be recoverable from the server connection, not only the local
   SentLink).
4. **[LOW] CONNECTION SYNC needs app foreground/relaunch** (sender green lags) — ideally
   syncs without a manual relaunch (timer / scenePhase poll). Polish.
5. **[CLEANUP] STRAY EDGE FUNCTION** — a duplicate function with the SAME display name
   "send-ping-notification" but slug **`rapid-action`** exists (NOT wired to the webhook).
   **DELETE** it in the cleanup pass; the webhook uses the **`send-ping-notification` slug =
   the live one**.
6. **[NOTE — RESOLVED] DOUBLE-TAP = iOS Messages behavior** (the link "becomes solid" on tap
   1, opens on tap 2), **NOT an app bug.** #8 is still valid as cold-launch routing hardening
   (lands on the arrival once opened). **Not a defect to chase.**
7. **[DEP] NAMED surfaces** (push / share-text / envelope) all depend on `users.display_name`
   being set → **onboarding name-persist (#6)** is the upstream fix for FUTURE users
   (**Build 10**). Today's test used manually-set names.

**FOLLOW-UP FLAGS (from the batch):**
- `MessageComposerView` (`ConnectView.swift`) now **orphaned** by #5 → confirm + retire
  (cleanup pass).
- The function edits are committed but the local env had **no Deno** → no `deno check` (a
  duplicate-`payload` boot bug slipped through once this way); **a `deno check` belongs in
  any future Edge Function edit.**

**⭐ REMAINING WORK — ALL PHONE-FREE (the runway):** PersonDetailView fix (#1), unread-clear
bug (#2), **9b** dead-pairing cleanup, **Build 10** onboarding rewrite + **#6** name-persist,
**Phase-2 test suite (#11)**, **cleanup pass** (incl. the `rapid-action` stray,
`MessageComposerView`, gitignore `reports/`). **Two-phone testing is NOT needed to progress
these** — device checks come individually at each item's end.


_(archived 2026-06-23 — from "⭐ 9b DEAD-PAIRING CLEANUP — COMPLETE ✅")_
### ⭐ 9b DEAD-PAIRING CLEANUP — COMPLETE ✅

**DONE (committed):**
- **B1 (`abc9e77`)** — dead pairing VIEWS hard-deleted: `ConnectView` (+ orphaned
  `MessageComposerView`), `PairAcceptView`, `AccountView` (+ `PairingCelebrationView`) + the
  `#if false` blocks in `RootView`/`PersonDetailView`.
- **B2 (`6c7f8c5`)** — pairing invite-ACCEPT API + DI retired: `redeem`/`redeemCode`/
  `createInvite`/`createProfileInvite`/`lookupInvite` (+ `insertInvite`/`updateInviteProfile`/
  `stampLocation`/`FullConnectionRow`/`RedeemResult`); `PairingServiceProtocol` /
  `MockPairingService` / `ServiceContainer.pairingService`.
- **B3+B5 (`9883a60`)** — orphaned PeopleManager funcs (`addFromInvite`/`bindConnection`/
  `insertFromInvite`/`person(forPairedUserID:)`) + `claimOutcome`/`PairOutcome` +
  `PairingScenarioTests` retired (`SkipOnboardingTests` migrated to `person(forSenderID:)`,
  green); `PersonDetailView.isConnected` collapsed to **senderID-only**; PersonDetailView
  leftovers mopped (unused `MessageUI` import + 9 dead `@State`). **246 → 228.**
- **B4 (`04e80d6`)** — dormant mutual-pointing cluster unwired: `presenceFelt`/
  `checkMutualPointing`/`partnerPointing*` state, the CompassView **edge-glow**, CompassManager
  `presenceTimer`/`reportPointingIfNeeded`, the `reportPointing` no-op stub; the pointing test
  retired (**228 → 227**). ⭐ **`NotificationHandler` thought/PATH-1 push branch BYTE-IDENTICAL**
  (push intact); **device-glance passed** (compass renders, send/receive + notification
  confirmed).
- **Server-side:** the stray **`rapid-action`** Edge Function **DELETED**.

**REMAINING (by design — NOT 9b dead-pairing scope):**
- ⭐ **The LIVE pairing-CODE-GENERATION subsystem STAYS** — sign-in still mints a pairing code
  (`myPairingCode` → `connections` table): `generatePairingCode` / `ConnectionRow` /
  `normalizePairingCode` / `isValidPairingCode` / `localPairingCode` / `refreshConnections` /
  `DiscoveredConnection`. Fully retiring THIS (+ the `connections` table + the legacy
  thought-invite path) is a **SEPARATE post-9b item**, gated on the thought-invite path going.
  Decision-involved — **around/after Build 10.**
- **`connectedFriendID` preserved** (load-bearing, live in `PingView`; no longer pairing-written
  → stays nil in production = correct link-era state).
- **Edge Function `compass_bearings`/"pointing" branch** — dead but harmless; retire at any
  future function edit (no client sends pointing pushes now).

**SURFACED DURING 9b (investigate / decide later):**
1. **Mystery prompt** "show arrival previews, you've seen 10 of them, change settings anytime"
   appeared on send — **origin unknown, NOT 9b-related.** Investigate which feature/setting
   drives it.
2. ⭐ **History replay = emoji + message only, NOT the full arrival animation.** Joshua's lean:
   replay **SHOULD** play the full animation (envelope → instrument → reveal) — re-feeling
   should be the full experience. Product/build item (the replay path; ties to "replay =
   re-feel").
3. **Trailing cleanup leftovers:** `CompassManager.lockedSince` now write-only; RootView
   `PairRequest` model orphan; OnboardingView `#if false` `createProfileInvite` ref (→ Build
   10); gitignore `reports/`; build-12 double-commit squash; Xcode warnings (stay Swift 5).

**⭐ MILESTONE:** with 9b done + the send model + push complete, **the link-era pivot is
SUBSTANTIALLY COMPLETE** — the app runs on the link model; the dead pairing surface is swept
(only the live sign-in code-mint remains, flagged as a separate item).

**NEXT:**
- **TOMORROW AM — Build 10:** onboarding rewrite + **#6** name-persist (decision-heavy, fresh
  session).
- **Before Build 10 (optional warm-up, low-judgment):** the final cleanup pass (wrap §3
  leftovers).
- **Held for around/after Build 10:** pairing-code-gen retirement; animation **#12/#13/#14**
  (other tab).


_(archived 2026-06-23 — from "Key Architecture Finding — the history bucket is PER-PERSON ")_
### Key Architecture Finding — the history bucket is PER-PERSON (pairing-era) — ✅ RESOLVED (build 9)
> **✅ RESOLVED in build 9** (the sender-agnostic conversion below). The finding is
> kept for history; the bucket no longer fetches by `pairedUserID` — it is built
> from LOCAL `caughtHistory`, all senders, and `/m/` opens now record into it.
> (The "repoint server fetch to messages/senderID" idea was superseded: there is
> **no `messages`-sent-to-me server query** — `messages` is sender-keyed, no
> recipient column — so the bucket went LOCAL instead.)

The compass history bucket (`thoughtsDrawer` / **"your bucket ✦"**,
The compass history bucket (`thoughtsDrawer` / **"your bucket ✦"**,
`CompassView.swift`) is **per-person and pairing-era**, and **fully LIVE** (not
stale or half-migrated):
- Scoped to `selectedPerson`; reload keyed to it
  (`.task(id: people.selectedPerson)` ~line 925, `.onChange(of: selectedPerson)`
  ~line 999).
- Server fetch **by `pairedUserID`** (`loadCompassThoughts()`,
  `fetchPings(with: pid)` ~line 2318).
- Local merge filtered **`isTest || fromName == selectedPerson.name`**
  (`mergedLocalHistory`, ~line 2334) — attributes every item to the tracked
  contact.

**Consequence:** it structurally **cannot** show link/short-code messages from
non-selected or unsaved senders. 4b's "rest to history" lands in the store but is
**hidden** by the per-person filter for any non-selected sender — recovery of
held-back messages currently works **only by RE-ENTERING the short code**.

The link-delivery model **requires a sender-agnostic unified bucket** ("all
thoughts sent to you"). This is a **NEW requirement, not a regression** — the
"unified" impression in past testing came from `isTest` messages **bypassing** the
per-person filter (test data looked unified; real multi-sender data is not).

**DECISION:** the bucket conversion is **coupled to pairing removal** — it can't
become sender-agnostic while it fetches by `pairedUserID`. So it is scheduled
**WITH build 9** (retire pairing data layer), not as a standalone build.

**SHARPENED (build 6 confirmed the exact seam):** the bucket's SERVER fetch
(`loadCompassThoughts → fetchPings(with: pairedUserID)`) queries the **`pings`**
table — but link sends live in the **`messages`** table. So a link contact gets
**ZERO server-side bucket content**; only LOCAL `caughtHistory` (the short-code
"rest" + locally-caught thoughts, matched by sender name) shows. Build 5's
mirror-write makes `pairedUserID` non-nil so the fetch *runs*, but it queries the
wrong table → empty. **Build 9 must repoint the server fetch from
`pings`/`pairedUserID` → `messages`/`senderID`, reconciled with the
sender-agnostic unified-bucket goal.** Benign until then: no crash; worst case is a
thinner bucket / "all caught up ✦". (Surfaced because build 6's launch default now
auto-selects the most-recent LINK contact.)

Also: tapping a bucket item **REPLAYS but does NOT flip opened**
(`replayThought`, ~line 2286 — no `markOpened`). Only live receive + `/m/` open
flip `opened_at`. The unified rework should decide whether replay-from-history
marks opened.


_(archived 2026-06-23 — detail behind: ⭐ BUILD 10 — OUTCOME + LOCKED DECISIONS (shipped `)_
### ⭐ ONBOARDING / ARRIVAL NORTH-STAR (Build 10 vision)
**Arrival path determines the experience.** (Absorbs the earlier "subtractive cut" —
the dead connection-code screen is removed + repositioned as part of THIS redesign.)

- **MESSAGE-ARRIVERS (tapped a link):** the **message plays FIRST, unblocked — the
  thought IS the welcome, NO onboarding gate.** If the link opened the INSTALLED app,
  they're already converted — no hard sell. After the message, **three calm,
  non-blocking doors:** (1) **"send one back ✦"** (→ just-in-time sign-in/name at THIS
  moment — the same moment the connection record forms); (2) **"learn more"** (→
  optional showcase); (3) a **graceful warm exit** — copy: *"Got the message, I'm good
  for now."* (respecting a leaver builds more goodwill + return-likelihood than a
  pitch; on-brand). **Offer, never ambush/interstitial.**
- **DISCOVERY-ARRIVERS (App Store / ad):** minimal mandatory core = **SIGN IN +
  DISPLAY NAME** (the name travels in links); **location optional.**
- **SHOWCASE** (instrument carousel / "ways to send" / the cool-but-ad-like content):
  **GOOD content, WRONG place** — move OUT of the blocking flow into an **explorable
  section/tab** ("how it works" / "explore"), discoverable (a skippable "tour?" or a
  clear tab), **not a gate.**
- **PAYWALL + charity:** move OUT of onboarding to **CONTEXTUAL moments** — the paywall
  at the point of **using a premium instrument** (monetize at desire, not as an
  entry toll).
- **IDENTITY just-in-time:** capture sign-in / name at the **moment of action (reply)**,
  not upfront — the same moment the connection record forms.

**Walk-through decisions (this session):**
- **DROP THE PAIRING-CODE SCREEN (confirmed).** Remove the dead connection-code entry
  screen — useless post-pairing, one less click. **ABSORBED into the Build 10 redesign**
  (not a separate build). ⚠️ **CAUTION at build:** the subtractive audit flagged a
  **`loopFlick` animation-guard concern** when removing it — remove **carefully**, not a
  blind delete (re-verify the page-coupled animation guards).
- **NAME PRE-FILL (LOCKED — Joshua likes it).** In the recipient's just-in-time name
  fill-in, **PRE-FILL the name with whatever the SENDER addressed them as** — the name
  travels with the message (a mirror of `sender_display_name`). Shown **warmly** (it's
  the affectionate name someone used for *you*), with **"edit"** beneath. Half the time
  it's their real name (one less click); the other half a nickname (still fine, even
  sweet); **editable always.** **Never worse, often better.** **No "is this you?"
  hedging** — just show it with an edit affordance. Small plumbing: carry the **sender's
  label for the person** alongside the message (same channel as the connection signal).
- **ADDRESS / LOCATION AT ONBOARDING — FOR CONSIDERATION (open, decide during Build 10).**
  Three options on the table:
  - **(a) DON'T require an address at onboarding at all** (lean — minimal mandatory =
    sign-in + name; ask location **contextually** if/when the compass needs it, not as an
    entry toll);
  - **(b) AUTO-POPULATE from the Apple/device home address** (needs **CONTACTS
    permission** — an invasive-feeling prompt + trust cost; weigh against (a));
  - **(c) keep AS-IS** (manual entry).
  - **DEEPER question to resolve FIRST: what is location/address even FOR?** The compass
    "points toward people" — does it need a typed **STREET ADDRESS**, or just **ROUGH /
    DEVICE LOCATION** (direction + distance)? If rough location suffices, there may be
    **no address field at all** — just a gentler **Location** permission, contextually.
    **Sequence:** what is it for? → address vs. rough location? → required vs.
    contextual? → only then, how to fill.


_(archived 2026-06-23 — from "⭐ BUILD 10 — DECISIONS + REASONING (design session complete ")_
### ⭐ BUILD 10 — DECISIONS + REASONING (design session complete except the link-arriver path)
_The full design session. Audit references: `reports/build10_onboarding_audit.md` (#6 root +
touch-map) + `reports/build10_prep_audit.md` (open-fact verification + screen inventory)._

**⭐ GOVERNING PRINCIPLE — friction-free for most + require info only WHEN IT'S USED
(just-in-time) + TUTORIAL-AS-SETUP** (each setup step teaches its own *why*). **WHY:** the user
already has the app, so setup can afford to educate — every ask doubles as "that's what this
does." Field test: *"is this needed for what they're about to do?"* The
**link-arriver-vs-fresh-installer PATH-SPLIT is a CONSEQUENCE of the principle** (it sets the
timing), **not a separate rule.** **REFINEMENT:** require-when-used applies when there's a CLEAR
use-moment; when there isn't one (notifications), an honest **upfront** ask is fine.

**LOCKED DECISIONS (with reasoning):**

- **NAME — required at the SEND-MOMENT** (sender always has one → satisfies #6; receiver/viewer
  not asked). **WHY:** the name travels in every message; null name = "Someone"/#6. Path falls
  out: fresh installer (sends first) → asked in onboarding; link-arriver (receives first) →
  deferred to "send one back." Self-explaining copy: *"Your name — how you'll show up on this
  notice and all you send; won't ask again; edit on any message if you want."* Edit-per-message.
  **Apple pre-fill:** sign-in ALREADY requests `.fullName` but discards it → Build 10 reads
  `credential.fullName` at the callback to pre-fill (**TRIVIAL — verified**). Never relied on
  (reinstall/edit) — the flow **GUARANTEES `users.display_name`**. **NO Contacts-for-name**
  (invasive).
- **LOCATION — DON'T FORCE.** Setup offers **THREE options: Skip** (seeded bearing,
  friction-free default) / **Type in** / **Use current location** (one-time allow → real
  coordinate). **WHY don't force:** (a) it's the SENDER's felt directionality (pointing toward a
  loved one), not a receiver requirement — your own location is just the **ORIGIN** for the aim,
  the part users care least about; (b) Phase-3 live location makes manual entry moot. **"Use
  current location" = the first INCREMENT / on-ramp to Phase 3** (builds the permission +
  get-coordinate plumbing now, one-time; Phase 3 extends to live). Backward-inference from a
  send **RULED OUT** (a send carries at most direction, not DISTANCE → can't reconstruct a
  location). **AUDIT-CONFIRMED: sends carry NO location at all** → a contact's location is a
  local recipient-set act, never transmitted. Deny → seeded fallback. One location prompt
  (primed), not per-time.
- **SIGN-IN PLACEMENT — fresh installer: SIGN-IN FIRST**, then setup (name→location), then
  showcase (provisional). **WHY:** get the small commitment early at peak download-intent
  (**commitment momentum** — the rest becomes "continuing," not "deciding to start"); a fresh
  installer already opted-in by downloading, so "value-first" (for cold traffic) doesn't apply.
  **Link-arriver:** real message first → view/explore WITHOUT sign-in → sign-in only at "send
  one back."
- **SHOWCASE (Demo Dan / unified first-open) — ONE mechanism on first-app-open.** Fresh
  installer: showcase demo (**provisional** — may dissolve into the tutorial-as-setup teaching;
  don't over-invest). Link-arriver: their REAL message plays first, THEN the showcase is a **TAP**
  (offered, not auto) — **WHY:** they came to read the message; nothing plays before they've read
  it. **Demo Dan** = the empty-state placeholder, replaced once a real contact exists.
- **EDUCATION — lives in Settings** ("How to Use / Optimize / Features / About"), offered not
  forced (after a first receive, or an optional onboard screen). Showcase relocates here, out of
  the gate.
- **NOTIFICATIONS — keep UPFRONT** (as now): standard yes/no → Apple's screen, no custom copy.
  **WHY:** no crisp just-in-time trigger (unlike location/contacts), so forcing a fake
  just-in-time moment is worse than an honest upfront ask.
- **ADD-PERSON FLOW — offer Contacts autofill** (name + address IF present). If the contact HAS
  an address → **SKIP the location screen**; if NOT → prompt location (just-in-time, only when
  missing). Contacts surfaces ONLY for users who add-a-person that way (an option, not a step).
  **"Often-solution, not all-solution"** — common case frictionless, gap case asks; degrade
  gracefully.
- **GRACEFUL EXIT — link-arriver can "I'm good for now" and leave.** SAFE because the name
  requirement lives at the SEND-moment — if they later send, they're caught then. Exit loses
  nothing.
- **PATCH-NOT-REBUILD — trending** (Build 10 = self-contained additive pieces: #6 fix,
  first-open showcase, one-field setup, add-person flow). Audit-confirmed most screens REUSABLE.
  The one thing a rebuild buys: the swipeable paged `TabView` is #6's swipe-bypass ROOT — a
  non-paged flow dissolves it structurally. **STILL OPEN:** patch-the-paged-flow vs.
  rebuild-non-paged.
- **PAIRING-CODE — RETIRE IT.** **WHY:** audit confirms it's **HALF-DEAD** — show-your-code
  works but ENTER-a-code-to-connect (redemption) was deleted in 9b → a shown code is
  **UNREDEEMABLE** → the Settings "your code" is **misleading dead UI.** Not a failover; a
  vestige. Build 10 should **STOP showing the code.** Full retirement (mint + Settings +
  `connections` plumbing) = its **OWN audit-first task** (this area surprised us twice in 9b —
  `myPairingCode` live, `connectedFriendID` load-bearing), sequenced **around** Build 10, NOT
  blended into the onboarding rewrite. **Don't wire anything new to pairing codes.**

**#6 NAME-PERSIST (the bug Build 10 fixes) — root + fix (audit-confirmed):** three causes —
**(A)** the free-swipe paged TabView lets users swipe past the name screen → `saveAboutYou`
never fires; **(B)** `finishToApp` only sets `hasCompletedOnboarding`, doesn't commit the
profile; **(C)** the SERVER `display_name` write is gated on a geocoded address (optional) →
name-only profile writes LOCAL `displayName` but leaves `users.display_name` NULL. `ensureUser`
does NOT set `display_name` (confirmed). **TWO `display_name` stores split:** LOCAL
(`people.profile.displayName`) feeds send/share/envelope; SERVER (`users.display_name`) feeds the
PATH-1 push banner. **Fix:** write `display_name` UNCONDITIONALLY (not gated on geocode), don't
let swipe bypass the commit, `finishToApp` guarantees it, + the Apple-name pre-fill. **Add a
test** (none guards #6 today).

**AUDIT FINDINGS (`reports/build10_prep_audit.md`):**
- Sends carry **NO location** (confirmed — contact location is local-set only).
- **Mystery prompt = the ARRIVAL-PREVIEW feature** (sender-side post-send glimpse + the Settings
  toggle; intentional, not a bug, not 9b). **Identified, closed.**
- **NO received-history delete** exists (only a silent 50-item FIFO cap; the per-item delete is
  for **CustomThought** templates, not history). TRUTH's PATH-1 save/delete/~30-day-fade is
  **NOT built** → net-new feature if wanted (later, not Build 10).
- Apple name already requested (`.fullName`) but discarded → pre-fill is **trivial** (read
  `credential.fullName`).
- **Screen inventory:** REUSE `signInScreen` (+fullName +display_name guarantee),
  `aboutYouScreen` name field + `addressAutocompleteField`, the `InstrumentPreview` carousel (→
  Settings). RELOCATE showcase/paywall/charity out of the gate (move the finish off
  `givingScreen`). DELETE orphans (`compassScreen`/`thoughtScreen`/`proScreenSkins`/
  `CompletionMoment` + `alignConcept`/`loopFlick` — delete screen+helper together) + the
  `#if false` hero/yourCode/letsGo.

**STILL OPEN (fresh head):**
- ✅ **#2 the LINK-ARRIVER send-back path — now DESIGNED** (structure locked; see the subsection
  below). The design session is complete.
- **Patch-vs-rebuild** structural call (lean **patch**; rebuild's one win = killing the
  swipe-bypass) — resolves when the build is scoped.


_(archived 2026-06-23 — from "⭐ BUILD 10 — LINK-ARRIVER PATH (structure LOCKED; copy = pla")_
### ⭐ BUILD 10 — LINK-ARRIVER PATH (structure LOCKED; copy = placeholder, refine in situ)
_The link-opener's flow. Copy/feel below is **placeholder** — refine in situ (the
core-first/polish-near-publish mindset)._

**FLOW:** tap link → Pointward opens → their **REAL message plays** (the thought, **no gate**) →
**LANDING SCREEN** with three doors → each door's flow.

**LANDING SCREEN** (after the message plays) — three options _(likely ~exists today; verify —
possibly the `CompletionMoment` screen)_:
- **"Send one back to [Name]"** (primary)
- **"See what Pointward is"** (secondary)
- **"I'm good for now"** (quiet exit)
_(Placeholder copy/feel — calm, the just-received thought still resonant.)_

**"SEND ONE BACK"** → straight into composing back to [Name] (**no separate signup wall**).
Captures, **pre-filled from stored records via the link (confirm-don't-enter):**
- **NAME** — label *"Your name"*, helper *"This is how [Name] will see you."* Fill ladder:
  **stored-in-record (via link) > Apple ID (`credential.fullName`) > type.** The **#6 guarantee
  lands here** (`display_name` written).
- **LOCATION** — *"Add your location?"*, helper *"Lets your thoughts point the right way."* Three
  options **skip / type / use-current.** Fill ladder: **self-set > connected user's stored
  location (via link) > null → seeded.** Never forced.
_(Placeholder feel: **"answering," not "registering"** — refine warmth in situ.)_

**"SEE WHAT POINTWARD IS"** → the **showcase** (same content as the fresh-installer showcase /
Demo Dan — the `InstrumentPreview` showcase). A **tap** (offered, not auto).

**"I'M GOOD FOR NOW"** → quiet exit, no setup pressure. Name caught later IF they ever send (the
**send-moment guarantee**). Exit loses nothing.

**⭐ FILL MODEL (key — applies everywhere):** fields are **READ from stored DB records via the
LINK, NOT transmitted in the send** (the send stays lightweight = just the thought). One source
of truth (the record), reached via the relationship. **Verify in build:** (a) user records STORE
location; (b) the link grants **READ-ACCESS** to a connected user's stored fields
(name/location) — RLS/perms.

**RELEASE MINDSET (noted):** build **CORE/STRUCTURAL** now (adds, links, data plumbing — the
expensive-to-change foundation); **NICETIES** (copy/look/feel) = iterative **POLISH ROUNDS near
publish** (expected to take several rounds), across BOTH onboarding screens AND animations.
Polish is a **pre-launch pass, not now.**

**STILL OPEN:** patch-vs-rebuild — resolves when the build is scoped (does the build need to
dissolve the swipeable paged `TabView`, or can it adapt it). _(RESOLVED IN BUILD: **PATCHED** —
the paged TabView was adapted in place, not rebuilt; see the walkthrough subsection below.)_


_(archived 2026-06-23 — from "⭐ BUILD 10 — PHONE WALKTHROUGH FINDINGS + DECISIONS (single-")_
### ⭐ BUILD 10 — PHONE WALKTHROUGH FINDINGS + DECISIONS (single-phone cursory test done)
_Joshua's first on-device walk of the built Build-10 flow. The patch-vs-rebuild question
RESOLVED to **patch** (the paged TabView was trimmed in place, not rebuilt)._

**═══ DONE + COMMITTED (this session) ═══**
- **#6 name-persist fix** (Shot 1); **link-arriver landing placeholder**; **Shot 3a onboarding
  cleanup**; **Shot 2 link-arriver bypass + compose-back + fill-via-link**; **minor cleanup**;
  the **5-fix batch** (name copy, Home Location label, marketing-screen removal, Message-from
  label, door-2 route).
- **Onboarding is now: sign-in → about-you (name + Home Location, FINISHES) → app.** NO showcase
  in the forced flow (intentional — showcase deferred to the optional Yes/No, see below).
- **Link-arriver path works end-to-end (cursory):** 3 doors, names resolve, bypass + compose-back
  + fill validated signed-in; fresh-arriver walked.

**═══ DECISIONS BANKED (this session) ═══**
- **NAME-STEP COPY:** **"How should your name appear to [Name]?"** (locked; replaced "what should
  [Name] call you").
- **HOME LOCATION label:** **"(optional but recommended)"**.
- **"MESSAGE FROM: [Name]" on arrivals** — added (shows who it's from + reinforces editable-per-
  message name). Overlay, **animation untouched**.
- **⭐ FULL SEND+RECEIPT FOR BOTH ROLES** (design direction, **animation-track**): both sender and
  receiver see the full experience **oriented to their role** — **SENDER** sees the **send-out**
  (their thought flying to [recipient]); **RECEIVER** sees the **full arrival** (incoming build-up
  → open); labels flip per role. RECEIVER gets an **extra dialed-in replay** (the wow —
  aimed→tapped→sent→arriving) because they didn't perform it; SENDER doesn't need it (performed
  live).
- **⭐ HINT BAR** (in-context discoverability, **this-tab**): a subtle bottom hint bar on the
  compass/send screen naming hidden options — e.g. *"Choose Animation (tap-hold center)"* ·
  *"Customize: receiver / your name / message (tap)"*. Present-but-not-forced; subtle
  motion/scroll to catch the eye. **LAYERS with** (not replaces) the optional showcase + Settings.
  Build v1, iterate in situ.
- **HINT/HELPER LEGIBILITY** (this-tab + verify): larger font + scrolling + stand-out, applied to
  **BOTH** the new hint bar **AND** the existing animation hints **AND** the too-small location
  helper text (one consistent treatment). **Verify where the existing animation hints live**
  (this-tab if plain UI, animation-tab if embedded).
- **RANDOMIZE SHOWCASE VARIETY** (design, animation-adjacent): cycle the instrument shown on the
  demo/showcase so a new user sees variety (show-don't-tell). Real-use variety is organic (each
  sender picks their instrument).
- **FIRST-USE DISCOVERABILITY** (largely answered by the hint bar): a tutorial-free new user
  doesn't know they can choose an instrument / how / how to edit per-message — the **hint bar is
  the in-context layer**; friction-free ≠ no guidance.
- **"MINI CARD" voice** (copy direction): consider *"someone sent you a mini card"* instead of
  *"thought"* (feels more distinct from a text). **PRODUCT-WIDE copy decision** — apply to NEW
  copy now, decide the full **thought→mini-card** rename in a focused copy pass later (**NOT a
  blanket find-replace**). May be a mix (mini-card noun vs. send verb).
- **APPLE "MY CARD" auto-fill** (considered → **probably NO**): iOS My Card has name+address, but
  reading it needs **full Contacts permission** (heavy), the API is finicky, and Contacts-for-name
  was already ruled out as invasive. Not worth the friction vs. Apple-sign-in-name + typed/current
  location. Possibly a low-priority optional *"use my contact card"* button later.

**═══ PRESERVED FOR REUSE (do NOT delete) ═══**
- **SHOWCASE:** the instrument-showcase carousel (was `instrumentsScreen` / "three ways to
  connect": `InstrumentPreview` carousel + Connector/Expresser/Special-Moments copy +
  `cycleInstruments`) is kept **DORMANT (`#if false`)** in `OnboardingView` — **NOT deleted.**
  Reuse later for the **optional showcase Yes/No**, the **Settings "How to Use / Features"**,
  and/or **randomize-variety**. The `InstrumentPreview` component is shared/live.
- **proScreen (paywall) / givingScreen (charity)** — dormant `#if false` (post-launch relocation).

**═══ DEFERRED / OPEN WORK ═══**
- **2c COMPOSE-BACK ANIMATION ROUTING:** compose-back showed the **RECEIPT** instead of the
  send-out. Trace found compose-back triggers **NO** animation (lands on compass → normal send →
  send-out); **likely a HISTORY-REPLAY** of the just-arrived `caughtHistory` item, **not a
  send-path bug.** **NEEDS A DEVICE-REPRO** (note exactly which tap played the receipt — a send tap
  vs a history-replay tap) to localize. Near the **PATH-1 backbone** — own scoped, device-verified
  pass. _(Self-gated to STOP this session — `reports/build10_fixbatch_build.md`.)_
- **LOCATION not done:** (a) verify/wire the **"use current location"** one-time-grab (Shot 3a
  only relabeled — may still be just skip/type); (b) helper-text legibility; (c) Phase-3
  live-location on-ramp.
- **SHOWCASE "Yes/No":** design the optional *"want a quick how-to? Yes/No"* (now that the showcase
  is out of the forced flow) — uses the **preserved dormant showcase.**
- **SETTINGS "How to Use / Features / About":** build the **education home** (offered-not-forced).
- **HINT BAR v1 build** (this-tab); **hint/helper legibility pass.**
- **"thought → mini card" focused copy pass.**
- **PAIRING-CODE-GEN RETIREMENT:** still its **own audit-first task** (`myPairingCode` mint +
  Settings see/share + connections plumbing); area surprised us twice in 9b.
- **ANIMATION-TAB** (Joshua, later/parallel, **not blocking**): the missing **incoming build-up**
  (plane fly-in → parachute → open) on arrivals — may relate to the **#12 Plane-v1-not-v2
  regression**; full-send+receipt-both-roles + receiver replay; randomize-showcase-variety.

**═══ DEFERRED TESTING ═══**
- Real **2-phone send/receive round-trip** (needs a 2nd phone); fresh-arriver bypass eyeballed in
  a truly not-onboarded state (verified in code at Shot 2 Step 1); unread-badge visual clear.


_(archived 2026-06-23 — from "⭐ SESSION 2026-06-22 — TESTFLIGHT LIVE · DOMAIN FIXED · RECE")_
### ⭐ SESSION 2026-06-22 — TESTFLIGHT LIVE · DOMAIN FIXED · RECEIVE/PUSH FIXES · CANON

**A · TESTFLIGHT / FUNNEL — WORKING ✅.** External testing was broken because **Build 5 was
distributed "TestFlight (internal only)"**, which flags a build internal-only and **bars it from
external groups** (per Apple). **Fix: re-archive via "App Store Connect" distribution → Build 6 is
external-eligible** (no internal-only marker); it **passed external Beta App Review and is
APPROVED.** **Public link LIVE: `https://testflight.apple.com/join/rjAS4cnk`** (open to anyone) —
this is what the web funnel points to. **Web funnel verified end to end on device** (web page →
install → TestFlight). **DISTRIBUTION LESSON: always distribute as "App Store Connect," NEVER
"TestFlight internal only."**

**B · DOMAIN / DNS — RESOLVED.** pointward.app went down via an **ICANN contact-verification
lapse** → registrar auto-changed the nameservers → site stopped resolving. **Resolved:**
verification completed, Namecheap reverted the nameservers, DNS propagated, site serves again
(HTTP 200). **LESSON: watch for ICANN verification emails; a lapse auto-breaks DNS.** (See
Infrastructure / Gotchas.)

**C · WEBSITE REPO — CANON.** The LIVE website is the SEPARATE repo **`jdcoding75/pointward-website`**
(GitHub Pages → pointward.app). The old `HomeLink/website/` was a **DEAD duplicate** and has been
**DELETED this session.** **Website lives in pointward-website, NOT HomeLink.**

**D · RECEIVE / PUSH — DIAGNOSED + FIXED (the big one).** A read-only audit
(`reports/receive_audit.md`) established: **WARM receive (app open) works** (realtime); **closed-app
receive is APNs-push only and ONLY for PATH-1 (direct pings) — NOT implemented for PATH-2
(link/messages, which is link-tap only)**; **distribution type does NOT change receive code** (only
the APNs environment matters — TestFlight = production APNs). **ROOT CAUSE of "thoughts don't
arrive": `device_tokens` accumulated STALE tokens** (one user: **56, of which 53 dead /
410-Unregistered**) that were never pruned; live tokens still delivered, but the dead pile created
noise and the fresh-install token timing caused the "first reply missed." **FIXES SHIPPED:**
- **Edge function `send-ping-notification` now SELF-PRUNES** tokens on APNs **410/400** (final
  status after the prod↔sandbox fallback; sandbox-only tokens kept). **Deployed.** _(audit:
  `reports/push_token_prune_audit.md`.)_
- **One-time SQL purge run** → device_tokens down to the live few per user.
- **App fix `b21d1db`:** `DeviceTokenRow` now **bumps `updated_at` on every upsert** (ISO8601
  timestamptz, the codebase's existing pattern) so the **60-day cleanup sweeps work correctly**.
- **Cold-receive fix `435eb4f`:** a pending `/m/` link captured during onboarding now **replays
  after onboarding completes** (was stranded until a manual re-tap); plus a **stronger "✓ sent to
  [Name]" send confirmation** (PATH-1 + PATH-2). _(audit: `reports/receive_audit.md`.)_

**E · MONETIZATION — v1 SHIPS 100% FREE (no payment of any kind).** **DECISION (SUPERSEDES all
earlier pricing framing — both "free = compass+emojis / locked = rest" AND the optional "buy me a
coffee" idea):** v1 ships with **NO paywall and NO payment** — no IAP, no tip jar, no commercial
setup; **ALL animations/instruments FREE.** Rationale: any paid item needs the full commercial setup
(Paid Apps Agreement, banking/tax, IAP), not worth it for v1. Near-term: a small **"unlock everything
/ disable the live paywall"** app change (`PaywallView` is LIVE in Release, only `#if DEBUG`-suppressed
in dev) **AFTER** the receive/push test. **Revisit payment ONLY on real traction** — watch **App Store
Connect Analytics** (free, no SDK) for **active/retained users (not downloads); ~1,000+ active** is the
rough bar to even consider it. **SUPERSEDES the tester-unlock** (everything free → no special unlock;
`reports/tester_unlock_spec.md` marked superseded-for-v1). (See LAUNCH / MONETIZATION.)

**F · TESTING MODEL.** **INTERNAL TestFlight (John + wife) = instant builds, NO review — the
everyday loop.** **EXTERNAL/public link = one-time first-build review (done); later external builds
are light.** **Full App Store review only at public launch.** A **TESTER-UNLOCK** (internal testers
see premium unlocked in Release while real users stay gated) is a **PLANNED next build.**

**G · STRATEGY — LOCKED for v1:** ship the current scope as-is; **product pivot/refocus deferred to
post-launch** (brief banked separately).

**H · OPEN BACKLOG (don't lose — pointers, not reproductions):**
- **Receive remainders:** connected-status stamp on PATH-1 receive (overlaps the
  pairedUserID→senderID migration); auto-create on PATH-1 receive; history **full-animation**
  replay (animation-chat); pre-install **deferred deep-linking** (Phase 3). _(all in
  `reports/receive_audit.md`, ranked.)_
- **Compass upgrades (to do):** red marker + haptic tick (Apple-Compass feel); **lock-on-target** so
  you tap-to-launch instead of holding on the target.
- **UX / copy:** send-animation order; "tap to preview" copy; the "see what Pointward is" screen
  (consider hiding for v1).
- **Architecture:** separate the **animation track from app/backend** so parallel work doesn't
  collide in one tree; the **health-audit cleanup roadmap** (Tier-1 dead-code deletes — e.g.
  ProSetupView ~1019 lines, arrival-preview cluster, `UserProfile.code`). _(see
  `reports/health_audit.md`.)_
- **Reports to ground on (don't reproduce):** `reports/health_audit.md`,
  `reports/receive_audit.md`, `reports/push_token_prune_audit.md`,
  `reports/webpage_funnel_audit.md`.

---


_(archived 2026-06-23 — from "⭐ SESSION 2026-06-22 (cont.) — COLD-RECEIVE FINAL DECISION (")_
### ⭐ SESSION 2026-06-22 (cont.) — COLD-RECEIVE FINAL DECISION (clipboard bridge + re-tap fallback)

**COLD-RECEIVE — FINAL v1 DECISION: AUTOMATIC CLIPBOARD BRIDGE + RE-TAP FALLBACK.** _(The actionable
build/test/open ledger lives in **POST-TEST QUEUE** below; this block is the decision + its backing
detail.)_

**THE PRECISE BLOCK (why this was hard):** when a no-app person taps `pointward.app/m/<id>`, the link
opens the WEB PAGE in **Safari's sandbox**. They install from the App Store; the app launches in its
**OWN separate sandbox**. The two sandboxes share nothing, and the App Store install carries no
app-specific data across. So the message id (and anything the web page knew) is **STRANDED IN SAFARI** —
not destroyed, but unreachable by the freshly-installed app. iOS provides **NO built-in channel** to pass
content across that install boundary. The whole problem reduces to ONE question every time: **"how does
the message id get from Safari to the app?"** Confirmed across `dl_hunt_v2` / `code_in_link_hunt` /
`server_pull_feasibility` / `shortcode_carry_hunt`.

**HISTORICAL RECONCILIATION (why it "worked before" but breaks cold now):** every working past version
had the app **ALREADY PRESENT** or the data **ALREADY FED IN** — none ever crossed a true cold install:
1. **PRE-WEB PAIRING ERA:** connection required the app installed on BOTH ends. `/pair/<code>` and
   `/join/<code>` carried the code and auto-connected, but **ONLY app-present** (tapping opened the
   already-installed app). Info passed app-to-app, **never across a cold install**. (Removed `26c59ff` /
   `abc9e77` / `6c7f8c5`; `connections` table dropped. The memory of the carry is **REAL and vindicated
   in git** — it was just app-present, never cold.)
2. **XCODE / SCHEMA-FED TESTING:** builds ran with a message **manually inserted into Supabase** (or fed
   into app state). The message was **ALREADY ON THE APP'S SIDE OF THE BOUNDARY** — the app read
   pre-placed data, pointed at an id **supplied by hand** (tester = sender, knew the id). The cold-install
   boundary was **NEVER EXERCISED** — it was stepped around. **The key source of the "it worked"
   illusion.**
3. **WEB-BUT-APP-INSTALLED TESTING:** tapping a web link on a device that ALREADY had the app → universal
   link handed straight to the app. Again **never a true cold install**.
- **ROOT OF THE ILLUSION:** warm (app present), pairing (app-to-app), and schema-fed (message pre-injected
  past the boundary, id supplied by hand) all bypassed the hard part. "It worked" was always true under
  conditions that avoided the one thing that actually breaks. **NOT a regression, NOT lost work — an
  unbuilt case** that hid because nothing ever tested it.

**SEED / PRE-INSTALLED MESSAGE — CONSIDERED AND REJECTED:** bundling a "junk" message in the app (like the
Xcode schema-fed one) **fails** — a bundled message is identical for every install (baked in at BUILD
time, before any user tapped any link), so it **cannot carry the PER-USER message id** (e.g. `abc123`)
needed to query/attach the missed message. The seed gives the app A message but not the RIGHT id. The
Xcode trick worked only because the tester supplied the id by hand; production has no one to supply it.
The real problem is always **"get the id from Safari to the app,"** which a pre-baked message can't do.

**THE ONLY FOUR CHANNELS across the sandbox gap** (all others impossible): (1) **clipboard**, (2) server
**device-fingerprint match** (fuzzy/probabilistic), (3) **App Clip → App Group handoff** (heavy build),
(4) **re-tap** the link after install (app now present → universal link works). Server-pull is impossible
(messages have **no recipient field**). Pairing restore doesn't help (was app-present).

**DECISION: AUTOMATIC CLIPBOARD BRIDGE, with RE-TAP as a natural fallback.**
- **PRIMARY (automatic, no user effort, NOT manual copy-paste):** the web page **writes the message id to
  the system clipboard on the "Get Pointward" tap** (silent, on the user gesture). The app, on first
  launch, uses **`UIPasteboard.detectPatterns`** (silent presence check — only prompts if a relevant URL
  is actually present, so a direct installer with nothing relevant is **NEVER prompted**), then reads →
  feeds the existing **`PendingLink`** → the existing flow plays the thought in-app with full animation.
  The user copies/pastes nothing; the only user-facing cost is **ONE framed "tap to open your thought"
  permission moment, shown only to people who actually have a thought waiting.**
- **FALLBACK (automatic safety net, NO special build):** if the clipboard read misses (user copied
  something else, long delay, Universal Clipboard to another device), the original `/m/<id>` link is
  **STILL in their messages and the app is now installed** → re-tapping opens straight into the app and
  plays the thought. Natural "I didn't see it, tap again" recovery. **Every failure mode degrades to
  today's behavior — never worse, never a wrong message.**
- **REJECTED:** clipboard was INITIALLY rejected on a **misunderstanding** (thought it meant manual
  copy-paste); clarified — it's **automatic, one framed tap**. **App Clip** (too heavy for v1; revisit
  only if cold-conversion data demands fully-automatic no-tap). **Typed short-code** (friction).
  **Pure-web-only** (web teaser too weak alone — the animation is THE value, lives in the app). **Seed
  message** (can't carry the per-user id; see above).
- **Supersedes the earlier "Bridge 1 re-tap as primary" framing** (which was discussed but never
  committed to canon): re-tap is now the **FALLBACK** under the clipboard primary, not the main path. The
  separate **"first-launch re-tap prompt" build item is CUT** (clipboard is more automatic). The
  **notification-deferral fix is downgraded** from load-bearing to **OPTIONAL polish**.

**TEST-LOOP CAVEAT (locked):** TestFlight (internal OR external) **cannot faithfully reproduce the true
cold path**; clipboard hit-rate is **high-but-not-100%** (degrades to the re-tap fallback); **real cold
validation is post-launch on the live App Store**, with a fix path ready. **V1 build order + test queue +
open items live in POST-TEST QUEUE below.**


_(archived 2026-06-23 — from "⭐ SESSION 2026-06-23 (cont.) — ORIGINAL MISSION COMPLETE (PA")_
### ⭐ SESSION 2026-06-23 (cont.) — ORIGINAL MISSION COMPLETE (PASS 2 + cold path) · CONNECTION FIX LIVE · BACKLOG RE-CLUSTERED (pairing = release gate)

**✅ ORIGINAL MISSION — COMPLETE THIS SESSION:**
- **PASS 2 / 5T (closed-app push — the ORIGINAL root-cause gate, NEVER RUN before) → DONE.** Recipient
  phone **fully closed** on TestFlight **Build 7 (production APNs)** → direct ping → push **WOKE the app,
  thought played. STALE-TOKEN ROOT CAUSE CLOSED.**
- **TRUE COLD CLIPBOARD PATH → VALIDATED.** Genuine cold test (fresh device, no app → web `/m/` link →
  "Get Pointward" clipboard write → install **Build 8** → open → **"Allow Paste" fired** → thought
  surfaced). Cold-receive funnel works **end-to-end** (modulo App-Store-vs-TestFlight install source,
  which doesn't affect the clipboard handoff).
- **OPEN ITEM #7 (sender not notified of connection) → ROOT-CAUSED + FIXED + VERIFIED (`256e854`).**
  `link_connections` persists + the sender can read it, but `stampConnections` required a local `SentLink`
  (wiped by reinstall) → the row was silently dropped. Fix: `stampConnections` async + server-data
  fallback (`fetchPublicProfile` → `upsertContact(makeActive:false)` when `SentLink` absent). **Verified
  live** (persisted connection surfaced the contact, active person unchanged).
- **Shipped + pushed this session:** clipboard bridge (web+app), prompt-deferral (`d9e0fe1`),
  unlock-everything / v1-free (`87d9aa8`), A2 send-stage-on-receive (`55b1380`, **LINK path only**),
  landing bypass (`0a886bd`, onboarded skip the 3-door).

**✅ CLOSED / RESOLVED:** **#10 "Alex Demo disappears" / don't-seed-Alex → RESOLVED** — now **"Demo Dan",
persists correctly.** Removed from open bugs (struck in REMAINING BUGS).

**↓ BACKLOG RE-CLUSTERED:** the live priority view is now **## WORK CLUSTERS (prioritized)** below
(**PAIRING = the one release-gating cluster**; everything else iterative/non-blocking). The historical
**POST-TEST QUEUE** is reconciled (5T DONE, #7 FIXED, builds #1–3 DONE) and kept for record.

**STATUS / OPS:**
- **Build 8 uploaded to TestFlight (internal).** ⚠️ **OPEN: confirm whether Build 8 includes A2** — son's
  receive showed **receipt-only** → either Build 8 predates A2 (`55b1380`) OR it's the ping-path gap
  (A2 is LINK-only). **Confirm which commit Build 8 was archived from.**
- **Son (Joshua) added as internal tester** (role: Customer Support → Developer to qualify).
- **Supabase two-login** stands (GitHub **jdcoding** owns the project; wrong account = "no access"; TOS
  interstitial + slowness — resolved).
- **Test data tangled** (Bob/Joshua duplicates) — caused BY the Priority-1 pairing gaps; **fixing Priority 1
  cleans testing too.**

---


_(archived 2026-06-23 — from "POST-TEST QUEUE (current priorities)")_
## POST-TEST QUEUE (current priorities)

_⚠️ SUPERSEDED as the live priority view by **## WORK CLUSTERS (prioritized)** above — see there for the
current ordering (pairing = release gate). Statuses below are reconciled to 2026-06-23 and kept for record._

_This two-phone test pass surfaced multiple items; this is the full ledger + order of work.
**Immediate order: B (write this queue) → A (BUILD #1) → PASS 2 (TEST #5T).**_

### BUILD QUEUE — code to write
_(single-writer · ONE repo per run · propose-diff-before-write)_
1. **[✅ DONE 2026-06-23] WEBSITE (`pointward-website`): clipboard-write** — on the "Get Pointward" tap, silently write
   the message id (e.g. `https://pointward.app/m/<id>`) to the system clipboard, on the user gesture,
   **best-effort (`.catch` no-op)**. Smallest, independent, **verifiable in a browser alone**. Ship +
   verify before #2. (**`git pull` first** — local was behind origin.)
2. **[✅ DONE 2026-06-23] APP (HomeLink): clipboard-read** — on first launch, `UIPasteboard.detectPatterns` (silent presence
   check; only proceed/prompt if a relevant URL is present) → read → parse via `MessageLink.messageID` →
   `PendingLink.shared.set(id)` → existing `presentPendingMessageIfReady` flow plays the thought.
   **One-time guard** (a `UserDefaults` flag) so the clipboard is **never read again**. **NO downstream
   changes.** Only after #1 is live.
3. **[✅ DONE 2026-06-23 · `87d9aa8`] APP: unlock-everything / disable-paywall** (the Build-8 change — v1 ships 100% free).
4. **APP: receive-path regression harness** — warm + cold-launch-via-link sim tests; unit tests
   (`MessageLink.messageID` parse, once-only clipboard guard, `finishSend` name logic); **+ a LABELED
   manual checklist** for un-simulatable cases (true cold install, real APNs to a closed app, web `/m/`
   on device).
5. **WEBSITE: teaser animation clips** on the `/m/` page (sells the install). **BLOCKED** on the owner
   first **re-adding `AnimationTestLabView`'s DEBUG entry point**, then **screen-recording** clips (**0%
   reusable media exists** — all SwiftUI; must record from a DEBUG build via Simulator **File ▸ Record
   Screen**, per `reports/onboarding_asset_inventory.md`). Separable; do when ready.

### TEST QUEUE — verification owed
_(real-device runs, NOT builds · internal-tester or direct Xcode install — skip Apple review)_
- **5T. [✅ DONE — PASSED 2026-06-23] PASS 2 — CLOSED-APP PUSH** — VERIFIED on TestFlight **Build 7
  (production APNs)**: phone fully closed (swipe-killed) → direct ping → push **woke the app, thought
  played. STALE-TOKEN ROOT CAUSE CLOSED.** (Original spec preserved below.) — the **ORIGINAL root-cause gate, NEVER RUN
  this session** (the test pass diverted into cold-receive before this happened). Verify: after the
  `device_tokens` prune + edge-function dead-token self-pruning (`b21d1db` + `send-ping-notification`),
  a **DIRECT PING wakes a TRULY CLOSED app via APNs**. This was the explicit **reopen-condition** for the
  stale-token root cause. Phone fully closed (swipe-killed) → send a direct ping → confirm it arrives.
  **If it does NOT → reopen the root-cause issue.**
- **6T. PASS 1 — CLEAN HAPPY-PATH FUNNEL** — send → receive on **CLEAN state** (after clipboard is in),
  confirming the funnel end-to-end **without the dirty-state confounds** of the first run.

### OPEN ITEMS — investigate READ-ONLY before any fix (do not assume bug)
7. **[✅ RESOLVED 2026-06-23 · `256e854`] Sender not notified of connection after a cold recipient received** — root-caused (candidate (1)/(3)): the `link_connections` row IS written + readable, but `stampConnections` dropped it when the local `SentLink` was missing → now falls back to the server profile (`fetchPublicProfile` → `upsertContact(makeActive:false)`); VERIFIED LIVE. _(Original investigation preserved below.)_ (two-phone test). **NOT the
   cold-install gap; clipboard will NOT fix it.** Three candidate causes: (1) **EXPECTED** — sender-side
   connection display is unbuilt backlog **#3/#4**; (2) **NEVER WRITTEN** — `record_connection` is
   **auth-only**, fires when the recipient opens **IN THE APP**; if the recipient opened on web/pre-auth,
   no link was recorded → nothing to notify; (3) **WRITTEN BUT NOT PROPAGATED** — a `link_connections`
   row exists but the sender's `fetchMyConnections`/sync didn't surface it. Audit the chain (recipient
   receive → `record_connection` → `link_connections` → sender `fetchMyConnections`) to determine which,
   **THEN** fix.

### KNOWN GAPS / NON-BUGS — decide if launch-blocking (none currently believed to be)
8. **Legacy empty-name contact:** Phone A has a pre-existing local `Person` with `name=""` (from an older
   build), causing the **"sent ✦"** fallback instead of **"sent to [Name] ✦"**. Data artifact, not a bug;
   new users won't have it. Decide later: auto-heal empty names on receive, or ignore.
9. **Auto-create / connected-stamp on receive (backlog #3/#4):** **#3 (sender-side connection display) RESOLVED 2026-06-23 (`256e854`); #4 (sync-lag / no realtime) → moved to WORK CLUSTERS PRIORITY 1 (SYNC-LAG).** a sender does NOT auto-appear on the
   recipient's device on receive, and the connection only forms when the recipient sends back. **UNBUILT,
   expected — not a bug.** Build if/when desired; not launch-blocking unless decided otherwise.

### PARKED (post-launch)
Compass v2 (red marker + haptic + lock-on-target, after a Design exploration — **now overlaps WORK CLUSTERS COMPASS INTERACTION: HOLD·LOCK·TAP**); true live per-thought web
animation; App Clips (only if cold-conversion data demands fully-automatic no-tap delivery); health-audit
cleanup (Tier 1: delete `ProSetupView` ~1019 dead lines, etc.); animation/app code separation; **extract the replicated A2 send dispatch into a shared `SendStageView`** (overlaps WORK CLUSTERS animation cluster);
connected-status stamp on PATH-1 receive; history full-animation replay; UX/copy items; **V2 real-time
pointing** (now cheaper — sender location is **real + one-time**; recipient **last-known** location
suffices; **no continuous tracking**; "real last-known," NOT "live broadcast").

---


_(archived 2026-06-23 — full running _Last updated_ log (Q1))_
_Last updated: Session 8 (structural-truth pass) · Phase 2 canon reconciliation — link-based model, scope, senderID, deep-link deferred to P3. · IDENTITY CORRECTION: not forking — the two `users` rows are 2 Apple IDs (Joshua + wife), identity IS stable, hardening deprioritized; banked the display-polish batch (arrival-name, connection-indicator, contact-icon) as active small work. · SESSION CLOSE: Stage A/B/C + display polish all COMMITTED (clean tree, HEAD `90422fd`); banked the CLEAN-RESET PROTOCOL for next session (churn-fogged device state — reset before verifying) + open items (stuck "connected" banner, display clean-verify, old-copy cleanup, double-tap cold-start audit). · CLEAN TWO-PHONE TEST DONE: verified connection/green-indicator/PATH-1-direct/initials clean; RESOLVED the notification model (notify only when connected → named push → tap opens app → plays the arrival; link IS the awareness for unconnected); prioritized next-session list led by **[HIGH] PATH-1 push not firing when app-closed (code gap, not permission)** + **[HIGH] share-text "[John]" copy/name**. · BUG FOLD: re-homed the open bug list under its phases — FINISH 11b/Stage C (#1 push, #2 share-text, #3 envelope name, #15 display-verify), BUILD 9b (#4 forced-send/added-you, #5 legacy connect screen), BUILD 10 (#6 onboarding name-not-persist [root of "Someone"], #7 Settings profile, #9 old-copy cleanup), separate double-tap audit (#8); added **REMAINING BUGS (unphased)** catch-all — animation territory (#12 Plane v1/v2, #13 aiming-order, #14 send-sound) + notes (#10 Alex-demo, #11 first-send warm-up). · PRE-TEST BATCH: **5 fixes BUILT + uncommitted** (#8 double-tap cold-launch, #2 share-text named copy, #3 envelope "from [name]", #4 forced-send-on-add removed, #5 legacy connect screen removed) — all Release+248-green, batched for ONE clean two-phone test before commit; benched push `index.ts` (#1) awaits Joshua redeploy. Banked the obstacle-removal status (stuck "[name] connected" banner = NO live code, likely stale notification) + the 5-step clean test plan (commit the batch only if all pass). · ⭐ SESSION CLOSE — BATCH + PUSH COMMITTED & DEVICE-VERIFIED: app batch `d03eb3e` (5 fixes) + push fn `feafe7a` all passed the clean two-phone test; **PATH-1 push works END-TO-END** (named "John sent you a thought ✦" on a closed phone → tap → arrival played) — the send model's last functional gap is CLOSED (the boot bug meant the function NEVER booted before). NEW findings (all phone-free): #1 PersonDetailView still pairing-driven (load-bearing tap→compose bug), #2 unread count never clears, #3 sender-reinstall re-stamp gap, #4 connection-sync lag, #5 stray `rapid-action` Edge Function (delete), double-tap = iOS Messages behavior (RESOLVED, not a bug). Runway is ALL phone-free: PersonDetailView fix, unread-clear, 9b cleanup, Build 10 + #6, Phase-2 tests. · SESSION CONTINUED: PersonDetailView reconcile (`73cceaa`, senderID-primary isConnected + ungated compose, device-verified) + unread-badge Option A (`7c0f956`, markAllMyPingsOpened on foreground, "marked all opened ✓") both COMMITTED & verified — findings #1+#2 CLOSED. **9b CLEANUP AUDIT DONE** (5-batch removal plan; 2 catches — `connectedFriendID` is LOAD-BEARING/preserve, `claimOutcome`+tests now app-orphaned → Joshua decides retire-vs-keep). Animation (#12/#13/#14) queued-not-started (don't run animation+9b builds together). 9b removals START next session. · ⭐ 9b DEAD-PAIRING CLEANUP COMPLETE: B1 dead views (`abc9e77`) + B2 invite-accept API/DI (`6c7f8c5`) + B3+B5 PeopleManager funcs/tests/isConnected (`9883a60`) + B4 mutual-pointing unwire (`04e80d6`, NotificationHandler thought/PATH-1 branch byte-identical, device-glance passed) all COMMITTED; `rapid-action` stray Edge Function deleted; tests 246→227. The LIVE pairing-code-gen subsystem STAYS (sign-in mints a code via myPairingCode → connections) = separate post-9b item (around/after Build 10). Surfaced: arrival-preview mystery prompt, history-replay-should-be-full-animation, trailing leftovers. **LINK-ERA PIVOT SUBSTANTIALLY COMPLETE.** NEXT: Build 10 (onboarding + #6 name-persist). · ⭐ BUILD 10 DECISIONS LOCKED (Joshua, pre-build): governing principle = **friction-free for most + require info only WHEN IT'S USED** (path-split is a consequence, not a rule). NAME required at the **send-moment** (sender has one → satisfies #6; receiver not asked) + self-explaining copy + Apple pre-fill (never relied on; flow GUARANTEES display_name) + edit-per-message; no Contacts-for-name. LOCATION **don't force it** (felt-directionality not a receiver requirement now; Phase-3 live location makes manual moot → keep light). EDUCATION/showcase lives in **Settings**, OFFERED not forced (after first receive, or optional onboard screen). STILL OPEN: patch-vs-rebuild the paged TabView; 3-doors rendering; drop the sign-in myPairingCode mint. (Audit: `reports/build10_onboarding_audit.md`.) · ⭐ BUILD 10 DESIGN SESSION (decisions + REASONING banked): governing principle now = friction-free + require-when-used + TUTORIAL-AS-SETUP (refinement: honest upfront ask when no clear use-moment, e.g. notifications). Locked: NAME at send-moment (Apple .fullName pre-fill is trivial — already requested, just discarded), LOCATION 3-option (skip/type/use-current; "use current" = the Phase-3 on-ramp; sends carry NO location confirmed), SIGN-IN-FIRST for fresh installer (commitment momentum), unified first-open showcase (Demo Dan; link-arriver message-first then showcase-as-tap), education in Settings, notifications upfront, add-person Contacts-autofill (has-address → skip location), graceful exit safe (name lives at send), RETIRE the pairing code (half-dead/unredeemable → stop showing; full retirement = own audit-first task around B10), PATCH-not-rebuild trending. Prep-audit findings banked (no location in sends, mystery-prompt=arrival-preview [closed], no history delete, screen inventory reuse/relocate/delete). STILL OPEN: the link-arriver send-back path (last design piece) + patch-vs-rebuild. · ⭐ LINK-ARRIVER PATH DESIGNED (structure locked, copy placeholder): tap → real message plays (no gate) → landing 3-doors ("send one back to [Name]" / "see what Pointward is" / "I'm good for now"); send-one-back composes straight back (no signup wall) capturing name (#6 lands here) + location via **FILL LADDERS** that READ stored records VIA THE LINK (confirm-don't-enter), NOT from the send (send stays lightweight). Verify-in-build: records store location + link grants read-access to a connected user's fields (RLS). Mindset: build CORE/structural now, copy/look/feel = iterative POLISH ROUNDS near publish. Design session COMPLETE; only patch-vs-rebuild remains (resolves at build-scope). · ⭐ BUILD 10 BUILT + PHONE-WALKED (single-phone cursory): Shots 1/2/3a + landing + minor cleanup + the 5-fix batch all COMMITTED (HEAD `b10190f`); patch-vs-rebuild RESOLVED to **PATCH** (paged TabView trimmed in place). Onboarding now **sign-in → about-you (finishes)** — showcase OUT of the forced flow (deferred to an optional Yes/No; the marketing/showcase carousel kept DORMANT `#if false` for reuse). Link-arriver path works end-to-end cursory (3 doors, bypass + compose-back + fill-via-link). DECISIONS banked: name-step copy "How should your name appear to [Name]?", Home Location "(optional but recommended)", "Message from [Name]" on arrivals, **FULL SEND+RECEIPT FOR BOTH ROLES** (animation-track, +receiver replay), **HINT BAR** (in-context discoverability), hint/helper legibility, randomize-showcase-variety, **"mini card" voice** (product-wide copy, focused pass later — NOT blanket replace), Apple "My Card" auto-fill considered→probably-NO. DEFERRED: **2c compose-back routing** (RECEIPT-not-send-out — likely history-replay, needs device-repro; near PATH-1 backbone), location wiring (use-current/legibility/Phase-3), showcase Yes/No, Settings education home, hint-bar v1, copy pass, **pairing-code-gen retirement** (own audit-first), animation-tab (incoming build-up / #12 Plane-v1-v2). DEFERRED TESTING: real 2-phone round-trip. (Findings: `reports/build10_walkthrough_findings.md`.) · ⭐ PAIRING-CODE RETIREMENT COMPLETE (end-to-end, server + code): the whole subsystem removed across steps 2–8 (mint/screens/share/redeem, connectedFriendID + plumbing, refreshConnection(s), DiscoveredConnection, cosmetic presence, mint internals + ~8 tests, the `connections`-table code refs) — table dropped server-side; LINK (link_connections/senderID/short_code//m/) is the sole connection model; gecko/active-person/PATH-1 untouched (214 tests). · ⭐ DEPLOYMENT TARGET LOWERED 26.5 → **17.0** (`4093623`): app installs on shipped iPhones now; iOS-26-only geocoding `@available`-guarded with a CLGeocoder fallback (same GeocodedLocation shape, callers unchanged); 16.0 blocked by the widget's iOS-17 WidgetKit use. App Store toolchain ✅ (Xcode 26.5 / iOS-26 SDK / Tahoe 26.5.1). · ⭐ STRUCTURAL CLEANUP MAP banked (post-TestFlight ranked plan — dead-code → SupabaseService split → dedup → CompassView extraction → pairedUserID migration; the containment work that unlocks parallel builds; see new section at file end + `reports/structural_map.md`). · ⭐ PHASE 2 — ANIMATION-TRACK SESSIONS COMPLETE (`09ba2f5`…`c38ca9d` + interim `9ab3f6e`): bottom-band redesign (4-box picker, default-emoji framework, no send button) → R1/R2 polish (plane aim-hint compass-only, dots removed, recipe moved up, custom-text lock; duplicate sender-reveal suppressed) → Batch-1 (default emoji reaches all 7 face gates incl. wind/wand sensor-start-on-appear; per-animation defaults; compass explicit lock→tap send) → wind self-fire fix → ROOT-2 (plane+flick promoted to live V2 dispatch; wand deferred) → latch fix → Special Moments Stages 1+2 (Birthday/Firework now peer Instrument+SenderStyle cases, selectable cards). See the **"Phase 2 — Animation Track (canonical commit ledger)"** + **"PHASE 3 — DEFERRED WORK"** sections at file end, and `reports/phase3_handoff.md`. · ⭐ SPECIAL MOMENTS STAGE 3 COMPLETE (`624b044`, HEAD): `ReceiptView` recipient dispatch re-keyed to `style == .birthday/.firework` (emoji fallback kept for Stage 4); Birthday default flipped back 🎂 → **🎁**. Peer architecture now COMPLETE end-to-end (Stages 1+2+3); only Stage 4 (retire emoji fallbacks, post fleet-adoption) remains. _(reports/special_moments_stage3_build.md)_ · ⭐ PRE-RELEASE FIXES BATCH (`380d374` → `e3438a5`): firework/birthday FREEZE fix (finishSend rebuilds the face via instrumentResetID — approach B, no animation-face edit; re-arm CONFIRMED on device) · rocket receipt FIRST-DROP split into slow easeIn entry + kept settle (`entryDropDuration` knob; accepted "good enough") · removed the dead "show arrival preview" setting (CONFIRMED) · removed the dead/mislabeled "thoughts" notification toggle (gated the retired notify_pointing; app now has ZERO user-facing notification controls — post-launch relabel option) · bucket per-item DELETE on the replay overlay + `removeFromHistory(id:)` (⭐ reusable Phase-3 backbone; delete-only, NO save/preserve) · replay overlay UX rework (`e3438a5`): auto+swipe → explicit PREV·NEXT·CLOSE·DELETE buttons (no auto-exit; reveal keyed on `cur.id` so delete-advance re-fires; PersonDetail unaffected; known cosmetic — inert "tap to keep ✦" hint). Device-test PENDING: thoughts-toggle removal + bucket-delete + replay rework. See the animation-track ledger + PHASE 3 — DEFERRED WORK at file end + `reports/phase3_handoff.md`. · ⭐ COMPOSE-UNIFORMITY STEP 1 (`277b457`): per-instrument `defaultMessage`/`defaultTagline` added to AnimationManifest + wired into the compose seed (PREFER instrument default, FALL BACK to per-emoji `CuratedEmoji.defaultMessage`); ONLY Birthday → "Happy Birthday" (others nil = no regression); `defaultTagline` UNWIRED (tagline rides from the person); receipt style-keyed/unchanged. Full uniformity is now pure DATA-ENTRY (populate per-instrument defaults + retire the per-emoji fallback — no new plumbing). Device-test PENDING. INTERLEAVED (Phase-2/pairing track — ladder-ack only, not animation work): `684eabc` "prelaunch fix batch" + `7ac50bc` keep-Demo-Dan/switcher-tap; **`7ac50bc` is current HEAD** (`277b457` sits just below it). _(reports/birthday_default_message_build.md · reports/truth_full_reconcile.md)._ · ⭐ SESSION 2026-06-22 — **TESTFLIGHT EXTERNAL LIVE** + public link `…/join/rjAS4cnk` (root cause = Build 5 distributed "internal-only"; fix = distribute via **App Store Connect** → Build 6 approved). **WEB FUNNEL verified end-to-end on device.** **DOMAIN restored** after an ICANN-contact-verification lapse auto-broke DNS (watch ICANN emails). **WEBSITE canon = the separate `pointward-website` repo; HomeLink/website/ husk DELETED.** **RECEIVE/PUSH diagnosed + fixed:** stale `device_tokens` (one user 56 / 53 dead-410) → edge-fn **self-prune on 410/400** (deployed) + **`updated_at`-bump** (`b21d1db`) + **cold-receive pending-link replay after onboarding** + **"✓ sent to [Name]"** (`435eb4f`); closed-app receive = APNs/PATH-1 only (PATH-2 = link-tap). **PAYWALL is LIVE in Release** (DEBUG-suppressed only) — v1 model FREE compass+emojis / LOCKED other instruments; **commercial setup later; tester-unlock PLANNED** [SUPERSEDED — see MONETIZATION REVISED at end]. **TESTING:** internal = no-review everyday loop, external = one-time review done. **STRATEGY LOCKED for v1** (pivot post-launch). Backlog banked (compass red-marker+haptic+lock-on-target; animation-track separation; health-audit Tier-1 deletes). See the **2026-06-22 session block** + `reports/{receive_audit,push_token_prune_audit,health_audit,webpage_funnel_audit}.md`. · ⭐ MONETIZATION FINAL (2026-06-22) — **v1 SHIPS 100% FREE: NO paywall, NO payment of any kind** (no IAP, no "buy me a coffee," no commercial setup) — supersedes BOTH the "free=compass / locked=rest" note above AND the earlier same-day coffee-support framing. Rationale: any paid item needs full commercial setup, not worth it for v1. Near-term: small **"unlock everything / disable the live paywall"** app change AFTER the receive/push test. **Revisit payment ONLY on real traction** — App Store Connect Analytics (free, no SDK) for **active/retained users, not downloads; ~1,000+ active** = the rough bar. **SUPERSEDES the tester-unlock** (everything free → no unlock needed; `reports/tester_unlock_spec.md` superseded-for-v1). · ⭐ **POST-TEST QUEUE added** (current priorities — build/test/open/gaps/parked ledger) **+ COLD-RECEIVE FINAL DECISION** (automatic clipboard bridge + re-tap fallback; the id is stranded in Safari's sandbox across a cold install → web writes the id to the clipboard on the Get-Pointward tap → app first-launch `detectPatterns`-gated read → `PendingLink` → full in-app animation; re-tap is the fallback). Immediate order: B (queue) → A (build #1 website clipboard-write) → PASS 2 (test #5T closed-app push — the original root-cause gate, never run). **See the "POST-TEST QUEUE (current priorities)" + "COLD-RECEIVE FINAL DECISION" sections** (just before the PRODUCT DIRECTION DUMP). · ⭐ SESSION 2026-06-23 (cont.) — **ORIGINAL MISSION COMPLETE** (PASS 2 closed-app push PASSED on Build 7 production APNs → stale-token CLOSED; true cold clipboard path validated end-to-end; #7 connection-display ROOT-CAUSED+FIXED+VERIFIED `256e854`). Backlog RE-CLUSTERED → new **## WORK CLUSTERS**: **PAIRING = release gate** (contact reconciliation RULE 1 one-contact-per-user-id + delete-disconnect RULE 2 new RPC 1-way-vs-bilateral + sync-lag #4); iterative/non-blocking = animation-correctness, screens-reduction, compass HOLD·LOCK·TAP, contact model (emoji/photo), pre-launch polish, free-for-now messaging. New **## FUTURE/POST-V1** animation tier framing (free passive-send/catch-bucket vs paid interactive-receipt; web=on-ramp, app=moat). #10 Alex→Demo-Dan RESOLVED. Build 8 internal (A2-inclusion TBD). See the **2026-06-23 (cont.) session block + WORK CLUSTERS**. · ⭐ PAIRING CLUSTER DESIGNED + DECIDED (2026-06-23): **ONE CONTACT PER USER ID** (senderID sticks; incoming ID auto-attaches, never double-creates; server name never overwrites user name; "let it live, user cleans up" — **NO auto-merge/merge-tool/name-matching**, supersedes the earlier WARN-merge sketch). P1 = visibility-only (same-id annotation + "(2)" display-suffix, never written to Person/messages); **P2 delete-disconnect = Option A one-directional DECIDED** (RLS delete-own + client delete; bilateral PARKED) — the linchpin that makes cleanup stick; **P3 sync-lag = BUILD FIRST** (piggyback the "pointward" realtime channel, no SQL). Build order P3→P2→P1. Contact-flow: **Contacts-pick PREFERRED** (firm name/address/channel; auto-addressed first send; stores send-channel = PREVENTION). `reports/pairing_completion_plan.md`._
_Updated this session: Phase 2 progress + findings pass — builds 1–4b shipped & verified, per-person history-bucket finding (coupled to build 9), re-sequenced build order 5–11, onboarding + infrastructure notes banked._
_Findings pass 2: builds 5–6 + display-name/shortCode fix DONE & device-verified; sharpened the build-9 bucket finding (pings-table vs messages-table seam); banked hint legibility, Sarah dev-seed, duplicate-users, onboarding-emoji, share-sheet, and send-sound-distortion notes._
_Session lock-up: builds 5–9 (safe half) shipped & ledgered; CRITICAL link-send-`#if DEBUG` / delivery-backbone finding banked; bucket finding RESOLVED (sender-agnostic, local); 3 locked bucket decisions; back-half re-sequenced (11b cutover → 9b delivery-retire → 10 onboarding → 11 tests → 12 web → cleanup); build-9 left-intentionally flags + findings-pass-3 notes. CLAUDE.md: standing build patterns added._
_Build 12 reframed: SHOW-THE-MESSAGE static web page (fetch+display via getMessage(id), no animation) pulled to pre-launch; the animated-in-browser version stays Phase 3._
_Build 12 wording refreshed: contained / Claude-buildable static page (Joshua has no HTML experience); animated browser version remains Phase 3._
_SEND MODEL LOCKED: two-path send (connected → DIRECT, re-keyed pairedUserID→senderID, channel NOT retired; not-connected → "open in Pointward" universal LINK; cases 2+3 collapse; cold-start light fill-in; no double-send). 11b reframed to "implement the two-path send"; 9b reframed to retire dead pairing plumbing ONLY (PATH-1 channel survives). Build 12 CTA locked to "open in Pointward — free."_
_COMPREHENSIVE LOCK-DOWN (back-half design fully resolved): IDENTIFIER BACKBONE framing; CONNECTION-SIGNAL build spec (the gap, two new local stores S1/S2, `link_connections` migration + `record_connection` RPC, 10 cases, 4 resolved decisions, auth-timing correct-by-design) STAGED A→B→C with the family-test gate AFTER C; ONBOARDING/ARRIVAL north-star (message-first, 3 doors, showcase/paywall out of the gate, just-in-time identity); WEB PAGE locked design + canonical pitch + 3-tier animation ladder; PATH-1 push / ~30-day lifespan + save/delete / growth; standing prioritization principle; parked/deferred consolidated._
_Build 12 web page BUILT · DEPLOYED · LIVE-TESTED (pointward-website `2d319d4`, 404.html path-style, anon `get_message`, DARK-PURPLE brand superseding "warm cream", shipped copy, does NOT mark_opened, install button = **LIVE public TestFlight link `…/join/rjAS4cnk`** (was a placeholder; wired + funnel verified on device 2026-06-22); two invite surfaces locked). Stage B build-spec LOCKED (`reports/stage_b_buildspec.md`)._
_Onboarding walk-through banked (Build 10 North-Star): DROP the pairing-code screen (absorbed; loopFlick-guard caution); NAME PRE-FILL LOCKED (recipient's fill-in pre-filled with the sender's label for them, warm + editable, no "is this you?"); ADDRESS/LOCATION at onboarding FOR CONSIDERATION (need-at-all / Apple-home-autofill / as-is — resolve "what is it for?" + address-vs-rough-location first)._
_PRODUCT DIRECTION DUMP banked (future work, decided-vs-for-thought): APP CONCEPT/positioning (primary=emotional-connection via intent+meaning; secondary=anti-card-app); HELP/FAQ/HOW-TO + About (Settings-top, optional, the explorable home for the onboarding showcase); SETTINGS-tab review project (+ planned: Help, "turn off send-actions" advanced toggle [check-if-exists], structured feedback picker, "catch in bucket" toggle default-OFF); OCCASION notifications (parked); LAUNCH/MONETIZATION (seed-free-then-monetize principle endorsed; founding-cohort + propagating-free-Pro direction; specifics open for a dedicated session)._
_STAGE B VERIFIED end-to-end (two-phone test, 2 real Apple IDs → link_connections row formed — the back-channel is PROVEN). Findings banked: arrival shows "Someone" not sender_display_name (BUG) + recipient-local-name enhancement; Plane v1-not-v2 wrong-animation regression (careful audit-first, future); connection-status indicator (driven by senderID, pairs with Stage C); don't-seed-Alex-into-People; remove "[John] added you" notification (pairing-era); widget surface + Phase-3 live-location payoff; address-on-add PARKED + contacts-permission RESOLVED (ask only on pick-from-contacts) + send-channel fork (open); MANUAL PAIRING RESOLVED — do NOT re-add (re-tappable link is the fallback)._
