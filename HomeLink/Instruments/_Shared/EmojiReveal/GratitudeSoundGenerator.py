#!/usr/bin/env python3
# GratitudeSoundGenerator.py
# Pointward › Instruments › _Shared › EmojiReveal
#
# Generates emoji_gratitude.wav — the soft grateful tone for the 🙏 reveal.
# 🙏 graduated to a real .pro send (CuratedEmoji), and uses the shared BLOOM
# reveal; this is its bloom sound.
#
# Character: a warm, gentle major-chord SWELL (A major: A3 · C#4 · E4, with a
# soft octave shimmer) — slow attack, a quiet sustain, and a long graceful
# release. It reads as a held, thankful "ahh" — never sharp, never percussive.
# ~1.5s, soft (normalized to ~0.55 of full scale).
#
# Stdlib only (wave + math + struct) — no numpy/scipy. Run:
#   python3 GratitudeSoundGenerator.py
# Output:  ../../../Sounds/Emoji/emoji_gratitude.wav

import wave, math, struct, os

SR = 44100
DUR = 1.5
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "..", "Sounds", "Emoji", "emoji_gratitude.wav")

# A-major triad + a soft octave shimmer (freq, relative amplitude).
PARTIALS = [
    (220.00, 0.85),   # A3 — warm root
    (277.18, 0.70),   # C#4 — the major third (the "warmth")
    (329.63, 0.60),   # E4 — the fifth (openness)
    (440.00, 0.30),   # A4 — a gentle octave shimmer on top
]

def env(t):
    # Slow ease-in attack (0.30s), brief hold, then a long graceful release.
    attack = 0.30
    if t < attack:
        x = t / attack
        return x * x * (3 - 2 * x)            # smoothstep attack
    return math.exp(-(t - attack) / 0.70)     # long, soft release

def render():
    n = int(SR * DUR)
    samples = []
    for i in range(n):
        t = i / SR
        # A barely-there vibrato gives the held note a living, breath-like sway.
        vib = 1.0 + 0.004 * math.sin(2 * math.pi * 5.0 * t)
        s = 0.0
        for f, a in PARTIALS:
            s += a * math.sin(2 * math.pi * f * vib * t)
        samples.append(s * env(t))

    # Soft, not harsh (~0.55 peak).
    peak = max(abs(x) for x in samples) or 1.0
    gain = 0.55 / peak
    frames = bytearray()
    for x in samples:
        v = int(max(-1.0, min(1.0, x * gain)) * 32767)
        frames += struct.pack("<h", v)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print(f"wrote {os.path.normpath(OUT)}  ({DUR:.2f}s, peak gain {gain:.2f})")

if __name__ == "__main__":
    render()
