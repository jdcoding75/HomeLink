# Pointward — Project Truth Document

> **This is the ONE document any future Claude Code session reads to understand
> Pointward completely.** It supersedes the fragmented bootstrap paste and is the
> canonical reference going forward. `SESSION_LOG.md` (running history) and
> `POINTWARD_ANIMATION_FRAMEWORK.md` (animation grammar) remain, but this document
> is the top of the hierarchy. When they conflict with reality, the live code +
> this document win.

_Last updated: Session 8 (structural-truth pass) · Phase 2 canon reconciliation — link-based model, scope, senderID, deep-link deferred to P3. · IDENTITY CORRECTION: not forking — the two `users` rows are 2 Apple IDs (Joshua + wife), identity IS stable, hardening deprioritized; banked the display-polish batch (arrival-name, connection-indicator, contact-icon) as active small work. · SESSION CLOSE: Stage A/B/C + display polish all COMMITTED (clean tree, HEAD `90422fd`); banked the CLEAN-RESET PROTOCOL for next session (churn-fogged device state — reset before verifying) + open items (stuck "connected" banner, display clean-verify, old-copy cleanup, double-tap cold-start audit). · CLEAN TWO-PHONE TEST DONE: verified connection/green-indicator/PATH-1-direct/initials clean; RESOLVED the notification model (notify only when connected → named push → tap opens app → plays the arrival; link IS the awareness for unconnected); prioritized next-session list led by **[HIGH] PATH-1 push not firing when app-closed (code gap, not permission)** + **[HIGH] share-text "[John]" copy/name**. · BUG FOLD: re-homed the open bug list under its phases — FINISH 11b/Stage C (#1 push, #2 share-text, #3 envelope name, #15 display-verify), BUILD 9b (#4 forced-send/added-you, #5 legacy connect screen), BUILD 10 (#6 onboarding name-not-persist [root of "Someone"], #7 Settings profile, #9 old-copy cleanup), separate double-tap audit (#8); added **REMAINING BUGS (unphased)** catch-all — animation territory (#12 Plane v1/v2, #13 aiming-order, #14 send-sound) + notes (#10 Alex-demo, #11 first-send warm-up). · PRE-TEST BATCH: **5 fixes BUILT + uncommitted** (#8 double-tap cold-launch, #2 share-text named copy, #3 envelope "from [name]", #4 forced-send-on-add removed, #5 legacy connect screen removed) — all Release+248-green, batched for ONE clean two-phone test before commit; benched push `index.ts` (#1) awaits Joshua redeploy. Banked the obstacle-removal status (stuck "[name] connected" banner = NO live code, likely stale notification) + the 5-step clean test plan (commit the batch only if all pass). · ⭐ SESSION CLOSE — BATCH + PUSH COMMITTED & DEVICE-VERIFIED: app batch `d03eb3e` (5 fixes) + push fn `feafe7a` all passed the clean two-phone test; **PATH-1 push works END-TO-END** (named "John sent you a thought ✦" on a closed phone → tap → arrival played) — the send model's last functional gap is CLOSED (the boot bug meant the function NEVER booted before). NEW findings (all phone-free): #1 PersonDetailView still pairing-driven (load-bearing tap→compose bug), #2 unread count never clears, #3 sender-reinstall re-stamp gap, #4 connection-sync lag, #5 stray `rapid-action` Edge Function (delete), double-tap = iOS Messages behavior (RESOLVED, not a bug). Runway is ALL phone-free: PersonDetailView fix, unread-clear, 9b cleanup, Build 10 + #6, Phase-2 tests. · SESSION CONTINUED: PersonDetailView reconcile (`73cceaa`, senderID-primary isConnected + ungated compose, device-verified) + unread-badge Option A (`7c0f956`, markAllMyPingsOpened on foreground, "marked all opened ✓") both COMMITTED & verified — findings #1+#2 CLOSED. **9b CLEANUP AUDIT DONE** (5-batch removal plan; 2 catches — `connectedFriendID` is LOAD-BEARING/preserve, `claimOutcome`+tests now app-orphaned → Joshua decides retire-vs-keep). Animation (#12/#13/#14) queued-not-started (don't run animation+9b builds together). 9b removals START next session. · ⭐ 9b DEAD-PAIRING CLEANUP COMPLETE: B1 dead views (`abc9e77`) + B2 invite-accept API/DI (`6c7f8c5`) + B3+B5 PeopleManager funcs/tests/isConnected (`9883a60`) + B4 mutual-pointing unwire (`04e80d6`, NotificationHandler thought/PATH-1 branch byte-identical, device-glance passed) all COMMITTED; `rapid-action` stray Edge Function deleted; tests 246→227. The LIVE pairing-code-gen subsystem STAYS (sign-in mints a code via myPairingCode → connections) = separate post-9b item (around/after Build 10). Surfaced: arrival-preview mystery prompt, history-replay-should-be-full-animation, trailing leftovers. **LINK-ERA PIVOT SUBSTANTIALLY COMPLETE.** NEXT: Build 10 (onboarding + #6 name-persist). · ⭐ BUILD 10 DECISIONS LOCKED (Joshua, pre-build): governing principle = **friction-free for most + require info only WHEN IT'S USED** (path-split is a consequence, not a rule). NAME required at the **send-moment** (sender has one → satisfies #6; receiver not asked) + self-explaining copy + Apple pre-fill (never relied on; flow GUARANTEES display_name) + edit-per-message; no Contacts-for-name. LOCATION **don't force it** (felt-directionality not a receiver requirement now; Phase-3 live location makes manual moot → keep light). EDUCATION/showcase lives in **Settings**, OFFERED not forced (after first receive, or optional onboard screen). STILL OPEN: patch-vs-rebuild the paged TabView; 3-doors rendering; drop the sign-in myPairingCode mint. (Audit: `reports/build10_onboarding_audit.md`.) · ⭐ BUILD 10 DESIGN SESSION (decisions + REASONING banked): governing principle now = friction-free + require-when-used + TUTORIAL-AS-SETUP (refinement: honest upfront ask when no clear use-moment, e.g. notifications). Locked: NAME at send-moment (Apple .fullName pre-fill is trivial — already requested, just discarded), LOCATION 3-option (skip/type/use-current; "use current" = the Phase-3 on-ramp; sends carry NO location confirmed), SIGN-IN-FIRST for fresh installer (commitment momentum), unified first-open showcase (Demo Dan; link-arriver message-first then showcase-as-tap), education in Settings, notifications upfront, add-person Contacts-autofill (has-address → skip location), graceful exit safe (name lives at send), RETIRE the pairing code (half-dead/unredeemable → stop showing; full retirement = own audit-first task around B10), PATCH-not-rebuild trending. Prep-audit findings banked (no location in sends, mystery-prompt=arrival-preview [closed], no history delete, screen inventory reuse/relocate/delete). STILL OPEN: the link-arriver send-back path (last design piece) + patch-vs-rebuild. · ⭐ LINK-ARRIVER PATH DESIGNED (structure locked, copy placeholder): tap → real message plays (no gate) → landing 3-doors ("send one back to [Name]" / "see what Pointward is" / "I'm good for now"); send-one-back composes straight back (no signup wall) capturing name (#6 lands here) + location via **FILL LADDERS** that READ stored records VIA THE LINK (confirm-don't-enter), NOT from the send (send stays lightweight). Verify-in-build: records store location + link grants read-access to a connected user's fields (RLS). Mindset: build CORE/structural now, copy/look/feel = iterative POLISH ROUNDS near publish. Design session COMPLETE; only patch-vs-rebuild remains (resolves at build-scope). · ⭐ BUILD 10 BUILT + PHONE-WALKED (single-phone cursory): Shots 1/2/3a + landing + minor cleanup + the 5-fix batch all COMMITTED (HEAD `b10190f`); patch-vs-rebuild RESOLVED to **PATCH** (paged TabView trimmed in place). Onboarding now **sign-in → about-you (finishes)** — showcase OUT of the forced flow (deferred to an optional Yes/No; the marketing/showcase carousel kept DORMANT `#if false` for reuse). Link-arriver path works end-to-end cursory (3 doors, bypass + compose-back + fill-via-link). DECISIONS banked: name-step copy "How should your name appear to [Name]?", Home Location "(optional but recommended)", "Message from [Name]" on arrivals, **FULL SEND+RECEIPT FOR BOTH ROLES** (animation-track, +receiver replay), **HINT BAR** (in-context discoverability), hint/helper legibility, randomize-showcase-variety, **"mini card" voice** (product-wide copy, focused pass later — NOT blanket replace), Apple "My Card" auto-fill considered→probably-NO. DEFERRED: **2c compose-back routing** (RECEIPT-not-send-out — likely history-replay, needs device-repro; near PATH-1 backbone), location wiring (use-current/legibility/Phase-3), showcase Yes/No, Settings education home, hint-bar v1, copy pass, **pairing-code-gen retirement** (own audit-first), animation-tab (incoming build-up / #12 Plane-v1-v2). DEFERRED TESTING: real 2-phone round-trip. (Findings: `reports/build10_walkthrough_findings.md`.) · ⭐ PAIRING-CODE RETIREMENT COMPLETE (end-to-end, server + code): the whole subsystem removed across steps 2–8 (mint/screens/share/redeem, connectedFriendID + plumbing, refreshConnection(s), DiscoveredConnection, cosmetic presence, mint internals + ~8 tests, the `connections`-table code refs) — table dropped server-side; LINK (link_connections/senderID/short_code//m/) is the sole connection model; gecko/active-person/PATH-1 untouched (214 tests). · ⭐ DEPLOYMENT TARGET LOWERED 26.5 → **17.0** (`4093623`): app installs on shipped iPhones now; iOS-26-only geocoding `@available`-guarded with a CLGeocoder fallback (same GeocodedLocation shape, callers unchanged); 16.0 blocked by the widget's iOS-17 WidgetKit use. App Store toolchain ✅ (Xcode 26.5 / iOS-26 SDK / Tahoe 26.5.1). · ⭐ STRUCTURAL CLEANUP MAP banked (post-TestFlight ranked plan — dead-code → SupabaseService split → dedup → CompassView extraction → pairedUserID migration; the containment work that unlocks parallel builds; see new section at file end + `reports/structural_map.md`)._
_Updated this session: Phase 2 progress + findings pass — builds 1–4b shipped & verified, per-person history-bucket finding (coupled to build 9), re-sequenced build order 5–11, onboarding + infrastructure notes banked._
_Findings pass 2: builds 5–6 + display-name/shortCode fix DONE & device-verified; sharpened the build-9 bucket finding (pings-table vs messages-table seam); banked hint legibility, Sarah dev-seed, duplicate-users, onboarding-emoji, share-sheet, and send-sound-distortion notes._
_Session lock-up: builds 5–9 (safe half) shipped & ledgered; CRITICAL link-send-`#if DEBUG` / delivery-backbone finding banked; bucket finding RESOLVED (sender-agnostic, local); 3 locked bucket decisions; back-half re-sequenced (11b cutover → 9b delivery-retire → 10 onboarding → 11 tests → 12 web → cleanup); build-9 left-intentionally flags + findings-pass-3 notes. CLAUDE.md: standing build patterns added._
_Build 12 reframed: SHOW-THE-MESSAGE static web page (fetch+display via getMessage(id), no animation) pulled to pre-launch; the animated-in-browser version stays Phase 3._
_Build 12 wording refreshed: contained / Claude-buildable static page (Joshua has no HTML experience); animated browser version remains Phase 3._
_SEND MODEL LOCKED: two-path send (connected → DIRECT, re-keyed pairedUserID→senderID, channel NOT retired; not-connected → "open in Pointward" universal LINK; cases 2+3 collapse; cold-start light fill-in; no double-send). 11b reframed to "implement the two-path send"; 9b reframed to retire dead pairing plumbing ONLY (PATH-1 channel survives). Build 12 CTA locked to "open in Pointward — free."_
_COMPREHENSIVE LOCK-DOWN (back-half design fully resolved): IDENTIFIER BACKBONE framing; CONNECTION-SIGNAL build spec (the gap, two new local stores S1/S2, `link_connections` migration + `record_connection` RPC, 10 cases, 4 resolved decisions, auth-timing correct-by-design) STAGED A→B→C with the family-test gate AFTER C; ONBOARDING/ARRIVAL north-star (message-first, 3 doors, showcase/paywall out of the gate, just-in-time identity); WEB PAGE locked design + canonical pitch + 3-tier animation ladder; PATH-1 push / ~30-day lifespan + save/delete / growth; standing prioritization principle; parked/deferred consolidated._
_Build 12 web page BUILT · DEPLOYED · LIVE-TESTED (pointward-website `2d319d4`, 404.html path-style, anon `get_message`, DARK-PURPLE brand superseding "warm cream", shipped copy, does NOT mark_opened, install button = TestFlight placeholder pending external review; two invite surfaces locked). Stage B build-spec LOCKED (`reports/stage_b_buildspec.md`)._
_Onboarding walk-through banked (Build 10 North-Star): DROP the pairing-code screen (absorbed; loopFlick-guard caution); NAME PRE-FILL LOCKED (recipient's fill-in pre-filled with the sender's label for them, warm + editable, no "is this you?"); ADDRESS/LOCATION at onboarding FOR CONSIDERATION (need-at-all / Apple-home-autofill / as-is — resolve "what is it for?" + address-vs-rough-location first)._
_PRODUCT DIRECTION DUMP banked (future work, decided-vs-for-thought): APP CONCEPT/positioning (primary=emotional-connection via intent+meaning; secondary=anti-card-app); HELP/FAQ/HOW-TO + About (Settings-top, optional, the explorable home for the onboarding showcase); SETTINGS-tab review project (+ planned: Help, "turn off send-actions" advanced toggle [check-if-exists], structured feedback picker, "catch in bucket" toggle default-OFF); OCCASION notifications (parked); LAUNCH/MONETIZATION (seed-free-then-monetize principle endorsed; founding-cohort + propagating-free-Pro direction; specifics open for a dedicated session)._
_STAGE B VERIFIED end-to-end (two-phone test, 2 real Apple IDs → link_connections row formed — the back-channel is PROVEN). Findings banked: arrival shows "Someone" not sender_display_name (BUG) + recipient-local-name enhancement; Plane v1-not-v2 wrong-animation regression (careful audit-first, future); connection-status indicator (driven by senderID, pairs with Stage C); don't-seed-Alex-into-People; remove "[John] added you" notification (pairing-era); widget surface + Phase-3 live-location payoff; address-on-add PARKED + contacts-permission RESOLVED (ask only on pick-from-contacts) + send-channel fork (open); MANUAL PAIRING RESOLVED — do NOT re-add (re-tappable link is the fallback)._

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

### ⭐ REMAINING BUGS (unphased) — no phase home (stragglers)
The bugs above are folded into their phase homes (11b/Stage C · 9b · 10) + the separate
double-tap audit. These have **no phase home** — they ride a different track:

**ANIMATION TERRITORY** (⚠️ the *"never touch without care"* set — careful, AUDIT-FIRST,
**batched separately** in an animation-chat session, NOT in the Phase-2 build line):
- **#12 — Plane v1-not-v2 regression.** Sent with Plane → arrival played **Plane v1**, but
  **Plane v2 is LOCKED** as gold-standard. Send/receive resolves the OLD version — a real
  regression. Needs a careful audit of where the version is resolved on send/receive.
- **#13 — Animation aiming-order** (load emoji **before** aim feels broken): the
  emoji-then-aim sequencing reads wrong in the send mechanic. Animation-chat; audit-first.
- **#14 — Send-sound distortion.** ⚠️ Reported under a **DEBUG** build — **VERIFY in a
  release/TestFlight build BEFORE treating as real** (likely a debug-mode artifact). If
  real in release → animation-chat (sound files are animation territory). If debug-only →
  ignore.

**NOTES** (confirm / observe — not necessarily real work):
- **#10 — Alex Demo disappears** when a real contact is added — **likely intended**
  behavior (the demo steps aside for real people); **confirm**, don't assume a bug.
- **#11 — First-send-only animation breakup/noise** — 1st send after launch stutters, 2nd
  is clean: a **cold-start / warm-up** pattern (asset/first-run priming), not a logic bug;
  observe. (If pursued → animation territory.)

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

### ⭐ LAUNCH / MONETIZATION STRATEGY (direction banked; specifics = dedicated discussion)
**PRINCIPLE (endorsed):** **seed the network FREE before monetizing.** An
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
- **WEBSITE lives in the SEPARATE `pointward` GitHub repo** (Pages → custom domain
  pointward.app), **NOT** in `HomeLink/website/`. The `HomeLink/website/` folder
  is a **DEAD duplicate** that serves nothing — do not edit it expecting live
  effect; delete someday.
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
