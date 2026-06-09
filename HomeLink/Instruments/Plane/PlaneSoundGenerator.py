#!/usr/bin/env python3
# PlaneSoundGenerator.py
# Pointward > Instruments > Plane
#
# Regenerates the plane_send.wav / plane_receipt.wav
# placeholders. Run:  python3 PlaneSoundGenerator.py
#
# Right now this writes SILENT placeholders of the correct
# duration using only the Python standard library, so it
# runs anywhere with no dependencies. When real audio is
# approved, drop the .wav files in ../../Sounds/Instruments/
# or wire numpy/scipy synthesis in below.
#
# DURATIONS (must match InstrumentBoundaries + PlaneSounds.swift):
#   plane_send.wav     5.0s
#   plane_receipt.wav  5.0s
#
# ElevenLabs prompt (send):
#   "Small toy airplane propeller sound, starts slow winding up to full speed, light and charming, 5 seconds total"
# ElevenLabs prompt (receipt):
#   "Small toy airplane landing sound, propeller slowing down, gentle touchdown, charming and light, 5 seconds total"

import wave, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "Sounds", "Instruments")

SPECS = [
    ("plane_send", 5.0),
    ("plane_receipt", 5.0),
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
