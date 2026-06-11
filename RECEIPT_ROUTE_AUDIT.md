# JOB 1 — RECEIPT ROUTES + STAGE-MODEL AUDIT (2026-06-11)
*Report only — no code changed in this job.*

## A. The two receipt routes, per instrument

LIVE RECEIVE = `ReceiptView` → `<Instrument>ReceiptAnimation`.
LANDER PATH  = `Views/InstrumentLandingView.swift` → `<Instrument>Landing` struct.

| Instrument | live-receive receipt (ReceiptView) | lander Landing struct (InstrumentLandingView) | what the TEST LAB calls today | both selectable? |
|---|---|---|---|---|
| **Rocket** | `RocketReceiptAnimation` (PARACHUTE) | `RocketLanding` (LEGS-down) | `RocketReceiptAnimation` (parachute) **only** | ❌ **NO** — legs-down unreachable in lab |
| **Bow** | `BowReceiptAnimationV2` (live) | `ArrowLanding` | V1 → `ArrowLanding` (lander) · V2 → `BowReceiptAnimationV2` | ✅ YES (V1=lander, V2=live) |
| **Flick** | `standardReceipt` (shared spin-catch) | `PostItLanding` | V1 → `PostItLanding` (lander) · V2 → `FlickReceiptAnimationV2` | ⚠️ lander+V2 yes; the live `standardReceipt` is not a lab entry |
| **Plane** | `PlaneReceiptAnimation` (V1 toward-viewer) | `PlaneLanding` | V1 → `PlaneReceiptAnimation` (live) · V2 → `PlaneReceiptAnimationV2` | ⚠️ two live versions yes; lander `PlaneLanding` unreachable |
| **Wand** | `standardReceipt` (shared spin-catch) | `WandLanding` | `WandLanding` (lander) only | ⚠️ only lander; live spin-catch not a lab entry |
| **Leaf/Wind** | `WindReceiptAnimation` (live) | `LeafLanding` | `WindReceiptAnimation` (live) only | ⚠️ only live; lander `LeafLanding` unreachable |

**Headline:** Rocket's two genuinely-distinct receipts (parachute live vs
legs-down lander) — only the parachute is selectable in the lab. Same shape for
Plane (PlaneLanding lander hidden) and Leaf/Wind (LeafLanding lander hidden).

## B. Bow / Flick / Plane — V1 + V2 send/receipt on disk vs registered

Files on disk: `BowSendAnimationV1/V2`, `BowReceiptAnimationV1/V2`, and the same
for Flick + Plane (Plane also has non-versioned `PlaneSendAnimation` /
`PlaneReceiptAnimation`). The **V1 files are RETIRED marker enums** (not
renderable Views); the V1 animation is the inline dispatcher path
(`SenderAnimationView` for send, the lander struct for receipt). The **V2 files
are real full-screen Views**.

| | V1 in manifest? | V1 plays as | V2 in manifest? | V2 plays as |
|---|---|---|---|---|
| Bow   | ✅ | send=inline SenderAnimationView · receipt=`ArrowLanding` | ✅ | `BowSendAnimationV2` · `BowReceiptAnimationV2` |
| Flick | ✅ | send=inline · receipt=`PostItLanding` | ✅ | `FlickSendAnimationV2` · `FlickReceiptAnimationV2` |
| Plane | ✅ | send=`PlaneSendAnimation` · receipt=`PlaneReceiptAnimation` | ✅ | `PlaneSendAnimationV2` · `PlaneReceiptAnimationV2` |

→ V1 AND V2 ARE registered + selectable in the test lab (fixed in a prior task).
The V2 work IS reachable. Good.

## C. Current stage model — the double-play problem

The manifest currently uses **5 stages**: Compass Idle · Compass Charging · Send
· Approach · Target, with a `Stage.source` (compass / send / receipt).

- **Compass performed TWICE:** "Compass Idle" and "Compass Charging" are two
  separate selectable chips, and BOTH render the same interactive compass face
  (`compassStage`). So a user tapping each does the mechanic twice. (The Full
  Workflow dedups by source, so there it plays once — but the per-stage chips
  duplicate.)
- **Receipt motion shown TWICE:** "Approach" and "Target" are two chips, and
  BOTH render the same receipt animation (`receiptStage`, which already plays
  approach→target internally). So selecting each replays the same motion. (Full
  Workflow dedups to one.)

## D. Firework match-to-fuse — why the send doesn't initiate

Chain: drag match within 42pt of `fuseTip` → `ignite()` (lit=true, litAt set,
fuse-burn sound) → `burnProgress` ramps 0→1 → `.onChange(of: burn){ if ≥1 fire() }`
→ `fire()` → `onSend()`.

**Bug:** `.onChange(of: burn)` is attached to a view **inside the
`TimelineView { timeline in … }` content closure**, where `burn` is a per-tick
local `let`. onChange's cross-update value tracking is unreliable for a value
recomputed inside the timeline subtree, so the 1.0 crossing is missed and
`fire()` (hence `onSend()`) never runs — the fuse visibly burns but the send
never initiates. The lighting itself works; the **burn→send handoff is the
broken link.** Fix = drive `fire()` off a guaranteed timer set in `ignite()`
(`asyncAfter(burnDuration)`), keeping the guarded `fire()` so there's no double
send; optionally loosen the 42pt hit radius.

## E. Surfaces (manifest readership)
- **Test lab** → reads `AnimationManifest.all`. ✅
- **Pro tab / compass selector / history** → per-instrument (no V1/V2 concept);
  all 7 instruments present; firework+birthday signature section added (prior
  task). ✅ Complete for their semantics.

---

# JOB 2 plan (from the above)
1. Stage model → **3 stages**: Compass (one watchable rest→action), Send,
   Receipt (one continuous approach→landing). Full Workflow chains them.
2. Rocket → register **two** receipts: "Rocket Parachute" (RocketReceiptAnimation)
   + "Rocket Legs-down" (RocketLanding via InstrumentLandingView).
3. Bow/Flick/Plane → V1+V2 stay registered (now 3 stages); both routes already
   exposed (bow/flick: lander V1 + live V2; plane: two live versions).
4. Firework → guaranteed burn→`fire()` timer in `ignite()`.
5. Re-verify all surfaces read the manifest.
