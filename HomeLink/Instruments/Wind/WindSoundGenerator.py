#!/usr/bin/env python3
# WindSoundGenerator.py
# Pointward > Instruments > Wind
#
# Regenerates the wind_send.wav / wind_receipt.wav
# placeholders. Run:  python3 WindSoundGenerator.py
#
# Right now this writes SILENT placeholders of the correct
# duration using only the Python standard library, so it
# runs anywhere with no dependencies. When real audio is
# approved, drop the .wav files in ../../Sounds/Instruments/
# or wire numpy/scipy synthesis in below.
#
# DURATIONS (must match InstrumentBoundaries + WindSounds.swift):
#   wind_send.wav     6.5s
#   wind_receipt.wav  7.2s
#
# ElevenLabs prompt (send):
#   "Gentle organic wind building from near silence to full presence, pure wind no music or tones, 6.5 seconds total"
# ElevenLabs prompt (receipt):
#   "Wind arriving and gradually settling to silence, same character as send, 7.2 seconds total"

import wave, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "Sounds", "Instruments")

SPECS = [
    ("wind_send", 6.5),
    ("wind_receipt", 7.2),
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
