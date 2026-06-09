#!/usr/bin/env python3
# CompassSoundGenerator.py
# Pointward > Instruments > Compass
#
# Regenerates the compass_send.wav / compass_receipt.wav
# placeholders. Run:  python3 CompassSoundGenerator.py
#
# Right now this writes SILENT placeholders of the correct
# duration using only the Python standard library, so it
# runs anywhere with no dependencies. When real audio is
# approved, drop the .wav files in ../../Sounds/Instruments/
# or wire numpy/scipy synthesis in below.
#
# DURATIONS (must match InstrumentBoundaries + CompassSounds.swift):
#   compass_send.wav     3.5s
#   compass_receipt.wav  1.5s
#
# ElevenLabs prompt (send):
#   "Warm soft singing bowl tone, gentle strike building slowly then fading, intimate and peaceful, 3.5 seconds"
# ElevenLabs prompt (receipt):
#   "Soft singing bowl arrival tone, descending gently to silence, peaceful and complete, 1.5 seconds"

import wave, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "Sounds", "Instruments")

SPECS = [
    ("compass_send", 3.5),
    ("compass_receipt", 1.5),
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
