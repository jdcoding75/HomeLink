# Pointward — Session Log (latest)

## Shipped this session (built + pushed)
- Bow — visual rebuild, send/receipt live
- Plane — compass spin, NE send,
  receipt V1 (toward-viewer) + V2 (parachute),
  both in test lab, 7 sounds
- Firework 🎆 — match-to-fuse compass,
  spectacular send (small pops → 30-arm
  supernova → embers), receipt to bucket,
  5 sounds
- Birthday 🎂 — full hero mechanic:
  tap-to-light send, confetti, two-stage
  MIC blow-out receipt (reuses wind mic),
  emoji from smoke → bucket, 5 sounds
  (V2; basic placeholder kept as fallback)
- 197 tests passing throughout

## NOT YET SEEN ON DEVICE
bow, plane, firework, birthday — all
built but untested on hardware.

## DECISIONS PENDING DEVICE TEST
1. Plane receipt: V1 toward-viewer vs
   V2 parachute — pick live one
2. Firework: keep built 30-arm explosion
   OR rebuild screen 3 from
   firework_4screens_v2.svg (nicer
   screens 1/2/4, simpler explosion)
3. Birthday: confirm hero quality,
   esp. two-stage mic blow feel
4. Then revert ROCKET to V1 legs landing
   (parachute moved to plane — two
   instruments can't share mechanic)

## WORKFLOW LOCKED THIS SESSION
- Gemini draws rich SVG → save here as
  approved spec → build prompt → Claude Code
- Mockups = static SVG only, never animated
  JS widgets (they crash)
- Build prompt skeleton: read files →
  sounds → compass → send → receipt →
  wire → build. Reuse for every instrument.
- POLISH PASS (optional, after build):
  give approved SVG back to Gemini,
  "make it wow / signature screen," BUT
  keep framework rules locked (canvas,
  ring, palette, bucket) — only boost
  expressive parts (explosion, confetti,
  glow, particles)
- Signature screens worth boosting:
  firework explosion, birthday blow-out
- Don't run full test suite on small
  changes; build-only
- One project per terminal block

## VISUAL SPECS (in chat outputs, commit to repo)
bow_4screens.svg, plane_4screens_APPROVED.svg,
firework_4screens.svg, firework_4screens_v2.svg,
birthday_4screens_APPROVED.svg,
POINTWARD_ANIMATION_FRAMEWORK.md,
BIRTHDAY_MECHANIC_SPEC.md

## STILL TODO
- Commit visual specs to VisualSpecs/ folder
  (Claude Code couldn't find them — built
  from inline specs all session)
- Update framework: Plane = dark sky not daySky
- Device test everything above

## ── Session 7 lock-down — UNRUN QUEUE (pick up here) ──

FIRST MOVE WHEN BACK (two-tab flag — verify before stacking runs):
  cd ~/Developer/HomeLink && git status && git log --oneline -8
  Confirm clean tree + both builds' commits landed.

RUN ORDER (one at a time, each pushes before next; all touch manifest):
  finish running build → plane receipt → firework master → bow send arc

NOT-YET-RUN PROMPTS:
1. PLANE RECEIPT V2 (continuity): plane from send reappears at TOP of
   receipt traveling across (continuous flight, not fresh start);
   parachute releases QUICKLY from top-left, timed to OVERLAP plane
   travel; rest of receipt unchanged. V2 only, animation-only.
2. FIREWORK MASTER (combined):
   [1] Compass: after match-to-fuse initiates, fuse lights + visibly
       burns DOWN inside compass face before send fires. filtered-noise
       only, keep match-to-fuse interaction.
   [2] Receipt: DELETE bucket + square-drop. Keep post-burst glow as
       backdrop. Show message/emoji BIG + CLEAR over glow (shared
       EmojiReveal). burst→glow→message = one beat.
3. BOW SEND ARC: bigger arc, start LOWER in screen, longer path, exit
   point matching BowReceiptAnimationV2 entry; LENGTHEN path (don't just
   slow); art/draw/sounds unchanged. V2 only.

VERIFY LANDED: wand crystal-compass image swap; compass unpaired receipt.

## ── LOCK LEDGER (session 7 end) ──
LOCKED: wind compass · compass screen+send · birthday compass V2 ·
  bow compass V2 + receipt V2 · plane compass V2 + send V2 · firework send
ONE TWEAK→LOCK: flick (built,review) · birthday master (running) ·
  plane receipt · firework compass+receipt · bow send · rocket receipt ·
  wind send/receipt · wand image · compass receipt
DEFERRED TO PIVOT: birthday auto-blow-out baseline + download prompt ·
  catchMode/bucket-catch removal (w/ pairing removal + link delivery)
BUCKET PRINCIPLE: thrown-object sends keep bucket; THOUGHTS (everyday)
  + CARD/CELEBRATION (birthday, firework) = NO bucket. Confirmed
  no-bucket: birthday, firework.
PARKED: Santa.
