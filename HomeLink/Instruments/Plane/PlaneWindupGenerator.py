# PlaneWindupGenerator.py
# Pointward › Instruments › Plane
#
# Generates plane_windup.wav — an ultra-light, delicate rubber-band propeller
# wind-up for the COMPASS face (one soft whirr per wound circle). Think a balsa
# toy plane: airy, quiet, mechanical-but-gentle. Replaces the harsh per-circle
# "plane.wind" ratchet click. NOT loud, NOT a bang.
#
# Character: a soft rising whirr — band-passed air noise amplitude-modulated by
# a prop flutter whose rate rises ~17→48 Hz over the sound (winding up), with a
# faint low rubber-band hum rising underneath. Smooth attack/release (no
# transient click), very low level.
#
# Output: mono · 16-bit · 44100 Hz · 0.55s · peak 0.08 (ultra-light). Seeded.
#
# RUN: python3 PlaneWindupGenerator.py

import wave, os
import numpy as np

SR = 44100
DUR = 0.55
PEAK = 0.08          # ultra-light — quiet, sits gently
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "Sounds", "Instruments", "plane_windup.wav")

rng = np.random.default_rng(70730)
n = int(SR * DUR)
t = np.arange(n) / SR
p = t / DUR


def one_pole_lowpass(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


# Airy body — band-passed noise (soft mid air, no low rumble, no harsh highs).
noise = rng.standard_normal(n)
lp = one_pole_lowpass(noise, 0.18)          # roll off the highs (no hiss/harshness)
air = lp - one_pole_lowpass(lp, 0.015)      # remove the low rumble → gentle mid band
air /= np.max(np.abs(air)) + 1e-9

# Prop flutter — amplitude modulation whose RATE RISES (the prop winding up).
rate = 17.0 + (48.0 - 17.0) * p             # 17 → 48 Hz
flutter_phase = np.cumsum(2 * np.pi * rate / SR)
flutter = 0.55 + 0.45 * np.sin(flutter_phase)   # 0.1…1.0, rounded (no clicks)

whirr = air * flutter

# Faint low "rubber-band" hum rising 80→150 Hz, very quiet, also fluttering.
hum_f = 80.0 + 70.0 * p
hum_phase = np.cumsum(2 * np.pi * hum_f / SR)
hum = np.sin(hum_phase) * 0.18 * flutter

out = whirr * 0.9 + hum

# Gentle swell — quieter at the start, fuller as it winds up.
out *= 0.45 + 0.55 * p

# Smooth raised-cosine attack/release — NO sharp onset (kills the "bang").
atk = int(SR * 0.08)
rel = int(SR * 0.16)
out[:atk] *= 0.5 * (1 - np.cos(np.linspace(0, np.pi, atk)))
out[-rel:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, rel)))

out = out / (np.max(np.abs(out)) + 1e-9) * PEAK
pcm = np.clip(out * 32767.0, -32768, 32767).astype("<i2")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with wave.open(OUT, "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())

print("wrote", os.path.normpath(OUT), "·", round(len(pcm) / SR, 2), "s · peak", PEAK)
