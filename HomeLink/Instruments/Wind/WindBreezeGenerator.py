# WindBreezeGenerator.py
# Pointward › Instruments › Wind
#
# Generates wind_breeze.wav — a very soft, low ambient breeze cue layered
# UNDER the existing wind_send.wav / wind_receipt.wav (it does not replace them).
#
# Character: a LIGHT gentle breeze — a soft airy high band leads (the "shhh" of
# air, not a sustained heavy-wind rumble), with the low body kept well back,
# slowly swelling and ebbing (gusts), very low level, long fades in/out so it
# slips in and out unnoticed.
#
# Output: mono · 16-bit · 44100 Hz · 8.0s (covers both the 6.5s send and the
# 7.2s receipt). Deterministic (seeded).
#
# RUN: python3 WindBreezeGenerator.py

import wave, os
import numpy as np

SR = 44100
DUR = 8.0
PEAK = 0.02125       # very soft — ambient, sits underneath (halved again from 0.0425)
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


# [tweak] LIGHT GENTLE BREEZE rebalance — was body-dominant (0.78) low rumble
# that read as sustained heavy wind. Now the low body sits well back and a soft
# AIRY HIGH band leads, so it feels like a light breeze, not constant wind.

# Soft low body — heavily low-passed noise (twice). Kept, but quiet in the mix.
body = one_pole_lowpass(one_pole_lowpass(rng.standard_normal(n), 0.040), 0.040)
body /= np.max(np.abs(body)) + 1e-9

# Airy HIGH band — high-pass (noise minus its low-pass) drops the low rumble AND
# the harsh low-mids; a gentle top smoothing keeps it soft "air", not sharp hiss.
# This is the LEAD texture now — the soft "shhh" of a light breeze.
hp_src = rng.standard_normal(n)
airy = hp_src - one_pole_lowpass(hp_src, 0.18)   # keep highs, drop low/low-mid (harsh)
airy = one_pole_lowpass(airy, 0.55)              # round off the very top edge
airy /= np.max(np.abs(airy)) + 1e-9

# Mix — low body well back (0.34), soft airy highs forward (0.50).
mix = body * 0.34 + airy * 0.50

# Only a very light top smoothing now (was 0.30 ≈ 3 kHz, which dulled the air
# back toward "wind"); 0.6 keeps the soft airy highs present.
mix = one_pole_lowpass(mix, 0.6)

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
