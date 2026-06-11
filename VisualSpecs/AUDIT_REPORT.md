# PHASE 0 — Surface Audit (2026-06-11)

Live wiring traced through CompassView (send), ReceiptView (receipt),
InstrumentLandingView (test-lab/replay land), AnimationTestLabView.

| Instrument | Compass face (live) | Send (live) | Receipt (live) | V1/V2 status |
|---|---|---|---|---|
| **Wind** 🌬️ | WindCompassFace | WindSendAnimation | WindReceiptAnimation | single, approved ✅ |
| **Rocket** 🚀 | RocketCompassFace | SenderAnimationView (glow flight) | RocketReceiptAnimation (parachute) | parachute live; `RocketLanding` (legs) defined but **orphaned** in InstrumentLandingView |
| **Bow** 🏹 | BowCompassFace (dark sky) | BowSendAnimationV2 | BowReceiptAnimationV2 | **V2 live**; V1 enums **unreferenced** (retire) |
| **Flick** 👆 | FlickCompassFace | SenderAnimationView (V1) | standardReceipt (V1 spin-catch) | V1 live; V2 = test-lab only |
| **Plane** ✈️ | PlaneInstrumentView (top-down, dark sky) | PlaneSendAnimation | PlaneReceiptAnimation (toward-viewer V1) | V1 live; V2 parachute = test-lab only |
| **Wand** 🪄 | WandCompassFace (shake/charge) | WandSendAnimation | standardReceipt (V1) | compass+send live |
| **Compass** 🧭 | compassFace | SenderAnimationView (glow) | OrbLanding (via standard) | single |
| **Birthday** 🎂 | BirthdayCakeCompassFace (emoji intercept) | BirthdayCakeSendAnimationV2 | BirthdayCakeReceiptV2 | V2 live; V1 fallback kept |
| **Firework** 🎆 | FireworkCompassFace (emoji intercept) | FireworkSendAnimation | FireworkReceipt | single |

## Dispatch facts
- **Send** (CompassView): firework/birthday/wand/bow/plane intercepted; everything else → SenderAnimationView.
- **Receipt** (ReceiptView): emoji 🎂/🎆 intercepted first; then style firefly/rocket/bow/plane; else standardReceipt (flick/wand/compass/glow).
- **Land** (InstrumentLandingView): rocket→RocketReceiptAnimation(parachute); firefly/flick/bow/wand/plane→inline V1 landings; default→OrbLanding.

## Findings actioned this pass
- **Bow V1** (`BowSendAnimationV1`, `BowReceiptAnimationV1`) — unreferenced. Retire (comment out body, keep file). ✅
- **Rocket** — `RocketLanding` (legs) orphaned. Wire it back into InstrumentLandingView.rocket; keep parachute (RocketReceiptAnimation) live in ReceiptView. Both landings wired + kept. ✅

## Polish fixes (Phase 3) — targets
1. Plane send — remove duplicate emoji below plane (keep cockpit), center plane/prop.
2. Bow V2 receipt — arrow STICKS at impact, emoji drops, no reposition.
3. Flick V2 receipt — bounce magnitude −30%.
4. Fist bump — fists touch, never cross.
5. Firework compass (send + receipt-compass) — match starts top-left, drag down to fuse; remove non-functional top fuse string.
6. Birthday — render custom cake art (not 🎂 glyph) at reveal + bucket; data stays 🎂.
7. Wand screen 1 — **BLOCKED**: `VisualSpecs/wand_compass_face.svg` does not exist in repo or files.zip. Skipped per framework "no invention". Needs the SVG to proceed.

## NOT done here
- Phase 1 structural restructure (separate tab).
