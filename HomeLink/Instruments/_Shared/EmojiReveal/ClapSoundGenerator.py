#!/usr/bin/env python3
# ClapSoundGenerator.py
# Pointward › Instruments › _Shared › EmojiReveal
#
# Generates emoji_clap.wav — a single, realistic hand-clap used by the 👏 reveal.
# It fires once per clap contact (3–4 times) during the clapping animation.
#
# CHARACTER (warm + organic — real hands, NOT a metallic snap):
#   The previous version added pure SINE partials (900/1500/2300 Hz) for the
#   "body" — sustained tones ring like metal, which is exactly the metallic
#   quality we're removing. A real clap has NO tonal partials: it is shaped
#   NOISE. So this version is built entirely from filtered noise:
#     1. THUMP   — low band-passed noise (~250 Hz): the fleshy palm contact.
#     2. BODY    — mid band-passed noise (~950 Hz, gentle Q): the cupped-hand
#                  "pop" tone, resonant but noisy → organic, never a sine ring.
#     3. SLAP    — broadband noise rolled off above ~3.2 kHz: the air/skin
#                  transient, with the harsh fizz removed so it's a pat, not a click.
#   A SOFT attack (~3 ms ramp) replaces the old instant-onset click, and the
#   highs are low-passed for warmth. Short + percussive (~0.20 s), normalized
#   gentle (~0.6 peak) so it's warm, not loud.
#
# Stdlib only (wave + math + random) — no numpy/scipy. Run:
#   python3 ClapSoundGenerator.py
# Output:  ../../../Sounds/emoji_clap.wav   (Sounds/ root — same place as the
#          other emoji-reveal sounds: emoji_kiss, emoji_punch, emoji_hug, …)

import wave, math, struct, random, os

SR = 44100
DUR = 0.20
OUT = os.path.join(os.path.dirname(__file__),
                   "..", "..", "..", "Sounds", "emoji_clap.wav")
PEAK = 0.6                      # warm, not loud


def noise(n, rng):
    """White noise in [-1, 1]."""
    return [rng.random() * 2 - 1 for _ in range(n)]


def svf_bandpass(x, fc, q):
    """Chamberlin state-variable band-pass. q = 1/Q (lower = more resonant).
    Resonant filtered NOISE gives an organic tone with no tonal sine ring."""
    f = 2 * math.sin(math.pi * fc / SR)
    low = band = 0.0
    out = []
    for s in x:
        low += f * band
        high = s - low - q * band
        band += f * high
        out.append(band)
    return out


def lowpass(x, fc, poles=2):
    """Cascaded one-pole low-pass — rolls off harsh highs for warmth."""
    rc = 1.0 / (2 * math.pi * fc)
    a = (1.0 / SR) / (rc + 1.0 / SR)
    y = list(x)
    for _ in range(poles):
        prev = 0.0
        for i in range(len(y)):
            prev += a * (y[i] - prev)
            y[i] = prev
    return y


def render():
    n = int(SR * DUR)
    rng = random.Random(42)             # deterministic — same clap every build

    # Three decorrelated noise sources so the layers don't phase-align oddly.
    n_thump = noise(n, rng)
    n_body  = noise(n, rng)
    n_slap  = noise(n, rng)

    # Shape each layer through its filter.
    thump = svf_bandpass(n_thump, 250.0, q=0.85)   # fleshy low palm contact
    body  = svf_bandpass(n_body,  950.0, q=0.55)   # cupped-hand pop (noisy, warm)
    slap  = lowpass(n_slap, 3200.0, poles=2)       # air/skin transient, de-fizzed

    # Soft attack (~3 ms) so the onset is a pat, not a click.
    att = int(SR * 0.003)

    samples = []
    for i in range(n):
        t = i / SR
        # Per-layer decays — short + percussive, body a touch longer for warmth.
        e_thump = math.exp(-t / 0.040)
        e_body  = math.exp(-t / 0.075)
        e_slap  = math.exp(-t / 0.022)
        s = (thump[i] * 0.70 * e_thump
             + body[i] * 0.95 * e_body
             + slap[i] * 0.45 * e_slap)
        # Soft attack ramp (smooth, not linear) replaces the old instant onset.
        if i < att:
            k = i / att
            s *= k * k * (3 - 2 * k)        # smoothstep 0→1
        samples.append(s)

    # Gentle fade-out over the last 12% so the buffer never clicks at the end.
    fade = int(n * 0.12)
    for j in range(fade):
        idx = n - fade + j
        samples[idx] *= (fade - j) / fade

    # Normalize warm (~0.6 peak).
    peak = max(abs(x) for x in samples) or 1.0
    gain = PEAK / peak
    frames = bytearray()
    for x in samples:
        v = int(max(-1.0, min(1.0, x * gain)) * 32767)
        frames += struct.pack("<h", v)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print(f"wrote {os.path.normpath(OUT)}  ({DUR:.2f}s, peak gain {gain:.2f})")


if __name__ == "__main__":
    render()
