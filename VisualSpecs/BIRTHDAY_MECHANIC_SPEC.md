# Pointward — Birthday Cake 🎂 Mechanic (LOCKED SPEC)
**Flagship / marketing-hero mechanic. Build to spectacular quality, not placeholder.**
**Merges Copilot blow-out receipt + tap-to-light send. Source grammar: Plane + Firework modules.**

---

## The Core Idea (why this is special)

The sender's action and the receiver's action are two halves of one
birthday-wish ritual, across two phones:

- **Sender lights the candles** (tap each candle to light it)
- **Receiver blows them out** (microphone, two-stage blow)

Nobody else has a birthday message you physically light and the other
person physically blows out. This is the "wow" and the marketing story:
*"Light the candles — they blow them out."*

The send (lighting) is the inverse of the receipt (extinguishing), so the
two halves rhyme. The blow-out is the emotional payoff and the hero moment.

---

## Candle Count
**5 candles.** Reads clearly as "birthday," gives a satisfying number of
taps to light and blows to earn, without getting fiddly on a small screen.
Locked at 5.

---

## SCREEN 1 — Compass Face Idle

- Birthday cake centered inside the compass ring.
- 2-tier cake, clean minimal shapes (no heavy texture).
- 5 candles on top, all **UNLIT** (wicks visible, no flames).
- Soft idle glow behind the cake.
- No motion, no flicker, no particles.
- Instruction: "tap each candle to light it ✦"
- Background inside ring: dark sky #1a2d4a → #080e1e, clipped to circle.

Group: cake, candles (unlit), glow, compass ring.

---

## SCREEN 2 — Compass Face Charging (Lighting)

The user taps each candle one at a time to light it.

Per candle tapped:
- A warm flame blooms on that candle's wick (scale 0 → 1, soft spring).
- Soft haptic tap (HapticEngine light).
- Tiny soft sound per light (filtered noise, very short, warm).
- That flame then has a gentle idle sway 1-2°.

Progressive state:
- Counter feel: candles light in any order.
- Warm glow behind cake intensifies as more candles light.
- Tiny ember particles begin rising from lit candles.

When ALL 5 are lit:
- Cake glows warmly.
- Brief flare moment (candles flare brighter for ~0.3s).
- HapticEngine connectionFelt.
- Send fires → confetti burst handoff (Screen 3).

Instruction while lighting: "tap each candle to light it ✦"
Instruction when all lit: "make a wish ✦" (warm gold color)

Group: cake, candles (lighting), flames, embers, glow, compass ring.

---

## SCREEN 3 — Send Flight (Full Screen)

Cake leaves the compass ring, becomes full-screen. Celebratory.

- Background: deep space #080911, .ignoresSafeArea(), scattered stars.
- Candles flare brightly for a moment (peak brightness).
- Confetti burst expands outward behind/around the cake.
  - Match Firework burst TIMING but SOFTER shapes.
  - Confetti = small soft rounded rectangles/ovals, gold + lavender +
    warm white + soft pink. Tumbling rotation as they fly out.
  - NOT sharp radial spikes (that's firework's language) — birthday is
    softer, gentler, celebratory rather than explosive.
- Warm afterglow cloud remains at center after the burst.
- Cake can drift/scale slightly for energy.

Sound: soft celebratory burst (filtered noise, warmer/softer than firework).
After: finishSend pipeline (NOT EmojiRevealView(.sent)).

Group: cake, candles (flared), confetti burst, afterglow.

---

## SCREEN 4 — Receipt: The Blow-Out (HERO MOMENT)

This is the centerpiece. Build to full quality.

- Background: deep space gradient #080911 → #11162b → #1f1826.
- Cake appears above the bucket, candles still LIT, flames swaying gently.
- Bucket sits lower-right, stationary (standard wooden bucket).
- Instruction: "blow out the candles 🎂"

Microphone blow detection — reuse the WIND instrument's mic detection
pattern (wind already does mic input for the leaf; copy that approach).

TWO-STAGE BLOW:
- First blow detected: flames flicker and lean sideways (directional,
  brief). They do NOT go out yet. Flames bend in the blow direction.
- Second blow detected: flames extinguish completely.
  - Clean sequence per flame: flame → shrink → vanish → smoke puff.
  - Each candle emits a small smoke puff from the wick.
  - Smoke puff expands slightly then fades.

After extinguish:
- Emoji 🎂 revealed inside/emerging from the smoke cloud.
  - Soft, magical emergence — scale 0 → 1.2 → 1.0 spring.
  - Feels soft and magical, not abrupt.
- Emoji drifts downward into the bucket.
  - Same drift timing as other modules (plane/firework).
  - Soft sparkle trail behind the emoji (gold dots fading upward).
- On bucket catch: cyan glow rgba(80,180,240,0.2), small sparkles.
- Then EmojiRevealView(.received).

Group: cake, candles, flames, smoke puffs, emoji, sparkles, bucket.

---

## Animation Notes (locked)

- Candle flame idle sway: 1-2° gentle, only when lit.
- Lighting bloom: each flame scale 0 → 1 soft spring on tap.
- Flame flicker on FIRST blow: directional and brief, flames lean.
- Extinguish on SECOND blow: clean — flame → shrink → vanish → smoke puff.
- Smoke puff: expand slightly, then fade.
- Emoji reveal: soft and magical, emerging from smoke.
- Emoji descent: same drift timing as other modules.
- Confetti burst (Screen 3): match Firework burst timing, SOFTER shapes.

---

## Sound Rules (per framework)

- All filtered noise. Birthday blow-out can use the chime exception
  ONLY for the final all-out / reveal moment (gentle, soft).
- Per-candle light: tiny soft warm puff (filtered noise, short).
- First blow: breath/wind noise (filtered, like wind instrument).
- Second blow / extinguish: breath noise + soft smoke hiss.
- Confetti burst: soft celebratory (filtered noise, warmer than firework).
- Emoji reveal: gentle magical shimmer.

---

## Versioning

- The existing basic placeholder reveal (cake blooms, candles shrink,
  confetti, bounce — from the "all 9 placeholders" run) stays as the
  simple fallback.
- THIS spec is the real birthday mechanic — build as the full version.
- Both available in test lab; user decides on device which goes live.

Test lab entries:
  ("🎂", "Birthday Send", .compass)
  ("🎂", "Birthday Receipt", .compass)
  ("🎂", "Birthday Compass", .compass)

---

## What to hand Gemini

Gemini designs ONLY the visual look of the 4 screens — the cake, candles,
flames, smoke, confetti. The mechanic above is already locked; Gemini does
not decide interaction or timing. Ask Gemini for:
- Screen 1: cake with 5 unlit candles, dark sky inside compass ring
- Screen 2: cake with candles lighting, warm glow, embers rising
- Screen 3: full-screen cake with soft confetti burst + afterglow
- Screen 4: cake above bucket, candles lit/leaning, smoke puffs, emoji in smoke

Framework rules (canvas 393×852, compass cx196 cy392 r148, palette,
wooden bucket lower-right with 3 staves + brass band) all still apply.
