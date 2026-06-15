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
_COMPREHENSIVE LOCK-DOWN (back-half design fully resolved): IDENTIFIER BACKBONE framing; CONNECTION-SIGNAL build spec (the gap, two new local stores S1/S2, `link_connections` migration + `record_connection` RPC, 10 cases, 4 resolved decisions, auth-timing correct-by-design) STAGED A→B→C with the family-test gate AFTER C; ONBOARDING/ARRIVAL north-star (message-first, 3 doors, showcase/paywall out of the gate, just-in-time identity); WEB PAGE locked design + canonical pitch + 3-tier animation ladder; PATH-1 push / ~30-day lifespan + save/delete / growth; standing prioritization principle; parked/deferred consolidated._
_Build 12 web page BUILT · DEPLOYED · LIVE-TESTED (pointward-website `2d319d4`, 404.html path-style, anon `get_message`, DARK-PURPLE brand superseding "warm cream", shipped copy, does NOT mark_opened, install button = TestFlight placeholder pending external review; two invite surfaces locked). Stage B build-spec LOCKED (`reports/stage_b_buildspec.md`)._
_Onboarding walk-through banked (Build 10 North-Star): DROP the pairing-code screen (absorbed; loopFlick-guard caution); NAME PRE-FILL LOCKED (recipient's fill-in pre-filled with the sender's label for them, warm + editable, no "is this you?"); ADDRESS/LOCATION at onboarding FOR CONSIDERATION (need-at-all / Apple-home-autofill / as-is — resolve "what is it for?" + address-vs-rough-location first)._

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
model (see the build order below + the connection-signal spec).

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
- **STAGE B — the signal — ✅ BUILD-SPEC LOCKED** (`reports/stage_b_buildspec.md`;
  build-ready, no new decisions). Three independently-testable steps:
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
- **11b — IMPLEMENT THE TWO-PATH SEND** (per the locked SEND MODEL + connection-signal
  spec above) — **THE PIVOT CUTOVER.** Now **STAGED A→B→C** (the design-audit is DONE —
  `reports/connection_signal_build_spec.md`):
  - **A** (no schema, ships): un-gate the link + remove the unconditional legacy send +
    add (S1) `SentLink`. = PATH-2 "a link for everyone."
  - **B**: the `link_connections` migration + receiver write/sweep (S2) + sender stamp.
  - **C**: two-path `if/else` (connected → DIRECT re-keyed; else LINK) + poll receipts.
  - **⚠️ Family-test gate is AFTER C** (link-every-time feels clunky to close contacts).
- **9b — retire genuinely-DEAD pairing plumbing ONLY** (NOT the direct-delivery
  channel — that survives as PATH 1, re-keyed to `senderID`). The earlier "retire the
  delivery backbone" wording is **SUPERSEDED** by the locked SEND MODEL. Only the dead
  pairing bits (`connections` remnants, etc.) retire; the pings direct channel +
  realtime receive STAY (re-keyed).
- **10 — onboarding rewrite** — see **ONBOARDING / ARRIVAL NORTH-STAR** below (the
  earlier "subtractive cut" of the dead connection-code screen is **ABSORBED** into
  this redesign, not a separate build). Also touches `redeem`/`createInvite` (B1) and
  `myPairingCode` (B5).
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
  **trust-line** *"free · no ads · for real"* (truthful — Pointward monetizes via the
  paywall, NOT ads; keep that promise); quiet short-code fallback; faint drifting
  instrument hints.
- **DOES NOT `mark_opened`:** the web page **displays but does NOT flip opened** —
  preserving the locked definition (*read = opened IN FULL IN-APP, the way the sender
  intended*; a web glance is not a read). **The audit's "optional `mark_opened`" was
  deliberately DECLINED.**
- **⚠️ ONE OPEN DEPENDENCY:** both "Open / get Pointward" buttons use
  **`TESTFLIGHT_LINK_PLACEHOLDER`.** Joshua has **not** done external TestFlight review,
  so no public install link exists yet. The page **fetches / displays real messages
  TODAY** — only the install **destination** waits. Swap in the real link after external
  TestFlight review (→ public link) OR at App Store launch. **Routing (locked):**
  straight-to-install (no landing-page hop) for least friction.
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
