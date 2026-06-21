# TRUTH Pre-Release Update — Doc Reconcile Report

_Documentation ONLY. No code / schema / settings touched. ONE commit._
_Records the pre-release animation-fixes batch (`380d374` → `5cf1d47`, HEAD) into the
canonical reference + Phase-3 handoff. Originals preserved — additive/amend only._

## Commits recorded (verified against `git log`)
- **`380d374`** — pre-release 3-in-1: (1) firework + birthday FREEZE fix (approach B —
  `finishSend` bumps `instrumentResetID` for `.firework`/`.birthday` after the flight; no
  animation-face edit); (2) rocket receipt descent smoothing (first pass); (3) removed the
  dead "show arrival preview" setting.
- **`68de96d`** — rocket receipt FIRST-DROP fix: split the single `easeInOut(4.0)` into a
  slow `easeIn` ENTRY (`entryDropDuration` default 5.0s, tunable) + kept `easeOut` SETTLE;
  post-descent beats re-anchored off `land`. Accepted "good enough."
- **`e6e0608`** — removed the dead/mislabeled "thoughts" notification toggle (gated the
  retired `notify_pointing`); `setNotifyPointing` + `users.notify_pointing` now unreferenced
  client-side; app has ZERO user-facing notification controls.
- **`5cf1d47`** (HEAD) — bucket per-item DELETE: `PingManager.removeFromHistory(id:)`
  (keyed `remoteID ?? id`; reusable Phase-3 backbone) + a "🗑 delete" button on the replay
  overlay (`ReplaySwipeContainer`). Delete-only; NO save/preserve.

## Device-test status recorded
- firework / birthday re-arm — **CONFIRMED on device**.
- arrival-preview removal — **CONFIRMED**.
- rocket receipt descent — **accepted "good enough."**
- thoughts-toggle removal + bucket-delete — **shipped, device-test PENDING.**

## POINTWARD_TRUTH.md — what changed (all additive/amend)
1. **"Last updated:" log (line 10)** — appended a "⭐ PRE-RELEASE FIXES BATCH
   (`380d374` → `5cf1d47`, HEAD)" entry.
2. **Phase 2 — Animation Track (canonical commit ledger)** — appended the 4 commit
   bullets after `624b044` under a "_Pre-release fixes batch (this session)_" sub-header,
   plus a device-test status blockquote.
3. **Restore-ladder tail (corrected)** — now reads:
   `… c38ca9d → (birthday-interim 9ab3f6e) → 624b044 → bd285d8 → 380d374 → 68de96d →
   e6e0608 → 5cf1d47 (HEAD)`.
4. **Lock Ledger** — added 5 bullets: firework/birthday FREEZE fixed (`380d374`); rocket
   receipt descent SMOOTHED (`380d374` + `68de96d`); Settings notifications REMOVED
   (`e6e0608` → zero user-facing notification controls); bucket per-item DELETE SHIPPED
   (`5cf1d47`).
5. **PHASE 3 — History-tab bullet** — noted the per-item delete backbone
   (`removeFromHistory(id:)`) now EXISTS; save/preserve still deferred.

## reports/phase3_handoff.md — what changed
- **§1 HISTORY TAB** — added the "Per-item DELETE backbone already EXISTS" note
  (`removeFromHistory(id:)`, swipe-delete reuses it); reaffirmed Save/preserve deferred to
  Phase-3 retention; amended the swipe-to-delete line to reference the backbone.
- **§6 CROSS-TRACK** — recorded the notifications toggle REMOVAL (`e6e0608`), the now-unused
  `setNotifyPointing`/`users.notify_pointing`, and the post-launch relabel/repoint option
  (replacing the prior "leave as-is" stance).

## Hash / ladder corrections
- Restore-ladder tail extended + corrected to include `bd285d8` (docs) and the 4 new
  commits ending at HEAD `5cf1d47` (see above).
- All 4 hashes + HEAD verified against `git log`. No prior hashes altered.

## Files touched (this commit)
- `POINTWARD_TRUTH.md` (doc)
- `reports/phase3_handoff.md` (doc)
- `reports/truth_prerelease_update.md` (this report)
- **No code / schema / settings / animation files touched.**
