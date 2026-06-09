#!/usr/bin/env python3
# RocketSoundGenerator.py
# Pointward > Instruments > Rocket
#
# Regenerates the rocket_send.wav / rocket_receipt.wav
# placeholders. Run:  python3 RocketSoundGenerator.py
#
# Right now this writes SILENT placeholders of the correct
# duration using only the Python standard library, so it
# runs anywhere with no dependencies. When real audio is
# approved, drop the .wav files in ../../Sounds/Instruments/
# or wire numpy/scipy synthesis in below.
#
# DURATIONS (must match InstrumentBoundaries + RocketSounds.swift):
#   rocket_send.wav     4.0s
#   rocket_receipt.wav  4.0s
#
# ElevenLabs prompt (send):
#   "Deep rumbling rocket launch sound, starting almost silent, building over 2 seconds to a thunderous roar with crackling fire exhaust tail, 4 seconds total, very bass heavy"
# ElevenLabs prompt (receipt):
#   "Rocket descending and landing, deep rumble fading to thruster burns then silence at touchdown, 4 seconds total"

import wave, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "Sounds", "Instruments")

SPECS = [
    ("rocket_send", 4.0),
    ("rocket_receipt", 4.0),
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
