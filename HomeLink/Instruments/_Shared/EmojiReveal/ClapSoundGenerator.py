#!/usr/bin/env python3
# ClapSoundGenerator.py
# Pointward › Instruments › _Shared › EmojiReveal
#
# Generates emoji_clap.wav — a single, realistic hand-clap used by the 👏 reveal.
# It fires once per clap contact (3–4 times) during the clapping animation.
#
# Character: a sharp broadband transient (the slap) with a short cupped-hand
# body resonance and a fast exponential decay — percussive, dry, ~0.22s. Warm,
# not harsh (normalized to ~0.7 of full scale).
#
# Stdlib only (wave + math + random) — no numpy/scipy. Run:
#   python3 ClapSoundGenerator.py
# Output:  ../../../Sounds/emoji_clap.wav   (Sounds/ root — same place as the
#          other emoji-reveal sounds: emoji_kiss, emoji_punch, emoji_hug, …)

import wave, math, struct, random, os

SR = 44100
DUR = 0.22
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "..", "Sounds", "emoji_clap.wav")

def render():
    n = int(SR * DUR)
    random.seed(42)                      # deterministic — same clap every build
    samples = []
    # Cupped-hand body resonances (give the noise a "hand" tone, not a hiss).
    bodies = [(900.0, 0.6), (1500.0, 0.5), (2300.0, 0.35)]
    for i in range(n):
        t = i / SR
        # Broadband noise transient — sharp attack, fast decay = the slap.
        noise = (random.random() * 2 - 1) * math.exp(-t / 0.045)
        # Damped body resonance — the cupped-palm pop.
        body = 0.0
        for f, a in bodies:
            body += a * math.sin(2 * math.pi * f * t) * math.exp(-t / 0.06)
        samples.append(noise * 0.8 + body * 0.25)

    # Normalize warm, not harsh (~0.7 peak).
    peak = max(abs(x) for x in samples) or 1.0
    gain = 0.7 / peak
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
