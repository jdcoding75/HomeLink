# POINTWARD — PHASE 3 HAND-OFF (Animation Track)

> **Canonical Phase-3 handoff.** This reproduces the authoritative decision record from
> the animation-track session (the durable "why" behind each deferral). Cross-checked
> against `git log`, `reports/`, and POINTWARD_TRUTH.md. Technical facts (hashes,
> file:line) were verified against the repo; decisions/reasoning are the session's.
> Where the two disagreed, the repo wins for facts and the session for rationale —
> the one discrepancy found is flagged inline (the History mockup HTML). See
> `reports/truth_phase3_reconcile.md` for the full reconciliation note.

_Deferred / future work parked during the pre-launch animation cleanup. Each item below
was audited or decided during the animation-track session; this doc is the durable
record so Phase 3 can resume without re-investigating. Ground any build on
POINTWARD_TRUTH.md + a fresh git status + the named report files in `reports/`._

_Last shipped commit: Special Moments Stage 3 (`624b044`, HEAD) — peer architecture
complete end-to-end. Restore ladder: `09ba2f5` → `b9e2a30` → `be59c38` → `d403584` →
`8fbd7d8` → `e0d7576` → `7128da7` → `c38ca9d` → (birthday-interim `9ab3f6e`) → `624b044`
(HEAD). All hashes verified against `git log`._

---

## 1. HISTORY TAB (deferred — full feature project)
**Decision:** deferred to Phase 3. Bigger than the mockup implied — it needs a net-new
data layer, not just a view. **Full scope already mapped in
`reports/history_tab_audit.md`.**

**What exists today:**
- RECEIVED history only: `PingManager.caughtHistory: [ReceivedPing]` (PingManager.swift
  ~:57), persisted as JSON in **UserDefaults** (key `caughtHistory`), NOT SwiftData.
  Capped 50, blind drop-oldest. Fields: id, fromName, emoji, timestamp, remoteID,
  senderStyle, message, tagline, isTest.
- Read/unread SoT already solid: `markOpened()` fires at reveal, server-stamps
  `opened_at`, settable on open (the "either tapped-open or watched-through" rule works).

**What's NET-NEW to build:**
- **Sent history** — NOT stored anywhere usable today (`SentLink` only holds
  messageID+personID+sentAt). Must record at the send sites (`PingManager.sendRemote`,
  `createAndShareLink`, `CompassView.sendThought`) — recipient, emoji, style, message,
  timestamp (all in hand at those sites, just discarded).
- **Preserve/pin** — no such concept exists; net-new `preserved: Bool` per item.
- **Unified store** — recommend a new SwiftData `@Model HistoryItem` (direction, person,
  emoji, style, message, date, preserved) + migrate the UserDefaults `caughtHistory`
  into it. (The legacy `Ping` @Model is sparse/unused — don't build on it.)
- **Retention engine** — replace the blind `removeFirst` with: 50 TOTAL (sent+received),
  evict oldest UNPRESERVED first, then oldest PRESERVED, **gentle warning before
  evicting a preserved item**. Unpreserved drop silently.
- ⭐ **Per-item DELETE backbone already EXISTS** (`5cf1d47`): `PingManager.removeFromHistory(id:)`
  (keyed on `remoteID ?? id`; idempotent; current UserDefaults shape) — the in-compass
  bucket's "🗑 delete" button already uses it, and the **History-tab swipe-delete reuses
  it as-is**. **Save/preserve is STILL deferred** to Phase-3 retention (the shipped delete
  is delete-only — no `preserved` flag yet).

**The view (all decided, ready to spec):**
- Own tab in the bottom bar — **additive `.tag(3)`** in `MainTabView` (`RootView.swift`
  ~:492/509), separate `HistoryView.swift`. Tab insert is TRIVIAL + low-collision; do
  NOT renumber tags 0/1/2 (hardcoded `.pointwardOpen*` handlers depend on them).
- Sent/Received toggle; rich rows = Date · Person · Message · emoji + instrument.
- Person label FLIPS: "From" on Received, "To" on Sent.
- Read/unread cue = ALL-OF-THE-ABOVE (unmissable): distinct unread row style + "New" tag
  + unread count on the toggle + a "New" section pinning unread to top.
- Swipe-to-delete = LOCAL only (sender keeps theirs) — reuse `removeFromHistory(id:)` (above).
- Supersedes the compass "your bucket ✦" section (`CompassView.swift` ~:2555) — relocate
  it out of compass when History ships.

**Mockup reference:** `pointward-history-tab-mockup.html` (visual only).
⚠️ **RECONCILE FLAG:** this file is **not present in the repo** at hand-off (`find`
returned nothing; it's not at the repo root). The visual reference likely lives outside
version control (Joshua's machine) — confirm before relying on it; the textual view spec
above is the authoritative source either way.

---

## 2. SPECIAL MOMENTS — STAGES 1+2+3 ✅ COMPLETE (only Stage 4 remains)
**Status (UPDATED):** Stage 3 SHIPPED (`624b044`) — the Birthday/Firework peer
architecture is now COMPLETE **end-to-end**. Both the sender-side AND the recipient
(`ReceiptView`) dispatch key on style/selection, not the emoji. Birthday's default is
back to the intended **🎁**. **Only Stage 4 remains** (retire the emoji fallback,
post fleet-adoption — see below). The original Stage-3 plan + gate notes are kept below
as the record of what shipped.

**What Stage 3 did (DONE):** re-keyed `ReceiptView` dispatch (~:101/106) from `emoji ==
🎂/🎆` to `style == .birthday/.firework` (emoji fallback KEPT, commented for Stage 4).
Closed the birthday-arrives-as-bucket gap AND flipped the Birthday default back from
interim 🎂 to the intended 🎁. _(reports/special_moments_stage3_build.md)_

**SQL GATE: CLEARED.** Verified `pings.sender_style` is free text, no constraint, already
holds arbitrary style strings (firefly/glow/rocket/etc.) — **no migration needed.**
`messages.instrument` (the /m/ link path) is also free text. So Birthday/Firework values
travel fine on both paths.

**Remaining gate (NON-SQL):** read `supabase/functions/send-ping-notification/index.ts`
— confirm it forwards `sender_style` blindly and doesn't whitelist/validate it. Almost
certainly fine (it's a push-sender, doesn't render the animation). If it validates,
small function edit + a Supabase deploy (Joshua).

**Interim state — RESOLVED at Stage 3:** Birthday's `defaultEmoji` was set to 🎂 as a
Stage-2 stopgap (`9ab3f6e`) and has been **flipped back to 🎁** at Stage 3 (`624b044`),
now safe because the recipient routes by style. The AnimationManifest comment is updated
to "[STAGE 3 DONE]".

**Stage 4 (later):** retire the emoji-keyed fallback branches (face/send/receipt) once
the fleet has updated. Pure cleanup.

**Reports:** `special_moments_peer_architecture_plan.md` (the full staged plan),
`special_moments_stage12_build.md` (Stages 1+2), `special_moments_stage3_build.md`
(Stage 3 — the recipient re-key + 🎁 flip), `special_moments_selector_build.md` (the
earlier Stage-stop that scoped it), `birthday_default_interim.md` (the interim flip).

---

## 2b. COMPOSE UNIFORMITY — per-instrument defaults (DE-RISKED, `277b457`)
**Direction:** move the compose-field defaults from per-EMOJI (`CuratedEmoji.defaultMessage`)
to per-INSTRUMENT (manifest), so each instrument carries its own default message + tagline.
**Step 1 SHIPPED (`277b457`):** `AnimationDefinition` now has `defaultMessage: String?` +
`defaultTagline: String?` alongside `defaultEmoji`; `CompassView.seedMessage` PREFERS the
selected instrument's `defaultMessage` and FALLS BACK to the per-emoji default (then the
TaglineSystem instrument hint). Only **Birthday → "Happy Birthday"** is populated today; every
other instrument is nil → identical to today's behavior (no regression). `defaultTagline` is a
field only — **UNWIRED** (the traveling tagline currently rides from `people.selectedPerson?.tagline`,
an entangled path; wiring deferred). The receipt is unaffected (style-keyed).
- ⭐ **What's left is now pure DATA-ENTRY, no new plumbing:** populate the other instruments'
  `defaultMessage` (and decide `defaultTagline` wiring), then retire the per-emoji
  `CuratedEmoji.defaultMessage` fallback once every instrument sets its own. The mechanism +
  fallback chain are already in place — this is the deliberate intermediate state
  (per-instrument preferred, per-emoji fallback). _(reports/birthday_default_message_build.md)_

---

## 3. FUTURE SPECIAL MOMENTS ROSTER
Valentine's 💌, For Mum 💐, July 4th 🎇, Graduation 🎓 (Birthday + Firework already built).
- Each needs: an `Instrument` + `SenderStyle` case + a manifest row + `InstrumentOption`
  case + its own face/send/receipt animation views.
- **Scaling decision parked:** if the roster grows (≥3 more committed), consider a
  **manifest-driven dispatch registry** (route by `AnimationDefinition.id` via a
  registry → zero switch edits per new moment) instead of per-moment switch arms. A
  one-time refactor; chose pragmatic per-moment for now.

---

## 4. WAND RECEIPT (deferred polish)
Wand currently uses the shared turn-to-catch BUCKET on arrival (works, not bespoke).
`WandReceiptAnimation` is a STUB (enum of constants, not a renderable View) — a real
wand receipt must be BUILT from scratch, then wired into `ReceiptView` (.wand case).
Low priority — cosmetic, not a defect. (Scoped in `reports/special_moments_selector_build.md`
during the ROOT-2 promotion, which deferred wand for exactly this reason.)

---

## 5. KNOWN GAPS / THINGS TO VERIFY (from this session)
- **Mic-DENIED wind path** — assumed working, NOT device-verified. The fallback
  hold-to-send (`WindCompassFace.fallbackHoldTick`) was left untouched; confirm it
  triggers cleanly on a permission-denied device (incl. first-launch prompt timing).
- **X button visibility** — audit read it as gated on `selectedToken != nil`, but it
  shows on the default payload in practice. Confirm X behavior across all instruments.
  (See `reports/cancel_semantics_audit.md`.)
- **Recipient-side arrival correctness** — verify each instrument plays its correct
  arrival end-to-end (esp. the newly-promoted flick/plane V2).
- **Send-sound distortion** — DEBUG-only artifact per audit; confirm clean in a
  RELEASE/TestFlight build on device (no code fix expected). See `wrapup_audit.md` Item 4.
- **Large device-test debt** — much shipped untested: plane/flick V2, Batch 1, wind fix,
  Special Moments Stages 1+2, thoughts-toggle removal, bucket delete, the replay button rework
  (`e3438a5`), and the Birthday default message (`277b457`). Needs a full device pass.
  (CONFIRMED on device so far: firework/birthday re-arm, arrival-preview removal; ACCEPTED
  as-is: rocket descent "good enough".)
- ⭐ **Replay overlay UX reworked** (`e3438a5`) — the bucket replay now uses an explicit
  **PREV · NEXT · CLOSE · DELETE** button row (auto-advance + swipe removed). Device-test
  PENDING: Prev disabled on first / Next on last / both on a single item; DELETE removes the
  current thought then advances (closes if last); the reveal is keyed on `cur.id` so a
  delete-advance re-fires the animation; PersonDetail replays (separate inline cover) must be
  unaffected. _(reports/replay_buttons_build.md)_
- ⭐ **KNOWN COSMETIC — inert "tap to keep ✦" hint** — `EmojiRevealView`'s internal faint
  "tap anywhere to keep ✦" hint still renders during the bucket replay but is now **INERT**
  (the overlay passes a no-op `onDismiss`, so tapping does nothing — CLOSE is the button).
  Left untouched on purpose (it lives in the FENCED shared reveal component). **Clean up in a
  future in-reveal pass** — gate/hide the hint when the reveal is presented in the
  button-driven replay context. Cosmetic only; no functional impact.

---

## 6. CROSS-TRACK (Phase-2 / backbone — not animation-track to build alone)
- **History data layer** — touches send-recording near PATH-1; coordinate.
- **Stage 3 Edge Function** — `send-ping-notification` read + possible deploy (Joshua).
- ⭐ **Interleaved Phase-2/pairing commits (FYI, ladder-acknowledged):** `684eabc` ("prelaunch
  fix batch" — demo local-only preview + Demo Dan rename + share-sheet-on-animation-complete +
  inline add-person) and `7ac50bc` (keep Demo Dan permanently + sole-contact switcher-tap fix)
  landed from the Phase-2/pairing track interleaved with this animation work. **`7ac50bc` is
  current HEAD.** Detailed in that track; noted here only so the ladder is accurate.
- **iOS deployment-target ship-blocker (HANDED TO PHASE-2):** the highest-impact pre-launch
  item — `CLGeocodingService` @available guard + CLGeocoder fallback, lower the target from 26.5
  → 17.0. Per `4093623` this was already done (verify current `IPHONEOS_DEPLOYMENT_TARGET`
  before acting — see the repo note below). Owned by Phase-2/backbone, not animation-track.
- ⭐ **Notifications toggle REMOVED** (`e6e0608`) — the dead/mislabeled "thoughts" toggle
  (it gated the retired `notify_pointing`, NOT thought-arrival) is gone; the app now has
  **zero user-facing notification controls**. `PingManager.setNotifyPointing(_:)` +
  `users.notify_pointing` (column) are now **unreferenced client-side** (left in place —
  not dropped). **Post-launch option (NOT pre-launch):** relabel/repoint a fresh toggle to
  gate the LIVE thought-arrival push — a cross-track item (PATH-1 client + Edge Function +
  deploy), not a standalone animation-track build. (Was previously slated "leave as-is.")
- **Pre-launch (from `wrapup_audit.md`, NOT animation work):** deployment target is
  `IPHONEOS_DEPLOYMENT_TARGET = 26.5` (locks out almost all devices) — needs a
  `CLGeocodingService` @available guard + CLGeocoder fallback, then lower to iOS 16/17.
  This is the single highest-impact pre-launch item. Also: "message opened ✦" push to
  sender (infra exists, needs a function variant + webhook + deploy), and 9 advisory
  Xcode warnings (none block submission).
  > Repo note: a prior commit `4093623` already lowered the deployment target 26.5 → 17.0
  > (per POINTWARD_TRUTH.md + git log). If `wrapup_audit.md` still cites 26.5, treat that
  > as the pre-fix state; verify the current `IPHONEOS_DEPLOYMENT_TARGET` before acting.

---

## STILL-OPEN SMALL ITEM (could close pre-launch)
- **Compass directional strings** — the "X is to your NE" guidance (revived
  `alignmentInstruction`/`AlignmentText.guidance`) shows on the compass (compass-only
  after the R1 fix). Decision deferred pending seeing the exact strings: reword or leave.
  Small.

---

_Source: animation-track session hand-off, reconciled against the repo across the
documentation passes — most recently "docs(truth): reconcile full pre-release animation
batch + handoff" (adds the per-instrument default-message direction §2b, the interleaved
Phase-2 commits `684eabc`/`7ac50bc`, and refreshed device-test debt). Companions:
`reports/truth_full_reconcile.md`, `reports/truth_phase3_reconcile.md`._
