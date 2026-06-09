#!/usr/bin/env python3
# BowSoundGenerator.py
# Pointward > Instruments > Bow
#
# Regenerates the bow_send.wav / bow_receipt.wav
# placeholders. Run:  python3 BowSoundGenerator.py
#
# Right now this writes SILENT placeholders of the correct
# duration using only the Python standard library, so it
# runs anywhere with no dependencies. When real audio is
# approved, drop the .wav files in ../../Sounds/Instruments/
# or wire numpy/scipy synthesis in below.
#
# DURATIONS (must match InstrumentBoundaries + BowSounds.swift):
#   bow_send.wav     0.8s
#   bow_receipt.wav  1.1s
#
# ElevenLabs prompt (send):
#   "Compound bow release sound, sharp crack followed by high pitched arrow whistle doppler fading away quickly, 0.8 seconds total"
# ElevenLabs prompt (receipt):
#   "Arrow hitting archery target, sharp thud with brief vibration, 1.1 seconds"

import wave, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "Sounds", "Instruments")

SPECS = [
    ("bow_send", 0.8),
    ("bow_receipt", 1.1),
]

def write_silence(name, secs):
    n = int(SR * secs)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"\x00\x00" * n)
    print("wrote", os.path.normpath(path), f"({secs}s)")

# ── Real-audio hook (optional) ───────────────────────────
# import numpy as np
# from scipy.io import wavfile
# def write_synth(name, secs): ...   # synthesize per the prompt
# ----------------------------------------------------------

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, secs in SPECS:
        write_silence(name, secs)
