# Pointward — Session Log (latest)

## Shipped this session (built + pushed)
- Bow — visual rebuild, send/receipt live
- Plane — compass spin, NE send,
  receipt V1 (toward-viewer) + V2 (parachute),
  both in test lab, 7 sounds
- Firework 🎆 — match-to-fuse compass,
  spectacular send (small pops → 30-arm
  supernova → embers), receipt to bucket, 5 sounds
- Birthday 🎂 — full hero mechanic:
  tap-to-light send, confetti, two-stage
  MIC blow-out receipt (reuses wind mic),
  emoji from smoke → bucket, 5 sounds
  (V2; basic placeholder kept as fallback)
- 197 tests passing throughout

## NOT YET SEEN ON DEVICE
bow, plane, firework, birthday — all built, untested on hardware.

## DECISIONS PENDING DEVICE TEST
1. Plane receipt: V1 toward-viewer vs V2 parachute — pick live one
2. Firework: keep built 30-arm explosion OR rebuild screen 3 from
   firework_4screens_v2.svg (nicer screens 1/2/4, simpler explosion)
3. Birthday: confirm hero quality, esp. two-stage mic blow feel
4. Then revert ROCKET to V1 legs landing (parachute moved to plane —
   two instruments can't share mechanic)

## WORKFLOW LOCKED THIS SESSION
- Gemini draws rich SVG → save as approved spec → build prompt → Claude Code
- Mockups = static SVG only, never animated JS widgets (they crash)
- Build prompt skeleton: read files → sounds → compass → send → receipt →
  wire → build. Reuse for every instrument.
- POLISH PASS (optional, after build): give approved SVG back to Gemini,
  "make it wow / signature screen," BUT keep framework rules locked
  (canvas, ring, palette, bucket) — only boost expressive parts
  (explosion, confetti, glow, particles)
- Signature screens worth boosting: firework explosion, birthday blow-out
- Don't run full test suite on small changes; build-only
- One project per terminal block

## STILL TODO
- Commit these specs to VisualSpecs/ in the repo (Claude Code couldn't
  find them — built from inline specs all session)
- Update framework: Plane = dark sky not daySky
- Device test everything above
