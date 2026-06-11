# Pointward — Decisions Log (strategy + pivot session)

## PRODUCT POSITIONING (locked)
- Pointward is BIGGER and more INTENTIONAL than a text:
  sound + full-screen takeover + real animation + visible intent.
  These four = the "bigness floor." Every send must clear all four.
- NOT competing on "easier than texting" (ease = fancy text = death).
- Kept perks from the card metaphor: costs less than physical cards;
  serves a small circle of loved ones.
- TWO use-cases, different ceremony tiers:
  1. OCCASION card (birthday, holiday) — heavy ritual, friction is good,
     marketing hero. Episodic.
  2. THINKING-OF-YOU to your circle — light ritual, fast but still big.
     Habitual = the retention engine.
- Meaning LEADS, convenience ENABLES (don't lead with convenience).

## DELIVERY (locked this session)
- PHASE 1 = LINK-BASED delivery. Sender creates capsule → gets shareable
  link → shares via their own messaging → receiver taps → app opens it
  (or install prompt WITH a teaser of what's waiting).
- Reuses existing deep-link infra (AppLinks.swift, currently pairing codes).
- This DELETES the hardest rework (partner-scoped realtime receive) rather
  than rebuilding it. No paired accounts needed.
- Auto-push-to-contacts = Phase 2 only if link friction proves too high.
- Web viewer (no install) = Phase 2, deferred. No web infra exists yet.

## PAIRING REMOVAL (planned, NOT started — do fresh next session)
Per PAIRING_AUDIT.md. Order:
  1. Add contact identity to Person (contactIdentifier + contactName
     alongside editable display name)
  2. Implement link-based delivery (the keystone)
  3. Collapse to single sendRemote path (retire sendPing(to person:))
  4. Strip pairing UI (ConnectView, PairAcceptView, MutualMomentView),
     deep-link pairing, presence/reportPointing, compass_bearings
  5. Drop isDynamic / receiver-side live location
- Steps 1-3 load-bearing; 4-5 mostly deletions.
- Compass/direction is ALREADY sender-side — the aim experience SURVIVES
  pairing removal untouched. Animations/instruments untouched by pairing.
- Removal size: MEDIUM. Isolated behind 3 seams (SupabaseService,
  PingManager, Person.pairedUserID).

## SENDS TO FINISH (the strong set — finish to "big" + full loop)
- ROCKET — effectively done, one of the best, first-try countdown ceremony.
  Keeps its ORIGINAL legs-down landing.
- BIRTHDAY — showstopper / marketing hero. Most built. Finish the bigness.
  Blow-out = OPTIONAL native enhancement over a simple web-safe baseline.
- BOW V2 — strong, aimed everyday send (beats V1; V1 retired).
- COMPASS-PULSE — the purest everyday send (just needle + pulse). The
  "floor test": can the simplest send still feel bigger than a text?

## COMPASS = FOUNDATION (not just an instrument)
- The compass is the app's HOME / identity / frame. Every send happens from
  it. Must be rock-solid. "Always know the way home."
- ALSO ships as the simplest send (compass-pulse).

## PARACHUTE (locked)
- Parachute is a great dynamic — SAVED as a reusable LANDING component.
- Rocket = its original legs-down landing (not parachute).
- Parachute reassigned to the PLANE (or shared landing library).

## PARKED (built, NO more work, un-park post-launch)
- Plane, firework, flick, emoji reveals.
- Santa gift-drop = PARKED. Do NOT start. Build it the week AFTER launch
  as the first new-content drop. (Naming it so the brain lets go.)

## THE FREEZE (the discipline that lets shipping happen)
- Finish the strong set to big + full-loop BEFORE touching anything else.
- No new instruments until the spine is proven with real users.

## THE PLAN TO SHIP
1. (DONE) 5-stage manifest + surface visibility fix
2. (DONE) Pairing audit
3. NEXT SESSION (fresh, focused): the pairing removal + link delivery
   (steps 1-5 above) — the single big job, well-rested, not late-night
4. Drive rocket/birthday/bow/compass-pulse to genuinely-big + full loop
5. Ship to ~5 real people. Learn from real sends.

## DESIGN LESSON (folded into framework)
- Instruments built on universally-understood real-world sequences
  (countdown-launch, light-the-candles, draw-and-loose) generate cleanly
  first try. Invented mechanics drift. The rocket worked because rockets
  already have a script.
- Sound is the most underweighted lever — design it as first-class bigness,
  not a per-animation afterthought.
- Full-screen takeover, no chrome leaking into reveals.
- Claude owns STRUCTURE + CONSISTENCY; you own FEEL + TASTE.

## STILL OPEN / MINOR
- Wand screen-1 art swap (needs wand_compass_face.svg moved into repo)
- Verify on device: 5-stage test lab, both rocket landings, firework +
  birthday now in Pro tab + compass selector
