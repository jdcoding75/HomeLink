# TRUTH Pre-Release Update — Doc Reconcile Report

_Documentation ONLY. No code / schema / settings touched. ONE commit._
_Records the pre-release animation batch (`380d374` → `e3438a5`, HEAD) into the canonical
reference + the Phase-3 handoff. Originals preserved — additive/amend only._

## Commits recorded (verified against `git log`)
- **`380d374`** — pre-release 3-in-1: (1) firework + birthday FREEZE fix (approach B —
  `finishSend` bumps `instrumentResetID` for `.firework`/`.birthday` after the flight,
  recreating the face fresh; no animation-face edit); (2) rocket receipt descent smoothing
  (first pass); (3) removed the dead "show arrival preview" setting.
- **`68de96d`** — rocket receipt FIRST-DROP fix: split the single `easeInOut(4.0)` into a
  slow `easeIn` ENTRY (`entryDropDuration` default 5.0s, tunable) + kept `easeOut` SETTLE;
  post-descent beats re-anchored off `land`. Accepted "good enough."
- **`e6e0608`** — removed the dead/mislabeled "thoughts" notification toggle (gated the
  retired `notify_pointing`); `setNotifyPointing` + `users.notify_pointing` now unreferenced
  client-side; app has ZERO user-facing notification controls.
- **`5cf1d47`** — bucket per-item DELETE: `PingManager.removeFromHistory(id:)` (keyed
  `remoteID ?? id`; reusable Phase-3 backbone) + a "🗑 delete" button on the replay overlay.
  Delete-only; NO save/preserve. [UX superseded by `e3438a5`.]
- **`e3438a5`** (HEAD) — replay overlay UX rework: auto-advance + swipe → explicit
  **PREV · NEXT · CLOSE · DELETE** button row. Prev disabled on first, Next on last (both on
  a single item); DELETE removes current + advances to next (closes if last); no auto-exit;
  reveal keyed on `cur.id` (not `idx`) so delete-advance re-fires the animation. PersonDetail
  replays (separate inline cover) unaffected; DELETE hidden when no `historyID`. KNOWN
  COSMETIC: EmojiRevealView's internal "tap anywhere to keep ✦" hint still renders but is now
  INERT (no-op dismiss) — left untouched (fenced shared reveal).

## Device-test status recorded
- firework / birthday re-arm — **CONFIRMED on device**.
- arrival-preview removal — **CONFIRMED**.
- rocket receipt descent — **accepted "good enough."**
- thoughts-toggle removal + bucket-delete + replay button rework (`e3438a5`) — **shipped,
  device-test PENDING.**

## POINTWARD_TRUTH.md — what changed this pass (all additive/amend)
1. **"Last updated:" log (line 10)** — extended the existing "PRE-RELEASE FIXES BATCH" entry
   range `380d374 → 5cf1d47` → **`380d374 → e3438a5`**, and appended the replay-UX-rework
   clause + the "device-test PENDING" list.
2. **Phase 2 — Animation Track (canonical commit ledger)** — added the **`e3438a5`** entry
   after `5cf1d47`; tagged the `5cf1d47` entry "[UX superseded by `e3438a5`]"; updated the
   device-test blockquote to include the replay rework.
3. **Restore-ladder tail (corrected)** — now ends:
   `… 624b044 → bd285d8 → 380d374 → 68de96d → e6e0608 → 5cf1d47 → e3438a5 (HEAD)`.
4. **Lock Ledger** — added a "Replay overlay UX — REWORKED (`e3438a5`)" bullet (button row,
   no auto-exit, cur.id keying, PersonDetail unaffected, inert-hint cosmetic).
   _(The `380d374`/`68de96d`/`e6e0608`/`5cf1d47` ledger + lock bullets were already present
   from the prior reconcile `0b0ba16`; left intact.)_

## reports/phase3_handoff.md — what changed this pass
- **§5 KNOWN GAPS** — added (1) the replay-overlay UX-rework device-test item (`e3438a5`) and
  (2) the ⭐ KNOWN COSMETIC note: the inert "tap to keep ✦" hint in `EmojiRevealView` to gate
  in a future in-reveal pass.
- _Already present from `0b0ba16` (left intact): §1 per-item delete backbone + save/preserve
  deferred; §6 notifications toggle REMOVED + relabel/repoint option + unused
  `setNotifyPointing`/column._

## Hash / ladder corrections
- Restore-ladder tail extended to HEAD **`e3438a5`** (was `5cf1d47`).
- All 5 hashes + HEAD verified against `git log` (`e3438a5` = HEAD). No prior hashes altered.

## Reconciliation flags
- **No conflicts** between git log / existing reports and this prompt's decisions/reasoning.
  The prompt's one-liners match the commit subjects + the per-commit build reports
  (`rocket_firstdrop_fix.md`, `remove_thoughts_toggle_build.md`, `bucket_delete_build.md`,
  `replay_buttons_build.md`).

## Files touched (this commit)
- `POINTWARD_TRUTH.md` (doc)
- `reports/phase3_handoff.md` (doc)
- `reports/truth_prerelease_update.md` (this report)
- **No code / schema / settings / animation files touched.**
