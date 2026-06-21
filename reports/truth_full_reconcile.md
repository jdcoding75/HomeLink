# TRUTH Full Reconcile — Pre-Release Animation Batch + Handoff

_Documentation ONLY. No code / schema / settings. ONE commit. Ground: POINTWARD_TRUTH.md +
`git log` + existing reports/. Verified the ladder against `git --no-pager log --oneline -20`._

## Verified commit ladder (actual git order, newest → oldest)
```
7ac50bc  keep Demo Dan permanently + sole-contact switcher tap   ← Phase-2/pairing · HEAD
277b457  per-instrument defaultMessage; Birthday "Happy Birthday" ← THIS track (NEW to record)
684eabc  prelaunch fix batch (demo preview, share-sheet gate, …)  ← Phase-2/pairing
02231a4  docs(truth): record pre-release animation batch          ← prior reconcile
e3438a5  replay overlay UX rework                                  ← already recorded
0b0ba16  docs(truth): record pre-release fixes + bucket delete     ← prior reconcile
5cf1d47  bucket per-item DELETE                                    ← already recorded
e6e0608  remove "thoughts" notification toggle                    ← already recorded
68de96d  rocket receipt first-drop fix                            ← already recorded
380d374  pre-release fixes (3-in-1)                               ← already recorded
bd285d8  docs(truth): Stage 3                                      ← prior reconcile
624b044  Special Moments Stage 3                                  ← already recorded
```

## ⚠️ Conflicts / corrections found (flagged)
1. **The prompt listed `380d374`, `68de96d`, `e6e0608`, `5cf1d47`, `e3438a5` "to record" — but
   they were ALREADY recorded** in the two prior reconciles (`0b0ba16` recorded `380d374`→
   `5cf1d47`; `02231a4` added `e3438a5`). Verified each is present in TRUTH's ledger + the
   "Last updated" PRE-RELEASE FIXES BATCH entry. **Not duplicated** — only verified.
2. **The prompt called the Birthday default-message commit "HEAD" — it is NOT.** Its hash is
   **`277b457`**, and it sits one commit BELOW HEAD. **Actual HEAD = `7ac50bc`.**
3. **TWO interleaved Phase-2/pairing commits exist, not one.** The prompt flagged only
   `684eabc`; a SECOND non-animation commit **`7ac50bc`** landed after the prompt was written
   (it is now HEAD). Both are acknowledged in the ladder (not detailed — other track).
4. **Stale "HEAD" annotation fixed:** the "Last updated" log's PRE-RELEASE FIXES BATCH range
   read "(`380d374` → `e3438a5`, HEAD)"; HEAD has since moved past `e3438a5`, so the `, HEAD`
   was removed.

## POINTWARD_TRUTH.md — what changed (additive/amend; nothing deleted)
1. **Canonical commit ledger** — added the **`277b457`** entry (per-instrument default message;
   prefer-instrument / fallback-per-emoji; Birthday only; `defaultTagline` unwired; receipt
   unchanged). Added an "Interleaved (Phase-2/pairing track)" note recording `684eabc` +
   `7ac50bc` and that `7ac50bc` is HEAD.
2. **Restore-ladder tail** — extended to actual git order:
   `… 5cf1d47 → e3438a5 → 684eabc* → 277b457 → 7ac50bc* (HEAD)`, with `*` marking the two
   Phase-2/pairing commits as interleaved (not animation-track).
3. **Device-test blockquote** — added the Birthday default message (`277b457`) to the PENDING
   list.
4. **Lock Ledger** — added a "Per-instrument default message — SHIPPED (`277b457`)" bullet
   noting it de-risks the uniformity direction to pure data-entry.
5. **"Last updated" log** — fixed the stale `, HEAD`; appended a "COMPOSE-UNIFORMITY STEP 1
   (`277b457`)" entry + the interleaved-commits / HEAD-correction note.

## reports/phase3_handoff.md — what changed (file already existed; refreshed)
- **New §2b — COMPOSE UNIFORMITY (de-risked, `277b457`):** the per-instrument default
  direction; Step 1 shipped; what's left is pure data-entry (populate other instruments +
  retire the per-emoji fallback), no new plumbing; `defaultTagline` unwired.
- **§6 CROSS-TRACK** — added the interleaved `684eabc`/`7ac50bc` acknowledgment (HEAD =
  `7ac50bc`) and the iOS deployment-target ship-blocker handed to Phase-2 (per `4093623`,
  verify current target).
- **§5 device-test debt** — refreshed to include thoughts-toggle removal, bucket delete, the
  replay rework (`e3438a5`), and the Birthday default message (`277b457`); plus the
  CONFIRMED/ACCEPTED status so far.
- **Footer** — updated the source/companion line.
- _Already present from prior reconciles (verified, left intact): History tab (§1) + the
  `removeFromHistory` per-item backbone + save/preserve-deferred; Special Moments Stages 1+2+3
  COMPLETE / Stage 4 remains (§2); Future roster + manifest-driven-registry scaling decision
  (§3); Wand receipt stub (§4); known gaps incl. mic-denied wind / X-button / arrival
  correctness (§5); inert "tap to keep ✦" cosmetic (§5); notifications-toggle-removed +
  relabel option (§6); opened-✦ push + 9 advisory warnings (§6)._

## Device-test status recorded
- **CONFIRMED on device:** firework/birthday re-arm, arrival-preview removal.
- **ACCEPTED as-is:** rocket descent ("good enough").
- **PENDING device test:** thoughts-toggle removal, bucket delete, replay button rework
  (`e3438a5`), Birthday default message (`277b457`).

## Files touched (this commit)
- `POINTWARD_TRUTH.md` (doc)
- `reports/phase3_handoff.md` (doc)
- `reports/truth_full_reconcile.md` (this report)
- **No code / schema / settings / animation files touched.**
