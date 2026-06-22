# Animation ↔ App/Backend Separation — Architecture Spec

_Design only. DOC ONLY — no code. Grounded in the actual repo layout (file/dir lists verified).
Goal: let the **animation/instrument track** and the **app/backend track** work in parallel on the
same HomeLink repo without colliding — in files OR in the git working tree._

> **Why this exists:** two Claude sessions share **one working tree** — one on app/backend (this
> track), one on animations/instruments. Real damage has happened: a `git clean`/`checkout` in one
> session **wiped uncommitted files** in the other (Phase 2). And **CompassView (~2826 lines)** mixes
> app-send-people logic with compass-face + flight-animation rendering, so both tracks edit the same
> file. This spec maps the territory, the collision points, and a sequenced fix.

---

## 1. CURRENT STATE (audit)

### Already-separated ANIMATION / INSTRUMENT / SOUND territory ✅
- **`HomeLink/Instruments/`** — **64 `.swift` files**, cleanly grouped by instrument: `Bow/`,
  `Compass/`, `Flick/`, `Plane/`, `Rocket/`, `Wand/`, `Wind/`, plus `_Shared/` and
  `_Shared/EmojiReveal/` (the shared reveal: `EmojiRevealView`, `EmojiRevealContext`,
  `EmojiRevealSound`, `HugRevealModifier`) and `_Shared/AnimationManifest.swift`. **This is the
  cleanest part — the animation track mostly lives here already.**
- **`HomeLink/AnimationEngine/`** — `AnimationDescriptor(s)`, `EmotionalIntent`, `HolidayVariant`,
  `AnimationEngineGuide.md`.
- **`HomeLink/Sounds/`** — 54 audio assets + generators.
- **`HomeLink/DesignSystem/AnimationSystem.swift`**, **`HomeLink/Utilities/SoundEngine.swift`**.

### Animation views still living in `HomeLink/Views/` (mixed in with app views) ⚠️
Pure animation/receipt/instrument rendering that is NOT under `Instruments/`:
`SenderAnimationView`, `ReceiptView`, `InstrumentLandingView`, `InstrumentOptionPicker`,
`InstrumentPreview`, `SkinFaceView`, `NeedleView`, `AnimationTestLabView`, `BucketCatchView`,
`BucketTipView`, `CatchBadgeView`, `DirectionIndicator`, `AlignmentGuides`.

### App / backend territory (the OTHER track)
- **Views:** `RootView`, `OnboardingView`, `AddPersonView`, `EditPersonView`, `PersonDetailView`,
  `PeopleListView`, `PersonSwitcherSheet`, `SettingsView`, `AboutView`, `GivingBackView`,
  `PaywallView`, `ProSetupView`, `ContactPickerView`, `ComposeBackView`, `ShortCodeEntryView`,
  `IncomingMessageView`, `CreateThoughtSheet`, `EmojiPickerView`, `ShareCardView`, `SkinPickerView`,
  `SkinQuickPicker`, `TaglinePickerSheet`, `TestMessageSheet`, `StepProgressView`, `LeopardGeckoView`.
- **Managers:** `PingManager`, `PeopleManager`, `CompassManager`, `SubscriptionManager`,
  `NotificationHandler`. **Services:** `SupabaseService*`. **App entry:** `HomeLinkApp`,
  `AppDelegate`, `SceneDelegate`, `RootView`.

### ⚠️ COLLISION POINTS (where the two tracks step on each other)
1. **`Views/CompassView.swift` (~2826 lines) — the big one.** It interleaves both tracks:
   - **ANIMATION:** `compassFace` (the rose/skin/needle render, MARK ~:2369), the **flight-dispatch
     block** (`if let token = flightToken { … }`, ~:665–790 — a switch over instrument style that
     mounts `FireworkSendAnimation` / `BirthdayCakeSendAnimationV2` / `SenderAnimationView` / etc.),
     plus `compassFace`-adjacent visuals (Emoji presence ~:2423, Lock badge ~:2455, Bearing readout
     ~:2475, Ambient presence glow ~:2560).
   - **APP / SEND / PEOPLE:** `sendThought` (~:2233 — PATH-1/PATH-2 selection, `createAndShareLink`,
     the demo local-only branch, `receivePing`), `finishSend` (~:2165), `nameHeader` +
     `PersonSwitcherSheet` (~:1229/1280), the history bucket on the compass (~:2565), `sendFeedbackLayer`
     ("sent ✦", ~:2097), `bottomBandRedesign` / `emojiRow` (~:1336/:1812, content/UI).
   → **Both tracks edit this one file.** This is collision point #1.
2. **The PARALLEL ENUMS — `Models/Instrument.swift`, `Models/SenderStyle.swift`,
   `Models/InstrumentOption.swift`, `Models/SoundStyle.swift`.** A new instrument (animation track)
   adds cases here; the app/delivery track also reads/switches on them. Because Swift `switch`
   statements over these enums live in BOTH tracks' files, **a new case and its switch-arm updates
   must land in the SAME commit** or the build breaks — the classic cross-track coupling.
3. **`Instruments/_Shared/AnimationManifest.swift`** — an animation source-of-truth, but the **app's
   compose seed reads it** (`CompassView.seedMessage` → `defaultMessage`/`defaultEmoji`). Shared read
   surface.
4. **`Views/ReceiptView.swift` + `InstrumentLandingView.swift`** — animation-owned, but the **app
   dispatches into them** (RootView/IncomingMessageView present `ReceiptView`). Interface seam.
5. **`Utilities/InstrumentStore.swift`** — app-style state (selected instrument, tier gating) over an
   animation-domain enum; both tracks have reason to touch it.

### ⚠️ WORKING-TREE COLLISION RISK (independent of file layout)
- **One git working tree, no worktrees** (`git worktree list` → single root; current `main`).
- Both sessions edit/build/commit in the **same checkout**. A `git clean -fd`, `git checkout --`,
  `git reset --hard`, or `git stash` run by one session **discards the other session's uncommitted
  files** — this already happened in Phase 2. File-layout separation does NOT fix this; only
  process discipline or separate checkouts (worktrees) does.
- `reports/` is **gitignored** (force-add with `git add -f`) — relevant because cross-session audit
  notes there are extra-vulnerable to a `git clean`.

---

## 2. SEPARATION OPTIONS

### a. ORGANIZE-IN-PLACE — a top-level `Animation/` group
Move the scattered animation views (the `Views/` list in §1) + `AnimationEngine/` + `Instruments/` +
`Sounds/` + `SoundEngine`/`AnimationSystem` under one documented top-level group (e.g.
`HomeLink/Animation/…`), with a one-page boundary doc ("animation track edits here; app edits
elsewhere").
- **File collisions:** ↓↓ for the scattered views (they leave `Views/`); **does nothing for
  CompassView or the parallel enums** (those stay shared).
- **Git-clobber:** **no help** (same tree).
- **Effort:** LOW (file moves + Xcode group/target-membership update; risk of fat-fingering project
  refs). **Risk:** LOW. **Pre-launch-safe:** yes (pure moves, no behavior change) — but do it in a
  quiet window so it doesn't itself collide.

### b. SWIFT MODULE / PACKAGE — extract the animation layer
Pull the animation layer into its own Swift package/module with a defined interface (the app depends
on it; it does NOT depend on app types).
- **File collisions:** ↓↓↓ — a hard compiler boundary; the app can't accidentally edit animation
  internals and vice-versa.
- **Git-clobber:** no help by itself (same tree) unless paired with worktrees.
- **Effort:** **HIGH.** The blocker is the **parallel enums + `AnimationManifest` + `InstrumentStore`
  + `ReceiptView` dispatch**: a clean module needs these de-tangled (the module owns the animation
  enums; the app references them through a stable interface), and the `CompassView` flight-dispatch
  must already be extracted (§3). **Risk:** MEDIUM-HIGH (target membership, access control, build
  config). **Timing:** **post-launch** — too invasive to do under a live TestFlight.

### c. SEPARATE BRANCH / GIT WORKTREE per track
Each session works in its **own `git worktree`** (separate working dir, separate checked-out branch,
shared `.git`), merged deliberately.
- **File collisions:** unchanged at the file level, BUT each session edits its own copy, so
  **uncommitted work is never wiped by the other's `git clean`/`checkout`** — the worktree is the
  real fix for the Phase-2 clobber. Merge conflicts surface at merge time (visible, recoverable)
  instead of as silent file loss.
- **Git-clobber:** **SOLVED** — independent working dirs.
- **Effort:** LOW (`git worktree add ../HomeLink-anim anim-track`); each gets its own DerivedData.
  **Risk:** LOW. **Pre-launch-safe:** yes. **Caveat:** the parallel-enum coupling still means
  enum+switch changes should be merged as a unit; two long-lived branches can drift, so merge often.

### d. COMBINATION — organize-in-place **+** worktrees (**+** module later)
Organize-in-place reduces *which files* each track touches; worktrees remove the *clobber* risk;
module extraction (later) makes the boundary compiler-enforced. They're complementary, not exclusive.

| Option | File collisions | Git-clobber | Effort | Risk | Timing |
|---|---|---|---|---|---|
| a. organize-in-place | ↓↓ (not CompassView/enums) | none | low | low | pre-launch (quiet window) |
| b. Swift module | ↓↓↓ (hard boundary) | none alone | high | med-high | post-launch |
| c. worktree per track | unchanged | **SOLVED** | low | low | pre-launch (now) |
| d. a + c (+ b later) | ↓↓ + clobber solved | **SOLVED** | low-med | low | **recommended** |

---

## 3. THE COMPASSVIEW PROBLEM (the file-level chokepoint)

`CompassView` is where the two tracks physically collide. `health_audit.md` already flags
**CompassView re-extraction as a Tier-2 cleanup** (and notes it grew back to ~2826 lines). Proposed
split — extract the **animation-owned rendering** out, leave the **app-owned orchestration** in:

**Extract into animation-track files (animation track edits these):**
- **`CompassFaceView.swift`** — `compassFace` + its visual companions (skin/needle/rose render, Emoji
  presence, Lock badge, Bearing readout, Ambient presence glow). Inputs only: `bearing`, `activeSkin`,
  `isLocked`, `quietMode`, presence flags. Pure render — no send/people logic.
- **`SendFlightDispatchView.swift`** — the `if let token = flightToken { … }` switch (~:665–790) that
  mounts each instrument's send animation (`FireworkSendAnimation` / `BirthdayCakeSendAnimationV2` /
  `SenderAnimationView` / …). Inputs: `token`, `style`, `bearing`, message/tagline; **output: an
  `onComplete` callback**. The animation track owns which view plays and how; the app just hands it
  the payload and gets the completion signal.

**Stays in `CompassView` (app track edits these):** `sendThought` / `finishSend` (PATH-1/PATH-2,
`createAndShareLink`, demo branch, `receivePing`), `nameHeader` + person switcher, the history bucket,
`sendFeedbackLayer`, state/orchestration. CompassView becomes the **shell** that holds state and
composes `CompassFaceView` + `SendFlightDispatchView` + the app UI.

**Dependency direction (the rule that keeps them apart):** **app → animation, never the reverse.**
The extracted animation views take plain inputs + callbacks; they do NOT import `PingManager` /
`PeopleManager` / Supabase. So the app track changes send logic in `CompassView`; the animation track
changes the look/flight in `CompassFaceView` / `SendFlightDispatchView`; they meet only at a small,
stable prop/callback interface. (`SenderAnimationView`'s existing `onComplete` is the model.)

_This split is the prerequisite that also makes Option (b), the Swift module, tractable later._

---

## 4. INTERIM WORKING RULE (follow this NOW — until separation is built)

Until worktrees/extraction land, the shared tree needs **single-writer discipline**:

1. **One session edits the shared tree at a time.** Agree who "has the pen."
2. **Commit (or stash to a named branch) before switching** sessions/tracks — leave the tree clean
   at every hand-off. Commit **selectively** (`git add <paths>`, not `-A`) so each session commits
   only its files.
3. **NEVER run `git clean -fd`, `git checkout --`, `git reset --hard`, or a discarding `git stash`
   while the other session has uncommitted work.** This is the exact action that wiped files in
   Phase 2. If you must clean, confirm the other session's tree is committed first.
4. **Enum/switch changes land together.** A new `Instrument`/`SenderStyle`/`InstrumentOption`/
   `SoundStyle` case + every `switch` arm that must handle it go in **one standalone-buildable
   commit** (the parallel-enum coupling) — don't split them across sessions.
5. **`reports/` is gitignored** → force-add cross-session notes (`git add -f reports/<file>`) and
   commit them, so a stray `git clean` can't erase them.

---

## 5. RECOMMENDATION (sequenced)

**Now (pre-launch, zero-to-low risk):**
1. **Adopt the §4 interim single-writer rule immediately** — it costs nothing and directly prevents
   the clobber that already burned a session.
2. **Stand up `git worktree`s — one per track** (`git worktree add ../HomeLink-anim anim-track`). This
   **solves the working-tree-clobber risk outright** (Option c) and is low-effort/low-risk. Merge to
   `main` deliberately and often (keep the parallel-enum changes as unit merges).

**Near-term (pre-launch, in a quiet window — NOT during a live test):**
3. **Organize-in-place** (Option a): move the scattered animation views into a top-level `Animation/`
   group + write the one-page boundary doc. Reduces which files each track touches. Pure moves.
4. **Extract the CompassView animation parts** (§3: `CompassFaceView` + `SendFlightDispatchView`) — the
   `health_audit.md` Tier-2 item. This is the highest-value collision reduction: after it, the
   animation track edits an animation file and the app track edits `CompassView`.

**Later (post-launch, optional):**
5. **Swift module extraction** (Option b) — the compiler-enforced boundary — once §3/§4 have de-tangled
   the enums + dispatch and there's no live TestFlight to destabilize.

**Net:** interim rule (now) + worktrees (now) kill the clobber risk; organize-in-place + CompassView
extraction (near-term) kill the file collisions; the module (later) makes the boundary permanent.

---

_Related: `reports/health_audit.md` (CompassView re-extraction = Tier-2; file-size inventory).
Project memory already records the shared-tree hazard ("2–3 tabs share ONE tree; commit selectively;
enum-case switch arms must land together")._
