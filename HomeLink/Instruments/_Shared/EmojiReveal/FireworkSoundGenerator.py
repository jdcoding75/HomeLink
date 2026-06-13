#!/usr/bin/env python3
# FireworkSoundGenerator.py
# Pointward > Instruments > _Shared > EmojiReveal
#
# Generates the soft "reveal sparkle" SFX that plays UNDER the firework
# receipt's message-reveal portion (after the opening burst). Pure Python
# standard library only (wave + math + struct + random) — no numpy/scipy.
# Run:  python3 FireworkSoundGenerator.py
#
# NOTE: the firework BURST sounds (firework_big_burst, firework_launch,
# firework_small_pops, firework_sparkle) are pre-existing external assets in
# Sounds/Emoji/ — this script does NOT touch them. It only writes the new
# firework_reveal_sparkle.wav.
#
# CHARACTER:
#   A gentle, magical twinkle bed — a scatter of soft high "ting" sparkles
#   (bell-like sine pings with quick decays) over a faint airy shimmer. Quiet
#   and warm, never loud or harsh; it sits softly beneath the 🎆 bloom + the
#   "from … ✦" message and resolves before the EmojiRevealView handoff.
#
# DURATION: 1.5s (covers bloom 1.1s → handoff 2.6s in FireworkReceipt).

import wave, os, math, struct, random

SR = 44100
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "..", "Sounds", "Emoji")   # alongside firework_*


def _write(name, samples):
    """Write a list of floats in [-1, 1] as 16-bit mono PCM."""
    path = os.path.join(OUT, name + ".wav")
    frames = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s)) * 32767)
        frames += struct.pack("<h", v)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print("wrote", os.path.normpath(path),
          f"({len(samples)/SR:.2f}s, peak {max(abs(x) for x in samples):.3f})")


def _normalize(samples, peak):
    m = max(abs(x) for x in samples) or 1.0
    g = peak / m
    return [x * g for x in samples]


def synth_reveal_sparkle(secs=1.5):
    n = int(SR * secs)
    out = [0.0] * n
    rng = random.Random(21)           # deterministic twinkle pattern

    # ── A scatter of soft bell "ting" sparkles ──────────────────────────────
    # Each ting is a short sine ping (with a faint shimmer partial) that decays
    # quickly. They start across the window and thin out toward the end so the
    # bed gently resolves into silence before the reveal handoff.
    t = 0.05
    while t < secs - 0.15:
        f = rng.uniform(1300, 3400)              # bright, but not piercing
        amp = rng.uniform(0.35, 0.8)
        dec = rng.uniform(14, 26)                # quick, bell-like decay
        shimmer = rng.uniform(1.98, 2.02)        # near-octave shimmer partial
        start = int(t * SR)
        dur = int(0.45 * SR)
        for k in range(dur):
            idx = start + k
            if idx >= n:
                break
            lt = k / SR
            e = math.exp(-lt * dec)
            s = (math.sin(2 * math.pi * f * lt)
                 + 0.4 * math.sin(2 * math.pi * f * shimmer * lt)) * e
            out[idx] += s * amp
        # later sparkles get a little sparser (gentle resolve)
        gap = rng.uniform(0.07, 0.16) * (1 + t * 0.5)
        t += gap

    # ── A faint airy shimmer bed (very quiet high noise, slowly fading) ──────
    hp_prev = 0.0
    for i in range(n):
        x = rng.uniform(-1.0, 1.0)
        hp = x - hp_prev                          # crude high-pass → airy
        hp_prev = x
        fade = max(0.0, 1.0 - i / n)              # fades out over the window
        out[i] += hp * 0.05 * fade

    return _normalize(out, 0.13)                  # gentle, magical, NOT loud


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    _write("firework_reveal_sparkle", synth_reveal_sparkle(1.5))
