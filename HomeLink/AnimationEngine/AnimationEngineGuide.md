# Pointward Animation Engine Guide

This is the foundation for every send/receive animation in Pointward.
It is **declarative**: each instrument describes *what* it feels like, and the
engine figures out the rest. You almost never write animation code — you fill
in a creative brief.

> **Important:** This new system lives *alongside* the existing animation views
> (SenderAnimationView, InstrumentLandingView, the per-instrument
> *InstrumentView files, CompassView, CatchWorldBackground). Those are not
> touched. The engine is the new source of truth that the views will gradually
> read from. The rocket — and every existing animation — stays exactly as is.

---

## The files

| File | Role |
|------|------|
| `EmotionalIntent.swift` | The 5 feelings (tender, playful, powerful, magical, urgent) + their default timing/particle/glow/easing values. Also defines the shared enums: `AnimationEasingProfile`, `ParticleColorStyle`, `WorldBackground`, `SoundCategory`, `HapticPattern`. |
| `AnimationDescriptor.swift` | The struct that fully describes one animation — identity, timing, visuals, sound, haptics. Plus computed totals and `applying(_:)` for holidays. |
| `AnimationDescriptors.swift` | **The creative brief.** One `static let` per instrument with the full emotional story, wow moment, visual brief, sound brief, and exact values. Source of truth. |
| `DirectionResolver.swift` | The single place that decides direction: symbolic (unpaired, gentle rotation) vs real GPS bearing (paired). |
| `HolidayVariant.swift` | Seasonal overlays. Override only what changes; everything else inherits from the base descriptor. |
| `AnimationEngineGuide.md` | This document. |

---

## How to add a new animation (3 steps)

1. Add a case to the `Instrument` enum (`HomeLink/Models/Instrument.swift`).
2. Create a `static let` in `AnimationDescriptors.swift`.
   - Copy any existing descriptor as a template.
   - Change the values to match your vision.
   - Fill in the creative brief comments (story, wow moment, visual, sound, haptic).
   - Add it to the `descriptor(for:)` lookup `switch` so the new case resolves.
3. Add the instrument to the picker UI.

That's it. No animation code needed. The engine handles everything else.

> **Naming note:** The wind instrument is backed by the `.firefly` enum case
> (its `displayName` is `"wind"` — the case name is kept for wire-format
> stability). So `AnimationDescriptor.wind` uses `instrument: .firefly`, and
> `descriptor(for: .firefly)` returns `.wind`. Keep this mapping in mind when
> adding or renaming instruments.

---

## How to add a holiday pack (2 steps)

1. Create a `static let` in `HolidayVariant.swift`.
   - Only override what changes from base (color, particles, sound, background, taglines).
   - Leave everything else `nil` — it inherits from the base descriptor.
2. Add it to `HolidayVariant.current()` with the right month.

Done. Every existing animation gets the holiday treatment automatically, because
`descriptor.applying(variant)` rewrites only the overridden fields.

---

## How a descriptor flows through a send

```
anticipation → journey → arrival → reveal → linger
```

- **anticipationDuration** — the build-up (rocket countdown, bow draw, wand charge).
- **journeyDuration** — flight from sender toward the person's bearing.
- **arrivalDuration** — the catch on the receiver's screen.
- **revealDuration** — the emoji materializing.
- **lingerDuration** — how long it stays before clearing (default 6s).

`totalSendDuration` = anticipation + journey.
`totalReceiveDuration` = arrival + reveal + linger.

Direction for every step comes from `DirectionResolver.bearing(person:compassHeading:)`
— never read the compass heading directly inside an animation.

---

## Creative brief format

Every descriptor must carry these comment sections so the brief stays the
source of truth for designers and future sessions:

- **EMOTIONAL STORY** — when is this send used, what does it *mean*.
- **THE WOW MOMENT** — the one beat people remember.
- **SEND VISUAL BRIEF** — exact on-screen choreography for the sender.
- **RECEIVE VISUAL BRIEF** — exact on-screen choreography for the receiver.
- **SOUND BRIEF FOR AUDIO DESIGNER** — character + ElevenLabs prompts for send & arrival.
- **HAPTIC BRIEF** (where relevant) — send / arrival / reveal patterns.

Then the `static let` with the exact numeric values.

---

## Design tokens (for reference)

- Background `#0d0d14` · Card `#1e1828`
- Accent soft `#c4a8d4` · Accent mid `#7c6b8e`
- Text primary `#e8e0f0` · Text muted `#6b5f7a`
- Always dark mode. Serif for emotional text, SF Pro for functional text.

---

*Built as a foundation. The existing animations stay exactly as they are; the
engine grows beside them until the views read from it directly.*
