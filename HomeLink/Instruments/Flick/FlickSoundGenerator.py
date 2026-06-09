#!/usr/bin/env python3
# FlickSoundGenerator.py
# Pointward > Instruments > Flick
#
# Regenerates the flick_send.wav / flick_receipt.wav
# placeholders. Run:  python3 FlickSoundGenerator.py
#
# Right now this writes SILENT placeholders of the correct
# duration using only the Python standard library, so it
# runs anywhere with no dependencies. When real audio is
# approved, drop the .wav files in ../../Sounds/Instruments/
# or wire numpy/scipy synthesis in below.
#
# DURATIONS (must match InstrumentBoundaries + FlickSounds.swift):
#   flick_send.wav     0.7s
#   flick_receipt.wav  1.0s
#
# ElevenLabs prompt (send):
#   "Paper flick snap sound, single sharp snap like flicking a sticky note, 0.7 seconds"
# ElevenLabs prompt (receipt):
#   "Sticky note slapping onto a cork board, sharp thwack sound with brief vibration, 1.0 seconds"

import wave, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "Sounds", "Instruments")

SPECS = [
    ("flick_send", 0.7),
    ("flick_receipt", 1.0),
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
