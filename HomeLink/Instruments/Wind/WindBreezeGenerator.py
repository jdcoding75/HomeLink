# WindBreezeGenerator.py
# Pointward › Instruments › Wind
#
# Generates wind_breeze.wav — a very soft, low ambient breeze cue layered
# UNDER the existing wind_send.wav / wind_receipt.wav (it does not replace them).
#
# Character: gentle natural breeze — filtered noise with a soft low body and a
# faint airy band, slowly swelling and ebbing (gusts), very low level, long
# fades in/out so it slips in and out unnoticed.
#
# Output: mono · 16-bit · 44100 Hz · 8.0s (covers both the 6.5s send and the
# 7.2s receipt). Deterministic (seeded).
#
# RUN: python3 WindBreezeGenerator.py

import wave, os
import numpy as np

SR = 44100
DUR = 8.0
PEAK = 0.0425        # very soft — ambient, sits underneath (halved from 0.085)
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "Sounds", "Instruments", "wind_breeze.wav")

rng = np.random.default_rng(20240611)
n = int(SR * DUR)
t = np.arange(n) / SR


def one_pole_lowpass(x, a):
    """Simple one-pole low-pass; small a = lower cutoff."""
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


# Soft low body — heavily low-passed noise (twice, for a gentle rolloff).
body = one_pole_lowpass(one_pole_lowpass(rng.standard_normal(n), 0.045), 0.045)
body /= np.max(np.abs(body)) + 1e-9

# Faint airy band — a quieter, SOFTER low-mid layer so it reads as gentle "air",
# not just rumble. [tweak] Double low-pass at a lower cutoff (0.12 vs 0.30) rolls
# off the harsh mid/highs; the high-pass still removes the low rumble. Quieter in
# the mix too, so the texture is smoother and airier, less harsh.
air_lp = one_pole_lowpass(one_pole_lowpass(rng.standard_normal(n), 0.12), 0.12)
air_hp = one_pole_lowpass(air_lp, 0.02)
air = air_lp - air_hp                       # soft low-mid band
air /= np.max(np.abs(air)) + 1e-9

mix = body * 0.78 + air * 0.28

# [tweak] A final gentle top-end smoothing (~3kHz) to round off any residual
# edge — keeps the breeze airy but removes harshness.
mix = one_pole_lowpass(mix, 0.30)

# Slow gusts — the breeze swells and ebbs (sub-1 Hz modulation).
gust = (np.sin(2 * np.pi * 0.13 * t)
        + 0.7 * np.sin(2 * np.pi * 0.27 * t + 1.1)
        + 0.5 * np.sin(2 * np.pi * 0.41 * t + 2.3))
gust = (gust - gust.min()) / (gust.max() - gust.min())   # 0…1
gust = 0.45 + 0.55 * gust                                  # never fully silent

out = mix * gust

# Long raised-cosine fades so it slips in/out (1.0s each).
fade = int(SR * 1.0)
ramp = 0.5 * (1 - np.cos(np.linspace(0, np.pi, fade)))
out[:fade] *= ramp
out[-fade:] *= ramp[::-1]

# Normalize to the soft target peak.
out = out / (np.max(np.abs(out)) + 1e-9) * PEAK

pcm = np.clip(out * 32767.0, -32768, 32767).astype("<i2")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with wave.open(OUT, "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())

print("wrote", os.path.normpath(OUT), "·", round(len(pcm) / SR, 2), "s · peak", PEAK)
