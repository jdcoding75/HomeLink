# Birthday Default Message — Per-Instrument defaultMessage (+ defaultTagline field)

_Audit-then-build, ONE run, ONE commit. Compile-check only; device-tested by Joshua.
Additive intermediate state (per-instrument PREFERRED, per-emoji `CuratedEmoji.defaultMessage`
KEPT as fallback) — NOT a full migration. Comment-don't-delete (originals preserved). Swift 5._

## Restore point / HEAD
- Task stated restore point **`e3438a5`**; **actual HEAD = `684eabc`** (the prelaunch fix batch
  landed after e3438a5). Verified the anchor regions are **identical to e3438a5**:
  `AnimationManifest.swift` + `CuratedEmoji.swift` had a zero-line diff `e3438a5..684eabc`, and
  the CompassView seed region (`seedMessage`/`defaultMessage`/`instrumentHint`) was untouched by
  the prelaunch batch. So grounding is sound. **Restore point for THIS build = `684eabc`.**

## PART A — VERIFY (read-only findings)
1. **Manifest per-instrument default structure** — `AnimationDefinition.defaultEmoji: String =
   "🤗"` (`AnimationManifest.swift:79`), a `var` with a default so existing initializers in `all`
   are unaffected. This is the field to extend. Birthday is two entries — V1
   (`AnimationManifest.swift:198`) + V2 (`:202`), both `instrument: .birthday`,
   `defaultEmoji: "🎁"`.
2. **Compose seed line** — `seedMessage(for item:)` (`CompassView.swift:1773–1776`), called at
   `CompassView.swift:1833` (`messageText = MessageRules.clamped(seedMessage(for: item))`) and
   gated by `!messageEdited` (`:1832`, the R1 custom-text lock). **Exact current expression:**
   ```swift
   private func seedMessage(for item: CuratedEmoji.Item) -> String {
       if !item.defaultMessage.isEmpty { return item.defaultMessage }   // per-emoji curated default
       return instrumentHint() ?? ""                                     // then TaglineSystem instrument hint
   }
   ```
   Clean to layer: just PREFER an instrument-level value, then fall through to this exact chain.
3. **defaultTagline finding** — the traveling tagline rides from the **selected PERSON**
   (`people.selectedPerson?.tagline`, captured in `sendThought` as `sentTagline`), NOT from a
   compose-seed equivalent to the message field. That path is materially different/entangled, so
   per Part A #3 I **added the `defaultTagline` field but left the wiring for later** (no values
   set, no seed change). Reported, not forced.
4. **No restructuring; no receipt/PATH-1 touch** — the layering drops in cleanly. → PROCEED.

## PART B — BUILD (the diff: 2 files, +36/−2)

### `AnimationManifest.swift`
- **Added two optional fields** on `AnimationDefinition`, right after `defaultEmoji` (`:79`):
  ```swift
  var defaultMessage: String? = nil   // per-instrument; PREFERRED over per-emoji, nil = today's behavior
  var defaultTagline: String? = nil   // FIELD ONLY — not yet wired (tagline rides from the person)
  ```
  `Optional` + default `nil` → every existing initializer in `all` is unchanged.
- **Set ONLY Birthday** (both V1 + V2 `.birthday` entries — shared suffix, replaced both):
  `… defaultEmoji: "🎁", defaultMessage: "Happy Birthday"),`. Firework and all other instruments
  leave `defaultMessage` **nil**. 🎁's per-emoji message was NOT set (skipped this step). No
  `defaultTagline` values set.

### `CompassView.swift`
- **New helper** `instrumentDefaultMessage()` mirroring `defaultEmojiForCurrentAnimation`:
  ```swift
  private func instrumentDefaultMessage() -> String? {
      AnimationManifest.instruments.first { $0.instrument == instrumentStore.selected }?.defaultMessage
  }
  ```
- **Layered `seedMessage`** (original two lines PRESERVED as the fallback tail):
  ```swift
  private func seedMessage(for item: CuratedEmoji.Item) -> String {
      if let m = instrumentDefaultMessage(), !m.isEmpty { return m }   // PREFER instrument default
      if !item.defaultMessage.isEmpty { return item.defaultMessage }   // PRIOR — per-emoji default
      return instrumentHint() ?? ""                                     // PRIOR — instrument hint
  }
  ```
  Seed = `instrument.defaultMessage` ?? `CuratedEmoji` per-emoji default ?? `instrumentHint()` ?? "".

## Confirmations
- **ONLY Birthday set; all others nil → NO regression.** Only the two `.birthday` entries carry
  `defaultMessage`; every other instrument keeps `nil` and falls through to EXACTLY today's chain
  (`item.defaultMessage` → `instrumentHint()` → ""). Verified by inspection — no other init was
  given a `defaultMessage`.
- **Seed stays USER-EDITABLE.** The change is inside `seedMessage`, still called only under
  `if !messageEdited` (`CompassView.swift:1832`). A user who hand-edits the field keeps their text;
  the lock was not touched. Selecting/clearing the emoji behaves as before.
- **Birthday RECEIPT UNCHANGED.** This is compose-seed text only. ReceiptView routes the arrival by
  `style == .birthday` (the wire `sender_style`), not by the message — untouched. No receipt /
  emoji-routing / ReceiptView change. `defaultEmoji` (🎁) is unchanged.
- **Fence held.** Touched ONLY `AnimationManifest.swift` (added fields + Birthday value) and the
  `CompassView.swift` seed (helper + layered `seedMessage`). `CuratedEmoji.swift` was READ only —
  **zero-line diff confirmed** (`git diff` empty). NOT touched: ReceiptView/receipt routing, any
  animation/instrument/sound file, Ping wire/Supabase, other instruments' default VALUES (left
  nil), BreathDetector, TaglineSystem internals (only the manifest field was added — no
  `instrumentHints` change), `defaultTagline` wiring (field only).
- **Compiles** — Debug **BUILD SUCCEEDED** + Release **BUILD SUCCEEDED** (iPhone 17 Pro sim). (A
  first Release attempt failed only on a transient XCBuild "database is locked" from a concurrent
  build — re-ran clean. SourceKit "Cannot find type SenderStyle/Instrument/…" lines are the known
  cross-file indexer noise.)

## For Joshua's device test
Select the **Birthday** instrument with no emoji hand-typed → the message field seeds **"Happy
Birthday"** (was the 🎁 emoji's "a little something for you ✦"). Every other instrument seeds
exactly as before. Editing the message still sticks (user override preserved). The birthday
animation + receipt are unchanged.

## Deliberate intermediate state (documented)
Per-instrument `defaultMessage` is PREFERRED; per-emoji `CuratedEmoji.defaultMessage` remains the
FALLBACK. This is intentional, not a half-migration — only Birthday opts in today. `defaultTagline`
exists as a manifest field but is unwired/unpopulated (tagline currently rides from the person).
