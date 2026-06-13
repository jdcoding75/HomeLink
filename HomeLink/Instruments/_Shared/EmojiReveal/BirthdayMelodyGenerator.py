#!/usr/bin/env python3
# BirthdayMelodyGenerator.py
# Pointward › Instruments › _Shared › EmojiReveal
#
# Generates birthday_melody.wav — a gentle music-box / chime rendition of
# "Happy Birthday to You" that plays as a warm celebratory bed under the
# Birthday SEND and RECEIPT screens.
#
# Character: bright bell/music-box timbre (additive harmonics + fast attack,
# exponential decay so notes ring and overlap), warm and charming — NOT loud
# or brash (normalized to ~0.6 of full scale; the player layers it softly).
#
# Stdlib only (wave + math) — no numpy/scipy, runs anywhere.
# Run:  python3 BirthdayMelodyGenerator.py
#
# Output:  ../../../Sounds/Instruments/birthday_melody.wav

import wave, math, os, struct

SR = 44100
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "..", "Sounds", "Instruments", "birthday_melody.wav")

# ── Note frequencies (C major, the classic Happy Birthday register) ──────────
N = {
    "G4": 392.00, "A4": 440.00, "B4": 493.88, "C5": 523.25,
    "D5": 587.33, "E5": 659.25, "F5": 698.46, "G5": 783.99,
}

# ── Melody: (note, duration in seconds) · gentle 3/4 feel, b≈0.5s ────────────
# "Happy birthday to you" ×2, "Happy birthday dear ___", "Happy birthday to you"
GAP = 0.25
MELODY = [
    # Line 1 — Happy birthday to you
    ("G4", 0.375), ("G4", 0.125), ("A4", 0.5), ("G4", 0.5), ("C5", 0.5), ("B4", 1.0),
    ("REST", GAP),
    # Line 2 — Happy birthday to you
    ("G4", 0.375), ("G4", 0.125), ("A4", 0.5), ("G4", 0.5), ("D5", 0.5), ("C5", 1.0),
    ("REST", GAP),
    # Line 3 — Happy birthday dear ___
    ("G4", 0.375), ("G4", 0.125), ("G5", 0.5), ("E5", 0.5), ("C5", 0.5), ("B4", 0.5), ("A4", 1.0),
    ("REST", GAP),
    # Line 4 — Happy birthday to you
    ("F5", 0.375), ("F5", 0.125), ("E5", 0.5), ("C5", 0.5), ("D5", 0.5), ("C5", 1.0),
]

TAIL = 1.2  # let the final note ring out

# ── Music-box bell voice: additive harmonics, fast attack, exp decay ─────────
HARMONICS = [(1.0, 1.00), (2.0, 0.45), (3.0, 0.22), (4.0, 0.12), (5.0, 0.05)]
ATTACK = 0.004     # 4 ms — crisp pluck
DECAY_TAU = 0.85   # ring-out time constant (notes overlap → music-box charm)

def render():
    total = sum(d for _, d in MELODY) + TAIL
    buf = [0.0] * int(SR * total)

    t = 0.0
    for note, dur in MELODY:
        if note != "REST":
            f = N[note]
            start = int(t * SR)
            # ring length: the note's duration plus a generous decay tail
            ring = dur + 1.6
            ns = int(ring * SR)
            for i in range(ns):
                idx = start + i
                if idx >= len(buf):
                    break
                tt = i / SR
                # envelope: linear attack → exponential decay
                if tt < ATTACK:
                    env = tt / ATTACK
                else:
                    env = math.exp(-(tt - ATTACK) / DECAY_TAU)
                s = 0.0
                for mult, amp in HARMONICS:
                    s += amp * math.sin(2 * math.pi * f * mult * tt)
                # gentle per-note level; harmonics are normalized below
                buf[idx] += env * s * 0.16
        t += dur

    # ── Normalize warm, not brash (~0.6 peak) ────────────────────────────────
    peak = max(abs(x) for x in buf) or 1.0
    gain = 0.6 / peak
    frames = bytearray()
    for x in buf:
        v = int(max(-1.0, min(1.0, x * gain)) * 32767)
        frames += struct.pack("<h", v)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print(f"wrote {os.path.normpath(OUT)}  ({total:.2f}s, peak gain {gain:.2f})")
    return total

if __name__ == "__main__":
    render()
