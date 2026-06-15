# Pointward — Project Truth Document

> **This is the ONE document any future Claude Code session reads to understand
> Pointward completely.** It supersedes the fragmented bootstrap paste and is the
> canonical reference going forward. `SESSION_LOG.md` (running history) and
> `POINTWARD_ANIMATION_FRAMEWORK.md` (animation grammar) remain, but this document
> is the top of the hierarchy. When they conflict with reality, the live code +
> this document win.

_Last updated: Session 8 (structural-truth pass) · Phase 2 canon reconciliation — link-based model, scope, senderID, deep-link deferred to P3._
_Updated this session: Phase 2 progress + findings pass — builds 1–4b shipped & verified, per-person history-bucket finding (coupled to build 9), re-sequenced build order 5–11, onboarding + infrastructure notes banked._
_Findings pass 2: builds 5–6 + display-name/shortCode fix DONE & device-verified; sharpened the build-9 bucket finding (pings-table vs messages-table seam); banked hint legibility, Sarah dev-seed, duplicate-users, onboarding-emoji, share-sheet, and send-sound-distortion notes._
_Session lock-up: builds 5–9 (safe half) shipped & ledgered; CRITICAL link-send-`#if DEBUG` / delivery-backbone finding banked; bucket finding RESOLVED (sender-agnostic, local); 3 locked bucket decisions; back-half re-sequenced (11b cutover → 9b delivery-retire → 10 onboarding → 11 tests → 12 web → cleanup); build-9 left-intentionally flags + findings-pass-3 notes. CLAUDE.md: standing build patterns added._
_Build 12 reframed: SHOW-THE-MESSAGE static web page (fetch+display via getMessage(id), no animation) pulled to pre-launch; the animated-in-browser version stays Phase 3._
_Build 12 wording refreshed: contained / Claude-buildable static page (Joshua has no HTML experience); animated browser version remains Phase 3._
_SEND MODEL LOCKED: two-path send (connected → DIRECT, re-keyed pairedUserID→senderID, channel NOT retired; not-connected → "open in Pointward" universal LINK; cases 2+3 collapse; cold-start light fill-in; no double-send). 11b reframed to "implement the two-path send"; 9b reframed to retire dead pairing plumbing ONLY (PATH-1 channel survives). Build 12 CTA locked to "open in Pointward — free."_

---

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
  instrument copy but is **not yet wired** into the live send flow (Session 8
  open item). Live send currently uses the per-person poetic tagline.
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
| **Flick** 👆 | `fingerFlick` | FlickCompassFace (legacy `FlickInstrumentView` is LIVE) | SenderAnimationView (legacy) | standardReceipt (legacy) | flick_send/receipt (FlickSoundGenerator.py) | 🔒 V2 locked (visual + sound) but **parked**: FlickDeskCompassFace + Flick*V2 are test-lab; old post-it ships live. |
| **Wand** 🪄 | `wand` | WandCompassFace | WandSendAnimation | WandReceiptAnimation | wand_send/receipt (WandSoundGenerator.py) | 🔒 Locked. |
| **Plane** ✈️ | `plane` | PlaneCompassFace | PlaneSendAnimation (base live; V2 parked) | PlaneReceiptAnimation (base live; V2 parked) | plane_flight + cue wavs (PlaneSoundGenerator.py + PlaneWindupGenerator.py) | 🔒 V2 locked (visual + sound). |

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

## Never Touch

- **AppGroupStore `suiteName`** — baked into both targets.
- **Widget target bundle ID.**
- **Associated domains entitlement.**

---

## Phase 2 — Link Delivery Model (IN PROGRESS — builds 1–9 safe-half shipped)

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
model (see the build order below).

### Three LOCKED bucket decisions (Joshua, this session)
1. **Replay-from-history does NOT flip opened** — replay = re-feel, not consume.
2. **Bucket is ALL senders** — per-person scoping dropped ("fill my bucket" intent).
3. **50-cap stays**; opened link messages count toward it.

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
- **11b — IMPLEMENT THE TWO-PATH SEND** (per the locked SEND MODEL above) — **THE
  PIVOT CUTOVER, not "un-gate a flag."** Decide at send time: **connected → DIRECT**
  (the existing channel, **re-keyed `pairedUserID → senderID`**); **not-connected →
  un-gated LINK** (`/m/` + share sheet). Decision-heavy; build against the locked
  model. **Next concrete step BEFORE building:** a design-audit confirming the direct
  channel can be cleanly re-keyed `pairedUserID → senderID` and mapping exactly what
  11b must change. (Reminder: the link send is gated across 3 files / 4 sites, and the
  legacy `sendRemote` is the PATH-1 channel — it stays, re-keyed, never double-fired.)
- **9b — retire genuinely-DEAD pairing plumbing ONLY** (NOT the direct-delivery
  channel — that survives as PATH 1, re-keyed to `senderID`). The earlier "retire the
  delivery backbone" wording is **SUPERSEDED** by the locked SEND MODEL. Only the dead
  pairing bits (`connections` remnants, etc.) retire; the pings direct channel +
  realtime receive STAY (re-keyed).
- **10 — onboarding rewrite** (decision-heavy; see Onboarding Notes). Also touches
  `redeem`/`createInvite` (deferred B1) and `myPairingCode` (B5).
- **11 — Phase 2 test suite** (automated scenarios).
- **12 — SHOW-THE-MESSAGE web page** (`pointward.app/m/[id]`, in the SEPARATE
  `pointward` repo / GitHub Pages). For a recipient **WITHOUT the app**: the page
  fetches the message via the existing anon `getMessage(id)` Supabase function (built
  in build 2) and **DISPLAYS it** — emoji, message text, sender name — in a calm,
  branded layout, with the **LOCKED CTA "open in Pointward — free"** below (NOT
  "download" — rationale: lower friction + the honest universal install-or-open, per
  the SEND MODEL). Delivers the emotional payload (someone thought of you + what they
  said) WITHOUT the app and
  WITHOUT rebuilding any animation. **Rationale:** most new users arrive via a received
  link, so showing the message before install flips arrival from a toll gate ("install
  to see it") to a gift ("that's lovely — get the app to reply"). Static HTML/CSS
  reading already-stored data; **zero risk to the app** (separate repo / language;
  Joshua has no HTML experience but the page is contained and Claude-buildable). The
  **ANIMATED** browser version (recreating the instrument animation in the browser)
  stays **DEFERRED to Phase 3** — the deep fidelity/time hole; the static
  show-the-message version captures most of the emotional value at a fraction of the
  cost. **Pull forward to pre-launch** so the day-1 test-with-others experience is good
  for no-app recipients.
- **cleanup pass** — tighten/consolidate transitional logic (the mirror-write
  bridge etc.), **hard-delete** the commented code, test audit, final TRUTH cleanup.

> b10 / 11b are the **decision-heavy / fresh-mind** builds; b9 safe-half was the
> last mechanical chunk (front-loaded deliberately).

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
- **WEBSITE lives in the SEPARATE `pointward` GitHub repo** (Pages → custom domain
  pointward.app), **NOT** in `HomeLink/website/`. The `HomeLink/website/` folder
  is a **DEAD duplicate** that serves nothing — do not edit it expecting live
  effect; delete someday.
- **AASA** (apple-app-site-association) is hosted in the `pointward` repo and now
  lists `/pair/*`, `/join/*`, **AND `/m/*`** (live, verified via curl).
- **iOS caches AASA hard** — device link tests may require delete+reinstall to
  pick up `/m/*`.
- **Identity edge:** app delete+reinstall (and/or `-skipOnboarding`) can create a
  **DUPLICATE `users` row** (a null-name orphan was created this way). Joshua's
  real account (messages + name "John") = `users.id 3ef2a987-…`, short_code
  **DS2CVW**. Investigate whether normal returning-user sign-in can also duplicate
  identities (build 2 / identity hardening).
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
- **[build 2 / identity hardening] Duplicate `users` rows.** App delete+reinstall
  and/or `-skipOnboarding` can create a duplicate / null-name `users` row (orphan
  observed). Joshua's real account = `users.id 3ef2a987-…`, short_code **DS2CVW**,
  name "John". Investigate whether **normal returning-user sign-in** can also
  duplicate identities.
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
