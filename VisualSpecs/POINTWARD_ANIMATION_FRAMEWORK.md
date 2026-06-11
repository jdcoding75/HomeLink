# Pointward Animation Framework
**Version 1.0 — merged from Copilot framework + Claude session learnings**
**Source of truth: Wind and Rocket instruments**

---

## 1. Core Principles

| Rule | Detail |
|------|--------|
| Source of Truth | Wind and Rocket are the two approved mechanisms. All future mechanisms must follow their visual grammar, animation grammar, and structural format exactly. |
| No Invention | Do NOT invent new props, textures, shadows, lighting, backgrounds, silhouettes, or color palettes. |
| Interpretation | Extract structure from references — do not reinterpret. Examples are templates, not inspiration. |
| If Unsure | Match Wind and Rocket. Simpler rule wins. |
| If Conflict | If Wind and Rocket differ, choose the simpler or more universal rule. |
| Framework Updates | Framework may only be updated when user explicitly says "update the framework" or when a new approved mechanism is added. |

---

## 2. Approved Mechanisms (Source of Truth)

### Wind ✅ APPROVED
- Compass face: leaf inside ring, daySky background inside circle
- Send: leaf travels full screen, lazy S-curve, dandelion seeds
- Receipt: leaf enters, drifts to bucket, emoji reveals
- Background: daySky `#1a3a5c → #7ec8e3`
- Sound: soft wind, no harsh sounds

### Rocket ✅ APPROVED  
- Compass face: rocket fueling mechanic
- Send: blast off, full screen launch
- Receipt: parachute descent v2, earth horizon, lands in bucket
- Background: deepSpace `#000008 → #0d0d20`
- Sound: countdown, launch, descent

### All 9 Emoji Reveals ✅ APPROVED
- Registry: RevealAnimationRegistry.swift
- Sounds: filtered noise only, no sine waves
- Background: matches instrument ambient

---

## 3. Visual Grammar (locked — derived from Wind + Rocket)

### Backgrounds
```
Inside compass ring:
  instrument world background only
  clipped with clipShape(Circle())

Outside compass ring:
  ALWAYS deep purple #0d0d14 → #12101c
  No exceptions

Send/Receipt full screen:
  instrument world background
  full screen, ignoresSafeArea()
```

### Background Library (approved)
```
daySky:      #1a3a5c → #7ec8e3  (Wind, Plane)
deepSpace:   #000008 → #0d0d20  (Rocket)
deepPurple:  #0d0d14 → #12101c  (Compass)
magicalDark: #0d0b18 → #150f28  (Wand)
corkBoard:   #2a1f12 → #3d2e1a  (Flick)
ethereal:    #ffffff → #e7ecf8  (Bow)
```

### Glow Rules
```
Glow radius, softness, and color
must match Wind and Rocket exactly.
No new glow styles.
Particle glow: rgba(196,168,212, x)
Gold trail glow: rgba(212,160,48, x)
Bucket catch glow: rgba(80,180,240,0.2)
```

### Silhouette and Scale
```
Instrument object sits centered
inside compass ring.
Scale: fills roughly 60% of ring
diameter.
Same padding approach as Wind leaf
and Rocket capsule.
```

### Color Palette (locked)
```
Base background:   #0d0d14
Card:              #1e1828
Border:            #3a3050
Accent lavender:   #c4a8d4
Text primary:      #e8e0f0
Text secondary:    #9b8fa8
Text muted:        #6b5f7a
Gold trail:        #d4a030
Bucket catch cyan: rgba(80,180,240,0.2)
```

---

## 4. Animation Grammar (locked)

### Timeline Structure
```
Every mechanism uses this structure:

0%   — idle/rest state
25%  — charging/tension building
50%  — launch/release moment
75%  — mid-flight/transit
100% — landing/resolution
```

### Easing Curves
```
Instrument launch:  easeIn (cubic)
Flight arc:         linear with
                    sin curve for
                    vertical arc
Approach bucket:    easeInOut
Bucket catch:       spring(response:0.35,
                    damping:0.5)
Needle settle:      spring(response:0.8,
                    damping:0.55)
Screen transitions: easeOut(0.35)
```

### Motion Arcs
```
Send flight path:
  Entry: from sendEntryPoint
  (InstrumentTransition)
  Arc: sin(p * π) * -peakHeight
  Peak: screen center
  Exit: exitBearing * 1.15 of screen

Receipt path:
  Entry: left edge or top
  Arc: smooth bezier to bucket
  No phase breaks or hesitation
  Single continuous motion
```

### Particles
```
Behavior matches Wind seeds and
Rocket exhaust exactly:
  Spawn: continuous during flight
  Count: 20 max (standard)
  Fade: easeOut over 0.4s
  Drift: ±12pt from flight path
  Colors: gold #d4a030 or white only
  No color particles
  No solid lines — scattered dots
```

### Screen Coordinate Rules (ALL 6 — never violate)
```
1. GeometryReader as outermost root
2. .ignoresSafeArea() on background
3. All positions from geo.size only
4. Swirl/flight center = geo.size/2
5. Entry/exit at geo.size * 1.15
6. Bucket: bx = width-80,
           by = height - 95
```

---

## 5. Wooden Bucket Spec (shared asset)

```
Position:
  bx = geo.size.width * 0.68
  by = geo.size.height - 105
  (approximately — use geo.size)

Exact pt values:
  bx = 268pt
  by = 747pt
  width = 120pt
  height = 100pt

Wood colors:
  dark:  #4a2e10
  mid:   #7a4e28
  light: #6a3e1e

Stave lines: 3 only (no more)
Brass band:  1 horizontal
             #5a4010 → #d4a030
Top rim:     ellipse, brass gradient
Handle:      arc above rim, brass
Shadow:      subtle ellipse below

On catch:
  cyan glow inside
  rgba(80,180,240,0.2)
  emoji visible inside bucket
  before EmojiRevealView
```

---

## 6. Sound Rules (locked — never violate)

```
Impact/explosion/punch:
  Filtered noise ONLY
  Zero sine waves

Chimes allowed ONLY for:
  💭 thought bubble
  💌 envelope

All sounds via EmojiRevealSound
Never legacy SoundEngine for reveals

Volume: soft and gentle
Nothing harsh or loud
All sounds match instrument world
```

---

## 7. File Structure (every instrument)

```
Instruments/[Name]/
  [Name]CompassFace.swift   ← interactive mechanic
  [Name]SendAnimation.swift ← full screen send
  [Name]ReceiptAnimation.swift ← full screen receipt
  [Name]Sounds.swift        ← sound file refs
  [Name]SoundsV2.swift      ← if updated

Versioning:
  V1 = original, always kept
  V2 = new version
  V1 stays wired in live app
  until explicitly upgraded
  Both appear in test lab
```

---

## 8. Wiring Rules (never break)

```
Compass face:
  Interactive mechanic — NEVER
  rewrite to static art
  Gemini/visual styles live in
  send/receipt only

Send dispatch:
  SenderAnimationView.swift
  hands back to finishSend pipeline
  NOT EmojiRevealView(.sent)

Receipt dispatch:
  ReceiptView.swift
  NOT InstrumentLandingView
  (except test lab)

After receipt:
  EmojiRevealView(.received)
  using instrument ambient background
```

---

## 9. Mechanism Output Template

Every new mechanism must produce:

```
1. Overview
   What the instrument is,
   what world it lives in,
   what the mechanic feels like

2. Visual Breakdown
   Object silhouette (derived from
   Wind/Rocket grammar)
   Glow style
   Particle style
   Composition

3. Animation Timeline
   0% / 25% / 50% / 75% / 100%
   keyframes

4. Particle Behavior
   Spawn, fade, drift, glow
   matching Wind/Rocket rules

5. Glow Behavior
   Pulse timing and amplitude
   matching Wind/Rocket rules

6. Sound Hooks
   File names, trigger points,
   filtered noise specs

7. Developer Notes
   Constraints, edge cases,
   wiring instructions
```

---

## 10. Status Registry

```
✅ APPROVED + SHIPPED:
Wind          — complete
Rocket v2     — complete (parachute)
Emoji Reveals — all 9, approved

⚠️ IN PROGRESS (V1 active):
Bow           — V1 wired, V2 partial
Flick         — V1 wired, V2 partial
Wand          — compass works,
                send cut scene missing
Plane         — V1 exists, needs polish

❌ NOT STARTED:
Future instruments TBD
```

---

## 11. What Is Forbidden

```
Do not add:
- New props not in Wind/Rocket
- Shadows under bucket
- Floors, tables, environments
- New lighting sources
- New background types
- New color palettes
- New glow styles
- New particle types
- Sine waves in impact sounds
- Animated JS widgets in chat
  (crashes Claude)
- Rewriting compass face mechanics
  to static art
```

---

*This framework wins over any individual session instruction.
When in doubt: match Wind and Rocket.*

---

## ANIMATION SPEC STANDARD (required for all NEW animation builds)
*Added after the device-review sessions. These exist so the person briefing
a build doesn't have to hand-specify motion each time — every build prompt
and every Gemini brief should conform to these by default.*

### 1. Canonical stages (5) — the single stage vocabulary everywhere
Every animation is described in these stages. The manifest, the test lab, the
compass selector, the Pro tab, and history ALL use these names. No "Reveal"
stage — it was retired.
1. **Compass Idle** — the resting mechanism (unlit candles, undrawn bow)
2. **Compass Charging** — the mechanism IN ACTION (candles lighting, fuse
   burning, bow drawing). This is the interaction playing out, not the idle face.
3. **Send** — the send-off / launch / the big moment
4. **Approach** — the payload travelling in (arrow flying, plane approaching,
   parachute descending)
5. **Target** — the payload arriving/landing (into the bucket, settling)
An animation only declares the stages it actually has; not all have all five.

### 2. Motion timeline is part of the spec (not left to interpretation)
The #1 cause of build drift was specifying APPEARANCE (a static SVG) but leaving
MOTION to interpretation. Every animation stage must specify, in the spec/prompt:
- phase breakdown with timing in seconds (e.g. 0–0.4s launch, 0.4–1.5s burst)
- what moves from where to where
- easing/feel per phase (spring vs ease-out; gentle vs snappy)
- what fades in/out and when
Prefer explicit timeline-driven motion over emergent physics — it generates
more reliably and avoids "expression too complex."

### 3. Each animation declares its REVEAL METAPHOR
Delivery/reveal is abstracted, not fixed. Each animation names how the message
is revealed (envelope, glow, card slide, spark, lantern, bucket-catch, etc.).
The delivery object is a flexible component, not a hardcoded asset.

### 4. Modular + composable
Build from small reusable pieces (a flame, a particle emitter, the shared
compass ring, the shared bucket) composed together — never one monolithic view.
Shared graphics (compass ring, bucket) have ONE source of truth.

### 5. Web-safe-able by default (forward-looking)
NEW animations should be designed so they could later render in web tech
(Lottie/CSS/light WebGL): simple metaphors, lightweight assets, predictable
timing. Native-only effects (haptics, mic, device-motion) are OPTIONAL
ENHANCEMENTS layered on a web-safe baseline — never the core mechanic the
animation depends on. (Existing native animations are grandfathered — this
is for new work, not a mandate to rebuild what exists.)

### 6. Sender-rich, receiver-simple (asymmetry is intentional)
The SENDER performs the ritual (the intentional "I made this for you" act).
The RECEIVER gets a simple, predictable reveal. Do not build receiver-side
game/catch mechanics that require synchronous interaction. (Exception kept on
purpose: birthday candle blow-out, as an OPTIONAL native enhancement over a
simple baseline reveal.)

---

## ANIMATION SPEC STANDARD (required for all NEW animation builds)

### 1. Canonical stages (5) — the single stage vocabulary everywhere
1. Compass Idle — the resting mechanism (unlit candles, undrawn bow)
2. Compass Charging — the mechanism IN ACTION (candles lighting, fuse burning, bow drawing)
3. Send — the send-off / launch / the big moment
4. Approach — the payload travelling in (arrow flying, plane approaching, parachute descending)
5. Target — the payload arriving/landing (into the bucket, settling)
An animation only declares the stages it actually has; not all have all five. The manifest, test lab, compass selector, Pro tab, and history ALL use these names. No "Reveal" stage — retired.

### 2. Motion timeline is part of the spec (not left to interpretation)
Every animation stage must specify: phase breakdown with timing in seconds; what moves from where to where; easing/feel per phase; what fades in/out and when. Prefer explicit timeline-driven motion over emergent physics — it generates more reliably and avoids "expression too complex."

### 3. Each animation declares its REVEAL METAPHOR
Reveal is abstracted, not fixed. Each animation names how the message is revealed (envelope, glow, card slide, spark, lantern, bucket-catch). The delivery object is a flexible component, not a hardcoded asset.

### 4. Modular + composable
Build from small reusable pieces (flame, particle emitter, shared compass ring, shared bucket) composed together — never one monolithic view. Shared graphics have ONE source of truth.

### 5. Web-safe-able by default (forward-looking)
NEW animations should be designed to later render in web tech (Lottie/CSS/light WebGL): simple metaphors, lightweight assets, predictable timing. Native-only effects (haptics, mic, device-motion) are OPTIONAL ENHANCEMENTS over a web-safe baseline — never the core mechanic. Existing native animations are grandfathered.

### 6. Sender-rich, receiver-simple (asymmetry is intentional)
The SENDER performs the ritual. The RECEIVER gets a simple, predictable reveal. No receiver-side game/catch mechanics requiring synchronous interaction. Exception kept on purpose: birthday candle blow-out, as an optional native enhancement over a simple baseline.
