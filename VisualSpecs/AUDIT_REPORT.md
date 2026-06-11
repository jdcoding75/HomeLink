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

---

# JOB 1B — Surface Visibility Audit (2026-06-11)

Goal: every built animation appears on every surface; no surface keeps its own
hand-maintained list. Source of truth = AnimationManifest.

| Surface | Source it uses | Status before | Action |
|---|---|---|---|
| **Test Lab** | `AnimationManifest.all` | ✅ already manifest-driven (job 1A) | none — verified shows all 13 defs × 5-stage |
| **Instrument picker** (compass long-press → `InstrumentOptionPicker`) | `InstrumentOption.allCases` | ✅ all 7 instruments present (1 free + 6 pro) | verified — not missing any |
| **Compass emoji/feeling grid** (CompassView, full grid) | `CuratedEmoji.all` (base + proAnimated + pro + occasion) | ✅ firework 🎆 + birthday 🎂 already present (in `proAnimated`, gated pro) | verified — the full grid shows every curated emoji incl. the signature mechanics |
| **Pro tab** (`ProSetupView`) | `InstrumentOption.allCases` (instruments only) | ❌ firework + birthday MISSING (no emoji-mechanism showcase) | **FIXED** — added `signatureAnimationsSection`, read from `AnimationManifest.emoji` (distinct → Firework + Birthday Cake) |
| **History / replay** (`ReplaySwipeContainer`, PersonDetailView) | `RevealAmbient.forStyle(senderStyle)` + EmojiRevealView | ✅ replays any received thought with the correct world; emoji-mechanic pings (🎆/🎂) replay via their emoji glow | verified — replay is animation-type agnostic |

## What was missing
- ONLY the Pro tab omitted the firework + birthday signature mechanisms. Fixed
  by sourcing a new "signature animations" section from the manifest.

## Notes / scope
- The instrument picker and emoji grid were already complete (they happened to
  list everything via `InstrumentOption.allCases` / `CuratedEmoji.all`). The
  earlier impression that "nearly none appear" maps to the FREE-tier *quick*
  send row (which intentionally shows only the core feelings for free users);
  the full grid behind it shows all, so nothing built is unreachable. Left the
  free-tier quick row as-is (product gating, not a visibility bug).
- A literal "every surface reads AnimationManifest directly" refactor of the
  product picker/grid was NOT done where those surfaces already show everything
  via their own complete enums — rewiring them risks free/pro gating with no
  visibility gain. The manifest is now the source for the test lab AND the Pro
  tab signature section; the other surfaces were audited and confirmed complete.
