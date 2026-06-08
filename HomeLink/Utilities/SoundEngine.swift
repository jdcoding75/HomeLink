// SoundEngine.swift
// Pointward › Utilities
//
// Programmatic sound synthesis for "send a thought" — every sound is
// generated sample-by-sample in Swift and played through AVAudioEngine.
// No audio files anywhere.
//
// PERFORMANCE: all buffers are pre-generated once at init and cached;
// play(for:) schedules a cached buffer instantly — nothing is synthesized
// on the tap path.

import AVFoundation

final class SoundEngine {

    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let format: AVAudioFormat

    /// Token → ready-to-play buffer + lane volume. Built once at startup.
    private var cache: [String: (buffer: AVAudioPCMBuffer, volume: Float)] = [:]
    /// PRO: the same voices, pre-rendered through proEnhanced() — layered,
    /// warmer, richer. Built once; play(for:) picks by tier at tap time.
    private var proCache: [String: (buffer: AVAudioPCMBuffer, volume: Float)] = [:]

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        // Ambient: respects the silent switch, mixes with the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        buildCache()
        buildProCache()
    }

    // Quiet Mode retired — full emotional intensity, always.
    // private var isQuiet: Bool { UserDefaults.standard.bool(forKey: "quietMode") }
    private let isQuiet = false

    // MARK: - Cache

    private func buildCache() {
        let builders: [(token: String, volume: Float, make: () -> AVAudioPCMBuffer?)] = [
            // ── CORE — four signatures, warm and barely-there ──────────────
            ("❤️",    0.50, makeWarmPulse),
            ("🤗",    0.50, makeWarmPulse),
            ("🌸",    0.50, makeWarmPulse),
            ("🌙",    0.50, makeWarmPulse),
            ("✨",    0.45, makeLightShimmer),
            ("💋",    0.50, makeSoftBreath),
            // legacy tokens (old history entries replay through these)
            ("💜",    0.50, makeWarmPulse),
            ("🫂",    0.50, makeWarmPulse),
            ("😢",    0.55, makeSad),

            // ── PRO — with feeling ──────────────────────────────────
            ("😤",    0.80, makeFrustrated),
            ("🤬",    0.85, makeAngry),
            ("👊",    0.85, makePunch),
            ("💢",    0.80, makeZap),
            ("⚡️",    0.90, makeLightning),
            ("🌋",    0.85, makeVolcano),
            ("🔥",    0.85, makeFire),
            ("😡",    0.80, makeStab),
            ("💨",    0.85, makeFart),

            // ── PRO — with food & drink ─────────────────────────────
            ("🍕",    0.55, makePizzaDoorbell),
            ("🍫",    0.50, makeChocolateCrinkle),
            ("🍺",    0.55, makeBeerPour),
            ("🍷",    0.50, makeWineClink),
            ("🍰",    0.50, makeCakeChime),
            ("☕",    0.50, makeEspresso),
            ("🧁",    0.50, makeCupcakePop),
            ("🍜",    0.55, makeNoodleSlurp),
            ("🍣",    0.50, makeSushiPlop),
            ("🥂",    0.55, makeChampagne),

            // ── PRO — silly ─────────────────────────────────────────
            ("😂",    0.55, makeLaugh),
            ("🤪",    0.55, makeNoodleSlurp),
            ("🥳",    0.55, makeCakeChime),
            ("💥",    0.80, makePunch),
            ("🎉",    0.55, makeChampagne),
            ("gecko", 0.50, makeGecko),

            // ── SENDER STYLE voices (animation system overhaul) ─────────
            ("style.whoosh",  0.55, makeStyleWhoosh),    // shooting star send
            ("style.chime",   0.40, makeStyleChime),     // firefly send
            ("style.bell",    0.45, makeStyleBell),      // catch reveal
            ("style.shimmer", 0.35, makeStyleShimmer),   // caught confirmation
        ]
        // (Commented out of the core flow, voices kept below for reuse:)
        // ("💜", 0.50, makeHeart), ("💋", 0.55, makeKiss),
        // ("🌸", 0.50, makeBlossom), ("✨", 0.50, makeSparkle)
        for entry in builders {
            if let buffer = entry.make() {
                cache[entry.token] = (buffer, entry.volume)
            }
        }
    }

    /// Instant playback from cache — safe to call on the tap path.
    /// Free: single clean voice. Pro: the layered enhanced version of the
    /// same voice (catch reveals, send completions, confirmations — all of
    /// them route through here).
    func play(for token: String) {
        if isProTier, let rich = proCache[token] {
            play(rich.buffer, volume: rich.volume)
            return
        }
        guard let entry = cache[token] else { return }
        play(entry.buffer, volume: entry.volume)
    }

    /// Read the tier straight from UserDefaults — SoundEngine has no view
    /// model, and the check must be instant on the tap path.
    private var isProTier: Bool {
        let raw = UserDefaults.standard.string(forKey: "subscriptionTier") ?? ""
        return (SubscriptionTier(rawValue: raw) ?? .free) != .free
    }

    // MARK: - Pro enhancement (layered warmth)

    /// Every cached voice gets a pre-rendered enhanced sibling.
    private func buildProCache() {
        for (token, entry) in cache {
            if let rich = proEnhanced(entry.buffer) {
                proCache[token] = (rich, entry.volume)
            }
        }
    }

    /// PRO ENHANCED — the same voice, three times, barely apart:
    ///   layer 1 · the original                      · 100 %
    ///   layer 2 · +7 ms, pitch +2 % (resampled)     ·  60 %
    ///   layer 3 · +14 ms, 85 % of its own volume    ·  40 %
    /// The micro-offsets and detune read as warmth and body — one voice
    /// becoming a small chorus. Normalized back into headroom.
    private func proEnhanced(_ base: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let baseFrames = Int(base.frameLength)
        guard baseFrames > 0, let src = base.floatChannelData?[0] else { return nil }
        let offset2 = Int(0.007 * sampleRate)   //  +7 ms
        let offset3 = Int(0.014 * sampleRate)   // +14 ms
        let pitch2  = 1.02                      //  +2 % — slight detune
        let total   = baseFrames + offset3
        guard let (buf, data, n) = makeBuffer(duration: Double(total) / sampleRate) else {
            return nil
        }
        for i in 0..<n {
            var s = 0.0
            // Layer 1 — the voice itself
            if i < baseFrames { s += Double(src[i]) }
            // Layer 2 — 7 ms behind, 2 % sharp (linear-interp resample)
            if i >= offset2 {
                let pos = Double(i - offset2) * pitch2
                let j = Int(pos)
                if j + 1 < baseFrames {
                    let frac = pos - Double(j)
                    s += (Double(src[j]) * (1 - frac) + Double(src[j + 1]) * frac) * 0.60
                }
            }
            // Layer 3 — 14 ms behind, slightly quieter copy
            let k = i - offset3
            if k >= 0 && k < baseFrames { s += Double(src[k]) * 0.85 * 0.40 }
            // Blend back into headroom (sum of gains ≈ 1.94)
            data[i] = Float(max(-1, min(1, s / 1.4)))
        }
        return buf
    }

    // MARK: - Core signatures (Pro Mode OFF)
    //
    // NOTE: programmatic synthesis has real limits for warmth — these are
    // designed placeholders. For production intimacy, source soft recorded
    // .wav/.caf samples (freesound.org, zapsplat.com) and play them here.

    /// WARM PULSE — ❤️ 🤗 🌸 🌙
    /// 60–90 Hz sine, 0.3 s fade-in, 0.8 s total. A heartbeat in a quiet
    /// room — felt more than heard.
    private func makeWarmPulse() -> AVAudioPCMBuffer? {
        let d = 0.8
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            // One deep slow swell, 62 → 84 Hz
            let phase = sweepPhase(t, f0: 62, f1: 84, d: d)
            let tone  = sin(phase) + 0.15 * sin(phase * 2)
            // 0.3 s of the 0.8 s is pure fade-in; long gentle release
            data[i] = Float(tone * 0.30 * envelope(p, attack: 0.375, release: 0.45))
        }
        return buf
    }

    /// LIGHT SHIMMER — ✨
    /// Slightly detuned high tones, 900–1400 Hz, 0.4 s.
    /// Fades like light catching glass — a shimmer, never a beep.
    private func makeLightShimmer() -> AVAudioPCMBuffer? {
        let d = 0.4
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        // Detuned pairs create the slow beating that reads as shimmer
        let tones: [Double] = [905, 911, 1085, 1093, 1240, 1247, 1390]
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for (k, f) in tones.enumerated() {
                s += sin(2 * .pi * f * t) * exp(-t * (6.5 + Double(k) * 0.7))
            }
            let attack = min(1, t / 0.03)
            data[i] = Float(s * 0.075 * attack)
        }
        return buf
    }

    /// SOFT BREATH — 💋
    /// Band-filtered noise warmth (150–300 Hz), a slight rise then fall —
    /// an exhale. 0.5 s, intimate and barely-there.
    private func makeSoftBreath() -> AVAudioPCMBuffer? {
        let d = 0.5
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        let r = 0.965
        var y1 = 0.0, y2 = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            // Bandpass center drifts 180 → 260 → 180 Hz across the breath
            let fc = 180 + 80 * sin(.pi * p)
            let omega = 2 * Double.pi * fc / sampleRate
            let x = Double.random(in: -1...1, using: &rng)
            let y = x + 2 * r * cos(omega) * y1 - r * r * y2
            y2 = y1; y1 = y
            // The exhale shape: rise to the middle, fall away
            data[i] = Float(max(-1, min(1, y * 0.022)) * sin(.pi * p))
        }
        return buf
    }

    // MARK: - With love (pro-era voices, kept for reuse)

    /// 💜 Soft warm sine pulse, 440→520 Hz over 0.8 s, gentle fades.
    private func makeHeart() -> AVAudioPCMBuffer? {
        let d = 0.8
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            let phase = sweepPhase(t, f0: 440, f1: 520, d: d)
            let tone  = sin(phase) + 0.3 * sin(phase * 2)
            data[i] = Float(tone * 0.22 * envelope(p, attack: 0.30, release: 0.40))
        }
        return buf
    }

    /// 💋 Exaggerated kiss — sharp lip smack, then a comic rounded "mwah".
    private func makeKiss() -> AVAudioPCMBuffer? {
        let d = 0.5
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            if t < 0.045 {
                s += Double.random(in: -1...1, using: &rng) * exp(-t * 120) * 1.2
                s += sin(2 * .pi * 1400 * t) * exp(-t * 90) * 0.8
            }
            if t >= 0.06 {
                let tt = t - 0.06
                let dd = d - 0.06
                let f: Double = tt < 0.10 ? 320 + 2200 * tt
                                          : 540 - 300 * ((tt - 0.10) / (dd - 0.10))
                phase += 2 * .pi * f / sampleRate
                let tone = sin(phase) + 0.4 * sin(2 * phase)
                s += tone * envelope(tt / dd, attack: 0.12, release: 0.35) * 0.7
            }
            data[i] = Float(max(-1, min(1, s * 0.6)))
        }
        return buf
    }

    /// 🫂 Warm laughter — four quick "ha" bursts, falling and fading.
    private func makeLaugh() -> AVAudioPCMBuffer? {
        let d = 0.8
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        let has: [(start: Double, f0: Double)] = [
            (0.00, 300), (0.18, 285), (0.36, 270), (0.54, 255),
        ]
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for (idx, ha) in has.enumerated() where t >= ha.start && t < ha.start + 0.15 {
                let tt = t - ha.start
                let pp = tt / 0.15
                let ph = sweepPhase(tt, f0: ha.f0, f1: ha.f0 - 60, d: 0.15)
                let voice = sin(ph) + 0.5 * sin(2 * ph) + 0.25 * sin(3 * ph)
                let breath = Double.random(in: -1...1, using: &rng) * exp(-tt * 50) * 0.5
                let fade = 1.0 - Double(idx) * 0.12
                s += (voice * envelope(pp, attack: 0.18, release: 0.45) * 0.5 + breath) * fade
            }
            data[i] = Float(max(-1, min(1, s * 0.45)))
        }
        return buf
    }

    /// 🌸 Three ascending chimes — C5, E5, G5 — overlapping.
    private func makeBlossom() -> AVAudioPCMBuffer? {
        let d = 0.65
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        let notes: [(start: Double, f: Double)] = [(0.00, 523.25), (0.15, 659.25), (0.30, 783.99)]
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for note in notes where t >= note.start && t < note.start + 0.3 {
                let tt = t - note.start
                s += sin(2 * .pi * note.f * tt) * envelope(tt / 0.3, attack: 0.08, release: 0.55)
            }
            data[i] = Float(s * 0.18)
        }
        return buf
    }

    /// 🦎 Rapid soft clicks — five quick pips, like a real leopard gecko chirp.
    private func makeGecko() -> AVAudioPCMBuffer? {
        let d = 0.45
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        let clicks: [(start: Double, f: Double)] = [
            (0.00, 1900), (0.08, 2150), (0.16, 1850), (0.24, 2250), (0.32, 2000),
        ]
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for click in clicks where t >= click.start && t < click.start + 0.025 {
                let tt = t - click.start
                s += sin(2 * .pi * click.f * tt) * exp(-tt * 280)
            }
            data[i] = Float(s * 0.5)
        }
        return buf
    }

    /// ✨ High shimmer — randomized pings 800–1200 Hz.
    private func makeSparkle() -> AVAudioPCMBuffer? {
        let d = 0.6
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        let pings: [(start: Double, f: Double)] = (0..<7).map { i in
            (Double(i) * 0.075 + Double.random(in: 0...0.03, using: &rng),
             Double.random(in: 800...1200, using: &rng))
        }
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for ping in pings where t >= ping.start && t < ping.start + 0.12 {
                let tt = t - ping.start
                let decay = exp(-tt * 45)
                s += (sin(2 * .pi * ping.f * tt) + 0.4 * sin(2 * .pi * ping.f * 2 * tt)) * decay
            }
            data[i] = Float(s * 0.16)
        }
        return buf
    }

    // MARK: - With feeling

    /// 😢 Soft descending tone with vibrato. Melancholy.
    private func makeSad() -> AVAudioPCMBuffer? {
        let d = 1.2
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            let f = 400 - 180 * p + 6 * sin(2 * .pi * 5.5 * t)
            phase += 2 * .pi * f / sampleRate
            let tone = sin(phase) + 0.25 * sin(2 * phase)
            data[i] = Float(tone * 0.22 * envelope(p, attack: 0.15, release: 0.30))
        }
        return buf
    }

    /// 😤 Sharp exhale — mid-resonant noise burst.
    private func makeFrustrated() -> AVAudioPCMBuffer? {
        let d = 0.3
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        let omega = 2 * Double.pi * 900 / sampleRate
        let r = 0.95
        var y1 = 0.0, y2 = 0.0
        for i in 0..<n {
            let p = Double(i) / Double(n)
            let x = Double.random(in: -1...1, using: &rng)
            let y = x + 2 * r * cos(omega) * y1 - r * r * y2
            y2 = y1; y1 = y
            data[i] = Float(max(-1, min(1, y * 0.05)) * envelope(p, attack: 0.04, release: 0.50))
        }
        return buf
    }

    /// 🤬 Low aggressive rumble, driven into distortion.
    private func makeAngry() -> AVAudioPCMBuffer? {
        let d = 0.6
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var phase = 0.0
        for i in 0..<n {
            let p = Double(i) / Double(n)
            let f = 80 + 40 * p
            phase += 2 * .pi * f / sampleRate
            var s = sin(phase) * 2.5
            s += 0.35 * Double.random(in: -1...1, using: &rng) * sin(phase)
            s = tanh(s)
            data[i] = Float(s * 0.5 * envelope(p, attack: 0.08, release: 0.25))
        }
        return buf
    }

    /// ⚡️ Crack, then deep rolling 40–80 Hz thunder with a long decay.
    private func makeLightning() -> AVAudioPCMBuffer? {
        let d = 1.5
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var prevX = 0.0
        var lp    = 0.0
        var roll  = 0.0
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            if t < 0.08 {
                let x = Double.random(in: -1...1, using: &rng)
                let hp = x - 0.92 * prevX
                prevX = x
                s += hp * exp(-t * 60) * 0.9
            }
            if t >= 0.05 {
                let tt = t - 0.05
                let x = Double.random(in: -1...1, using: &rng)
                lp   += 0.015  * (x - lp)
                roll += 0.0006 * (abs(x) - roll)
                let f = 60 + 20 * sin(2 * .pi * 0.7 * tt)
                phase += 2 * .pi * f / sampleRate
                let body   = lp * 6.0 + sin(phase) * 0.5
                let attack = min(1, tt / 0.06)
                let decay  = exp(-tt * 2.0)
                s += body * (0.5 + roll * 6) * attack * decay * 0.8
            }
            data[i] = Float(max(-1, min(1, s)))
        }
        return buf
    }

    /// 🔥 Igniting whoosh — resonant noise sweeping up with crackles.
    private func makeFire() -> AVAudioPCMBuffer? {
        let d = 0.8
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        let r = 0.93
        var y1 = 0.0, y2 = 0.0
        for i in 0..<n {
            let p = Double(i) / Double(n)
            let fc = 400 + 1600 * p
            let omega = 2 * Double.pi * fc / sampleRate
            var x = Double.random(in: -1...1, using: &rng)
            if Double.random(in: 0...1, using: &rng) < 0.0015 { x += 3.0 }
            let y = x + 2 * r * cos(omega) * y1 - r * r * y2
            y2 = y1; y1 = y
            data[i] = Float(max(-1, min(1, y * 0.06)) * envelope(p, attack: 0.15, release: 0.30))
        }
        return buf
    }

    /// 💨 Wet sputtering fart — drunken pitch walk, bubbly noise, drooping.
    private func makeFart() -> AVAudioPCMBuffer? {
        let d = 0.7
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var phase    = 0.0
        var wobPhase = 0.0
        var f        = 95.0
        var lp       = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            f = max(60, min(120, f + Double.random(in: -1.5...1.5, using: &rng)))
            phase += 2 * .pi * f * (1.0 - 0.25 * p) / sampleRate
            wobPhase += 2 * .pi * (22 + 6 * sin(2 * .pi * 3.1 * t)) / sampleRate
            let sputter = 0.55 + 0.45 * sin(wobPhase)
                          * (0.7 + 0.3 * Double.random(in: 0...1, using: &rng))
            lp += 0.06 * (Double.random(in: -1...1, using: &rng) - lp)
            var s = (sin(phase) + 0.5 * sin(2 * phase)) * sputter + lp * 1.6 * sputter
            s = tanh(s * 1.8)
            data[i] = Float(s * 0.5 * envelope(p, attack: 0.04, release: 0.30))
        }
        return buf
    }

    /// 👊 Punch — a deep fast thump with a knuckle click.
    private func makePunch() -> AVAudioPCMBuffer? {
        let d = 0.3
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = sin(sweepPhase(t, f0: 95, f1: 42, d: 0.12)) * exp(-t * 16) * 1.3
            if t < 0.015 { s += Double.random(in: -1...1, using: &rng) * 0.7 }
            data[i] = Float(max(-1, min(1, tanh(s) * 0.7)))
        }
        return buf
    }

    /// 💢 Zap — a short bright buzz of irritation.
    private func makeZap() -> AVAudioPCMBuffer? {
        let d = 0.25
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let f = 620 + Double.random(in: -40...40, using: &rng)
            phase += 2 * .pi * f / sampleRate
            // Square-ish edge = electric buzz
            let s = tanh(sin(phase) * 4) * exp(-t * 11)
            data[i] = Float(s * 0.5)
        }
        return buf
    }

    /// 🌋 Volcano — a deep building rumble that erupts and settles.
    private func makeVolcano() -> AVAudioPCMBuffer? {
        let d = 1.2
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var lp = 0.0
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            let x = Double.random(in: -1...1, using: &rng)
            lp += 0.012 * (x - lp)
            let f = 38 + 26 * p
            phase += 2 * .pi * f / sampleRate
            // Crescendo into an eruption at ~55%, then a rolling decay
            let swell = p < 0.55 ? p / 0.55 : exp(-(p - 0.55) * 5)
            let s = (lp * 7 + sin(phase) * 0.6) * swell
            data[i] = Float(max(-1, min(1, tanh(s) * 0.8)))
        }
        return buf
    }

    /// 😡 Stab — one sharp furious jab.
    private func makeStab() -> AVAudioPCMBuffer? {
        let d = 0.22
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = sin(sweepPhase(t, f0: 1250, f1: 320, d: 0.1)) * exp(-t * 26)
            s += 0.3 * sin(2 * .pi * 180 * t) * exp(-t * 20)
            if t < 0.008 { s += Double.random(in: -1...1, using: &rng) * 0.5 }
            data[i] = Float(max(-1, min(1, s * 0.65)))
        }
        return buf
    }

    // MARK: - With food & drink

    /// 🍕 Cartoon delivery doorbell — classic two-tone ding-dong.
    private func makePizzaDoorbell() -> AVAudioPCMBuffer? {
        let d = 0.8
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        let notes: [(start: Double, f: Double, len: Double)] = [
            (0.00, 659.25, 0.35),   // ding (E5)
            (0.28, 523.25, 0.50),   // dong (C5)
        ]
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for note in notes where t >= note.start && t < note.start + note.len {
                let tt = t - note.start
                s += (sin(2 * .pi * note.f * tt) + 0.4 * sin(2 * .pi * note.f * 2 * tt))
                   * exp(-tt * 6)
            }
            data[i] = Float(s * 0.3)
        }
        return buf
    }

    /// 🍫 Satisfying wrapper crinkle — clustered bright noise bursts.
    private func makeChocolateCrinkle() -> AVAudioPCMBuffer? {
        let d = 0.6
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        // Pre-place ~14 tiny crinkle bursts
        let bursts: [(start: Double, len: Double)] = (0..<14).map { _ in
            (Double.random(in: 0...(d - 0.05), using: &rng),
             Double.random(in: 0.01...0.04, using: &rng))
        }
        var prev = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for burst in bursts where t >= burst.start && t < burst.start + burst.len {
                let x = Double.random(in: -1...1, using: &rng)
                let hp = x - 0.85 * prev
                prev = x
                s += hp * 0.7
            }
            data[i] = Float(max(-1, min(1, s)) * envelope(t / d, attack: 0.05, release: 0.2))
        }
        return buf
    }

    /// 🍺 Pour, then a satisfying clink.
    private func makeBeerPour() -> AVAudioPCMBuffer? {
        let d = 0.9
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var lp = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            // The pour: rising band of bubbly noise (0–0.6 s)
            if t < 0.6 {
                lp += (0.04 + 0.10 * t) * (Double.random(in: -1...1, using: &rng) - lp)
                s += lp * 2.2 * (0.3 + t)
            }
            // The clink at 0.65 s
            if t >= 0.65 {
                let tt = t - 0.65
                s += (sin(2 * .pi * 1800 * tt) + 0.5 * sin(2 * .pi * 2700 * tt)) * exp(-tt * 24)
            }
            data[i] = Float(max(-1, min(1, s * 0.45)))
        }
        return buf
    }

    /// 🍷 One elegant glass clink with a long ring.
    private func makeWineClink() -> AVAudioPCMBuffer? {
        let d = 1.0
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let s = (sin(2 * .pi * 2100 * t)
                   + 0.5 * sin(2 * .pi * 3150 * t)
                   + 0.25 * sin(2 * .pi * 4350 * t)) * exp(-t * 5)
            data[i] = Float(s * 0.3)
        }
        return buf
    }

    /// 🍰 Happy little chime — quick rising major arpeggio.
    private func makeCakeChime() -> AVAudioPCMBuffer? {
        let d = 0.6
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        let notes: [(start: Double, f: Double)] = [
            (0.00, 523.25), (0.10, 659.25), (0.20, 783.99), (0.30, 1046.5),
        ]
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for note in notes where t >= note.start {
                let tt = t - note.start
                s += sin(2 * .pi * note.f * tt) * exp(-tt * 9)
            }
            data[i] = Float(s * 0.2)
        }
        return buf
    }

    /// ☕ Espresso machine — pulsing pressurized hiss over a low motor hum.
    private func makeEspresso() -> AVAudioPCMBuffer? {
        let d = 0.9
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var prev = 0.0
        var motorPhase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            let x = Double.random(in: -1...1, using: &rng)
            let hiss = x - 0.6 * prev
            prev = x
            motorPhase += 2 * .pi * 95 / sampleRate
            let pulse = 0.65 + 0.35 * sin(2 * .pi * 11 * t)
            let s = hiss * 0.5 * pulse + sin(motorPhase) * 0.18
            data[i] = Float(max(-1, min(1, s)) * envelope(p, attack: 0.10, release: 0.25))
        }
        return buf
    }

    /// 🧁 Soft little pop.
    private func makeCupcakePop() -> AVAudioPCMBuffer? {
        let d = 0.2
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = sin(sweepPhase(t, f0: 320, f1: 150, d: 0.08)) * exp(-t * 30)
            if t < 0.012 { s += Double.random(in: -1...1, using: &rng) * 0.4 }
            data[i] = Float(s * 0.5)
        }
        return buf
    }

    /// 🍜 The slurp — noise sweeping up with a comic wobble.
    private func makeNoodleSlurp() -> AVAudioPCMBuffer? {
        let d = 0.6
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        let r = 0.94
        var y1 = 0.0, y2 = 0.0
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            let fc = 400 + 1000 * p + 180 * sin(2 * .pi * 9 * t)   // wobbling sweep
            let omega = 2 * Double.pi * fc / sampleRate
            let x = Double.random(in: -1...1, using: &rng)
            let y = x + 2 * r * cos(omega) * y1 - r * r * y2
            y2 = y1; y1 = y
            phase += 2 * .pi * (fc * 0.5) / sampleRate
            let s = max(-1, min(1, y * 0.05)) + sin(phase) * 0.12
            data[i] = Float(s * envelope(p, attack: 0.10, release: 0.20))
        }
        return buf
    }

    /// 🍣 A soft satisfying plop.
    private func makeSushiPlop() -> AVAudioPCMBuffer? {
        let d = 0.25
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let s = sin(sweepPhase(t, f0: 400, f1: 120, d: 0.15)) * exp(-t * 18)
            data[i] = Float(s * 0.55)
        }
        return buf
    }

    /// 🥂 Champagne — the pop, then a long fading fizz.
    private func makeChampagne() -> AVAudioPCMBuffer? {
        let d = 1.0
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var prev = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            // The pop: thump + burst
            if t < 0.06 {
                s += sin(sweepPhase(t, f0: 260, f1: 110, d: 0.06)) * exp(-t * 40) * 1.2
                s += Double.random(in: -1...1, using: &rng) * exp(-t * 90) * 0.8
            }
            // The fizz: bright sparse noise fading away
            if t >= 0.06 {
                let tt = t - 0.06
                let x = Double.random(in: -1...1, using: &rng)
                let hp = x - 0.9 * prev
                prev = x
                let sparkle = Double.random(in: 0...1, using: &rng) < 0.35 ? 1.0 : 0.25
                s += hp * sparkle * exp(-tt * 3.2) * 0.5
            }
            data[i] = Float(max(-1, min(1, s * 0.55)))
        }
        return buf
    }

    // MARK: - Sender style voices (animation system overhaul)

    /// SHOOTING STAR — a whoosh of air opening up, with a shimmer landing.
    /// 0.45 s: low-passed noise sweeping brighter, detuned sparkle at the end.
    private func makeStyleWhoosh() -> AVAudioPCMBuffer? {
        let d = 0.45
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var lp = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            // Air rushing past: noise through an opening low-pass
            let noise  = Double.random(in: -1...1, using: &rng)
            let cutoff = 0.035 + 0.30 * p * p
            lp += (noise - lp) * cutoff
            var s = lp * envelope(p, attack: 0.15, release: 0.30) * 0.9
            // Shimmer at the end — light catching the comet's tail
            if p > 0.62 {
                let tt = (p - 0.62) / 0.38
                s += (sin(2 * .pi * 2105 * t) + sin(2 * .pi * 2118 * t)) * 0.5
                     * exp(-tt * 3.5) * 0.10 * min(1, tt * 4)
            }
            data[i] = Float(max(-1, min(1, s)))
        }
        return buf
    }

    /// FIREFLY — a soft chime, gentle and airy. Two warm detuned partials
    /// over a breath of filtered noise, 0.7 s, nothing sharp anywhere.
    private func makeStyleChime() -> AVAudioPCMBuffer? {
        let d = 0.7
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var lp = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            // Warm pair around G5, slightly detuned for slow beating
            var s = sin(2 * .pi * 784 * t) * exp(-t * 4.2) * 0.5
            s += sin(2 * .pi * 789 * t) * exp(-t * 4.6) * 0.4
            s += sin(2 * .pi * 1568 * t) * exp(-t * 7.0) * 0.12
            // The airy part — barely-there high noise breath
            let noise = Double.random(in: -1...1, using: &rng)
            lp += (noise - lp) * 0.35
            s += lp * 0.05 * exp(-t * 3.0)
            data[i] = Float(s * 0.5 * envelope(p, attack: 0.06, release: 0.5))
        }
        return buf
    }

    /// CATCH REVEAL — a soft bell with shimmer. Decaying inharmonic
    /// partials (bell), detuned highs blooming after (shimmer). 0.9 s.
    private func makeStyleBell() -> AVAudioPCMBuffer? {
        let d = 0.9
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        // Soft bell partials — rounded, never church-bell loud
        let partials: [(f: Double, a: Double, decay: Double)] = [
            (523.25, 0.50, 3.2),   // C5
            (659.25, 0.28, 4.0),   // E5
            (1046.5, 0.18, 5.5),   // C6
            (1318.5, 0.10, 6.5),   // E6
        ]
        let shimmer: [Double] = [2093, 2102, 2637, 2649]
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for partial in partials {
                s += sin(2 * .pi * partial.f * t) * partial.a * exp(-t * partial.decay)
            }
            // Shimmer blooms slightly after the strike
            if t > 0.08 {
                let tt = t - 0.08
                for (k, f) in shimmer.enumerated() {
                    s += sin(2 * .pi * f * tt) * 0.04 * exp(-tt * (5.0 + Double(k)))
                }
            }
            let attack = min(1, t / 0.012)
            data[i] = Float(s * 0.45 * attack)
        }
        return buf
    }

    /// SENDER CAUGHT — 80 ms of soft shimmer, the smallest sound in the
    /// app. A held breath of high detuned light, gone before it registers
    /// as a notification.
    private func makeStyleShimmer() -> AVAudioPCMBuffer? {
        let d = 0.08
        guard let (buf, data, n) = makeBuffer(duration: d) else { return nil }
        let tones: [Double] = [1760, 1767, 2217, 2226]
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            var s = 0.0
            for (k, f) in tones.enumerated() {
                s += sin(2 * .pi * f * t) * exp(-t * (18 + Double(k) * 3))
            }
            data[i] = Float(s * 0.12 * envelope(p, attack: 0.25, release: 0.45))
        }
        return buf
    }

    // MARK: - Synthesis plumbing

    private func makeBuffer(duration: Double) -> (AVAudioPCMBuffer, UnsafeMutablePointer<Float>, Int)? {
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard let buf  = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frames
        return (buf, data, Int(frames))
    }

    private func envelope(_ p: Double, attack: Double, release: Double) -> Double {
        if p < attack       { return p / attack }
        if p > 1 - release  { return max(0, (1 - p) / release) }
        return 1
    }

    private func sweepPhase(_ t: Double, f0: Double, f1: Double, d: Double) -> Double {
        2 * .pi * (f0 * t + (f1 - f0) * t * t / (2 * d))
    }

    /// Plays a buffer on a throwaway player node, detached when finished.
    private func play(_ buffer: AVAudioPCMBuffer, volume: Float) {
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: buffer.format)
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { engine.detach(node); return }

        node.volume = isQuiet ? volume * 0.4 : volume
        node.scheduleBuffer(buffer) { [weak self] in
            DispatchQueue.main.async {
                node.stop()
                self?.engine.detach(node)
            }
        }
        node.play()
    }
}
