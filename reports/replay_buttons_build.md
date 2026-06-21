# Replay Overlay — Explicit PREV · NEXT · CLOSE · DELETE Buttons

_Audit-then-build, ONE run, ONE commit. Compile-check only; device-tested by Joshua.
Recorded HEAD `5cf1d47` (restore point). BUILD SUCCEEDED (iPhone 17 Pro sim). Comment-don't-
delete: old container preserved as a block comment. Swift 5._

## PART A — AUDIT (read-only findings)

### 1. What `ReplaySwipeContainer` had (SenderAnimationView.swift:1524–1641)
- **Auto** — `@AppStorage("replayAutoAdvance") autoAdvance`; the EmojiRevealView `onDismiss`
  closure self-advanced after 2.0s when `autoAdvance && hasNext`, else dismissed; a small
  "auto" toggle dot drove it.
- **Swipe** — `DragGesture(minimumDistance: 40)` on the ZStack: left → `idx += 1`,
  right → `idx -= 1` (clamped via hasPrev/hasNext).
- **Tap-to-dismiss / hints** — the prev/next chevron text (tiny, 12pt) + the "auto" dot
  (13pt); plus EmojiRevealView's OWN internal `.onTapGesture { onDismiss() }` and its faint
  "tap anywhere to keep ✦" hint; plus RootView's external "swipe ‹ › · tap to dismiss" text.
- **items / idx / cur** — `items` computed from `request.siblings` (or a 1-item fallback
  built from the request fields incl. `historyID`); `idx` `@State`; `cur = items[clamp(idx)]`.
- **Sibling-advance re-trigger** — `EmojiRevealView(...).id(idx)`; changing `idx` rebuilt the
  reveal, re-running the bloom/animation/sound for the newly-shown thought.
- **Delete (from 5cf1d47)** — a "🗑 delete" Button gated `if let hid = cur.historyID,
  onDelete != nil`; called `onDelete?(hid)` then `onDismiss()` (closed the overlay).

### 2. Callers — bucket vs non-bucket
- **`ReplaySwipeContainer` has exactly ONE presenter: RootView** (`RootView.swift:543`,
  `.fullScreenCover(item:$pings.replayRequest)`), fed by the bucket via
  `requestReplaySequence` (CompassView.swift:2676). These requests carry per-item `historyID`.
- **PersonDetailView does NOT use the container.** It presents its OWN inline
  `EmojiRevealView` via its own `.fullScreenCover(item:$pings.replayRequest)`
  (PersonDetailView.swift:150–169), fed by `requestReplay` (single, no siblings, no
  historyID). Removing auto/swipe from the container therefore **cannot affect PersonDetail**.
- So no non-bucket caller routes through this container today. The Delete-hidden-when-no-
  historyID guard is **kept as defensive** (correct if a future no-historyID request ever
  reaches it).

### 3. STOP gates — none tripped
- Removal is NOT load-bearing for any other caller (PersonDetail is independent).
- Re-trigger on Prev/Next/Delete-advance needs **no non-trivial restructuring** — the same
  `.id(...)` mechanism drives it. **One required refinement:** key on `cur.id` (stable per
  `ReplayItem`, PingManager.swift:513), NOT `idx`. On delete-advance the next item shifts
  into the SAME idx, so `.id(idx)` would not change and the reveal would not re-fire for the
  new item. `.id(cur.id)` re-fires for BOTH Prev/Next (idx→new cur.id) and delete-advance
  (idx same, cur.id new). → proceeded.

## PART B — BUILD (the diff, 2 files)

### `SenderAnimationView.swift` — the container (old preserved, new added)
- **OLD struct block-commented** (`/* … */`, lines ~1524–1641) — auto + swipe + tap-dismiss
  container kept verbatim (comment-don't-delete), with a header noting it's superseded.
- **NEW `ReplaySwipeContainer`** — same init signature (`request:onDismiss:onDelete:`), so
  the RootView call site is unchanged. Key changes:
  - `@State private var liveItems` (a **local mutable copy** of siblings/fallback) so DELETE
    can drop an item in place and recompute nav; `@State private var idx`.
  - `EmojiRevealView(..., onDismiss: { })` — **no-op**: EmojiRevealView self-calls onDismiss
    at 6.0s and on tap (EmojiRevealView.swift:181/275), but its bloom/breathe is
    `repeatForever`, so with a no-op the thought **rests on screen with NO auto-exit**. The
    buttons are the only navigation.
  - `.id(cur.id)` (was `.id(idx)`) — re-triggers the replay on every Prev/Next/Delete-advance.
  - **PREV · NEXT · CLOSE · DELETE** button row (bottom), via a `controlButton(...)` helper:
    21pt SF Symbol + 14pt semibold label, 62pt tall, rounded lavender capsule, clear tap
    targets. Replaces the 12–13pt text + the dot toggle.
  - **No DragGesture, no auto toggle, no tap-to-dismiss** in the container.

### Button set + disable logic
- **PREV** — `idx -= 1` (animated); **`.disabled` when `idx == 0`** (`hasPrev == false`).
- **NEXT** — `idx += 1` (animated); **`.disabled` when `idx == last`** (`hasNext == false`).
  → single item: both Prev and Next disabled.
- **CLOSE** — `onDismiss()`; **always enabled**.
- **DELETE** — `deleteCurrent()`; shown **only** when `cur.historyID != nil && onDelete != nil`
  (hidden for non-bucket replays). Disabled-state colors: enabled `lav` / disabled
  `lav.opacity(0.3)`, border `0.45`/`0.18`.

### How Prev / Next / Delete re-trigger the replay
All three change which item `cur` resolves to, so `cur.id` changes → SwiftUI rebuilds
`EmojiRevealView` → `startReveal` runs again (bloom + animation + sound + text) for the
newly-shown thought. Identical to the old sibling-advance, now keyed on identity not index.

### Delete-advance + empty → dismiss + index handling
`deleteCurrent()`:
1. `removeIdx = clamp(idx)`; if that item has a `historyID`, call `onDelete?(hid)` →
   `PingManager.removeFromHistory(id:)` removes it from `caughtHistory` (unchanged, untouched).
2. `liveItems.remove(at: removeIdx)` (local drop).
3. **`if liveItems.isEmpty { onDismiss() }`** — last remaining item deleted → close overlay.
4. Else **`idx = min(removeIdx, liveItems.count - 1)`** — the next item shifts into
   `removeIdx` (stay in overlay on it); deleting the last-in-list clamps back one. Prev/Next
   enabled-states recompute for the new position automatically (computed from idx).

### Non-bucket callers still work (Delete hidden)
PersonDetail is unaffected (separate inline cover). Within the container, Delete only renders
when the shown item carries a bucket `historyID`, exactly as before.

## RootView.swift (minimal, in-fence)
- **Commented out** the obsolete external "swipe ‹ › · tap to dismiss" `Text` overlay
  (lines ~558–565) — the container now shows explicit buttons. The `onDismiss`/`onDelete`
  closures are **unchanged**; the call signature is unchanged (no auto param existed — it was
  internal `@AppStorage`).

## Fence held
- Touched ONLY: `ReplaySwipeContainer` in `SenderAnimationView.swift` (controls + nav +
  delete) + the obsolete hint text in `RootView.swift`.
- **NOT touched:** `PingManager.removeFromHistory` (called as-is), the animation/send logic,
  `EmojiRevealView` (the shared reveal — no-op closure only, no edit), the bucket bubble's
  tap-to-replay, ReceiptView, Ping wire/Supabase, other instruments, PersonDetail's replay.
- `ReplayOverlayView` (the older standalone replay struct further down the file) NOT touched.

## Known cosmetic (flagged, in-fence — NOT crossed)
- `EmojiRevealView`'s internal faint "tap anywhere to keep ✦" hint (white 0.3, 11pt) still
  renders and is now **inert** (its onDismiss is the no-op). Removing it would require editing
  the fenced shared reveal component — left untouched and flagged for a later in-reveal pass.

## Compiles
- **BUILD SUCCEEDED** (iPhone 17 Pro sim, arm64, ios17.0). SourceKit "Cannot find type
  SenderStyle / EmojiHue / AnimationSystem / PeopleManager …" + "hex:" + ScenePhase lines are
  the known cross-file indexer noise — xcodebuild is authoritative.

## For Joshua's device test
Tap a bucket thought → it plays and rests. Four large buttons: **Prev** (greyed on the first),
**Next** (greyed on the last), **Close** (always), **Delete**. Prev/Next replay the new
thought. Delete removes it (persists after relaunch) and moves to the next; deleting the last
one closes the overlay. No auto-advance, no swipe. PersonDetail replays are unchanged (no
Delete button there).
