#!/usr/bin/env python3
# GiftUnwrapSoundGenerator.py
# Pointward › Instruments › _Shared › EmojiReveal
#
# Generates emoji_gift_unwrap.wav — the short, warm "lid pops off" cue for the
# 🎁 reveal. Fires the instant the lid lifts away from the box. Pure Python
# standard library (no numpy/scipy), so it runs anywhere:
#
#     python3 GiftUnwrapSoundGenerator.py
#
# CHARACTER (warm + celebratory, NOT loud — ~0.5 s):
#   1. a soft paper UNWRAP rustle (a short breath of filtered noise)
#   2. a rounded POP as the lid releases (a quick down-glide blip)
#   3. a gentle SPARKLE shimmer tail (two soft detuned highs) — the little
#      burst leaving the open top
#
# Output lands in ../../../Sounds/Emoji/ where the synchronized file group
# flattens it into the bundle, alongside the other emoji_*.wav reveals.

import wave, os, math, struct, random

SR = 44100
DUR = 0.5
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "..", "Sounds", "Emoji")
NAME = "emoji_gift_unwrap"

PEAK = 0.5          # keep it gentle — warm, never loud
random.seed(7)      # deterministic output


def env(p, attack, release):
    """Linear attack/release envelope over normalized progress p (0..1)."""
    if p < attack:
        return p / attack
    if p > 1 - release:
        return max(0.0, (1 - p) / release)
    return 1.0


def synth():
    n = int(SR * DUR)
    samples = []
    lp = 0.0  # one-pole low-pass state for the rustle noise
    for i in range(n):
        t = i / SR
        p = t / DUR
        s = 0.0

        # (1) UNWRAP — a short, soft paper rustle: filtered noise, quick in/out,
        #     living mostly in the first ~140 ms.
        noise = random.uniform(-1.0, 1.0)
        lp += (noise - lp) * 0.12
        rustle_env = math.exp(-t * 22.0)
        s += lp * 0.35 * rustle_env

        # (2) POP — a rounded blip as the lid releases: pitch glides 430→150 Hz
        #     with a fast warm decay. Centered right at the start.
        pop_f = 430.0 - 280.0 * min(1.0, t / 0.12)
        pop_env = math.exp(-t * 18.0)
        s += math.sin(2 * math.pi * pop_f * t) * 0.55 * pop_env

        # (3) SPARKLE — two soft detuned highs blooming just after the pop, a
        #     little shimmer rising out of the open box.
        if t > 0.07:
            tt = t - 0.07
            shimmer = (math.sin(2 * math.pi * 1840 * t) +
                       math.sin(2 * math.pi * 2460 * t)) * 0.5
            s += shimmer * 0.16 * math.exp(-tt * 6.5) * min(1.0, tt * 12)

        # Master shaping — gentle fade in/out so nothing clicks.
        s *= env(p, attack=0.01, release=0.30)
        samples.append(s)

    # Normalize to the target peak (keeps it consistently warm, not loud).
    hi = max(1e-6, max(abs(x) for x in samples))
    scale = PEAK / hi
    return [int(max(-1.0, min(1.0, x * scale)) * 32767) for x in samples]


def write_wav(name, data):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", v) for v in data))
    print("wrote", os.path.normpath(path), f"({DUR}s, {len(data)} frames)")


if __name__ == "__main__":
    write_wav(NAME, synth())
