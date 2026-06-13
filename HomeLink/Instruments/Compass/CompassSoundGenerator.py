#!/usr/bin/env python3
# CompassSoundGenerator.py
# Pointward > Instruments > Compass
#
# Generates compass_send.wav / compass_receipt.wav with REAL synthesized
# audio. Pure Python standard library only (wave + math + struct + random) —
# no numpy/scipy, so it runs anywhere. Run:  python3 CompassSoundGenerator.py
#
# CHARACTER (per the creative brief in CompassSounds.swift):
#   SEND    — a very soft, gentle departure: an airy breath/whoosh that swells
#             then drifts away, with a faint low tone gliding down in pitch so
#             it feels like a thought leaving. Intimate, peaceful, unobtrusive.
#   RECEIPT — a very soft, warm arrival: a gentle singing-bowl / bell chime
#             with a soft sub for body and a consonant companion partial, a
#             quick soft strike then a long warm decay. A warm welcome.
#
# DURATIONS (kept in sync with CompassSounds.swift):
#   compass_send.wav     2.2s   (soft departure whoosh)
#   compass_receipt.wav  1.5s   (warm arrival chime)
#
# ElevenLabs equivalents (if ever swapping to recorded audio):
#   send:    "Soft airy departing breath whoosh, gentle swell then fading
#             away, intimate and peaceful, 2.2 seconds"
#   receipt: "Warm soft singing bowl arrival chime, gentle strike resolving to
#             a long warm decay, peaceful and welcoming, 1.5 seconds"

import wave, os, math, struct, random

SR = 44100
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "Sounds", "Instruments")


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
    """Scale so the loudest sample hits `peak` (keeps it gentle)."""
    m = max(abs(x) for x in samples) or 1.0
    g = peak / m
    return [x * g for x in samples]


# ── SEND — soft departing breath/whoosh ─────────────────────────────────────
def synth_send(secs=2.2):
    n = int(SR * secs)
    rng = random.Random(7)            # deterministic noise
    lp_a, lp_b, out = 0.0, 0.0, []
    for i in range(n):
        t = i / SR
        # White noise → two one-pole lowpasses; their difference is a soft
        # mid "air" band (breath), with the harsh top and the low rumble gone.
        x = rng.uniform(-1.0, 1.0)
        lp_a += 0.12 * (x - lp_a)     # gentle lowpass (tames the hiss)
        lp_b += 0.015 * (x - lp_b)    # very low rumble
        air = lp_a - lp_b
        # Faint low tone gliding DOWN in pitch (320 → 170 Hz) — the thought
        # drifting off. Very quiet, just a felt undertone.
        f = 320.0 - 150.0 * (t / secs)
        tone = math.sin(2 * math.pi * f * t) * 0.06
        # Envelope: soft swell in (~0.55s), then a long gentle fade to nothing.
        atk = 0.55
        if t < atk:
            env = math.sin((t / atk) * (math.pi / 2))        # ease-in to 1
        else:
            d = (t - atk) / (secs - atk)
            env = math.cos(d * (math.pi / 2)) ** 1.5         # ease-out to 0
        out.append((air * 0.85 + tone) * env)
    return _normalize(out, 0.16)      # very soft


# ── RECEIPT — warm welcoming chime ──────────────────────────────────────────
def synth_receipt(secs=1.5):
    n = int(SR * secs)
    f0 = 528.0                        # warm fundamental
    # (partial ratio, amplitude, decay rate) — higher partials fade faster,
    # a soft sub and a consonant major-third companion add warmth/body.
    partials = [
        (0.5,  0.28, 2.2),            # soft sub — body/warmth
        (1.0,  1.00, 2.6),            # fundamental
        (1.25, 0.34, 3.2),            # major-third companion (consonant warmth)
        (2.0,  0.30, 4.2),            # octave shimmer
        (3.0,  0.12, 6.0),            # faint upper sparkle
    ]
    out = []
    for i in range(n):
        t = i / SR
        # Quick soft strike (~25 ms) then a long warm exponential tail.
        attack = min(1.0, t / 0.025)
        s = 0.0
        for ratio, amp, dec in partials:
            s += amp * math.sin(2 * math.pi * f0 * ratio * t) * math.exp(-t * dec)
        out.append(s * attack)
    return _normalize(out, 0.22)      # gentle, warm


# ── Silent placeholder (kept for reference — superseded by the synths above) ─
# def write_silence(name, secs):
#     n = int(SR * secs)
#     _write(name, [0.0] * n)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    _write("compass_send", synth_send(2.2))
    _write("compass_receipt", synth_receipt(1.5))
