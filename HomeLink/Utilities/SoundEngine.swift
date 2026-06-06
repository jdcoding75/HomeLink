// SoundEngine.swift
// Pointward › Utilities
//
// Programmatic sound synthesis for "send a thought" — every sound is
// generated sample-by-sample in Swift and played through AVAudioEngine.
// No audio files anywhere.
//
// Each emoji has its own designed voice (see the play(for:) dispatch):
// warm sine pulses for love, filtered noise and distorted rumbles for
// feeling. Volumes are mixed subtle-and-warm vs aggressive per lane,
// and everything drops to 40% in quiet mode.

import AVFoundation

final class SoundEngine {

    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let format: AVAudioFormat

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        // Ambient: respects the silent switch, mixes with the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    private var isQuiet: Bool { UserDefaults.standard.bool(forKey: "quietMode") }

    // MARK: - Dispatch

    /// Play the designed sound for an emoji token. Fire-and-forget;
    /// returns immediately so it runs simultaneously with the animation.
    func play(for token: String) {
        switch token {
        case "💜":    playHeart()
        case "💋":    playKiss()
        case "🫂":    playLaugh()
        case "🌸":    playBlossom()
        case "gecko": playGecko()
        case "✨":    playSparkle()
        case "😢":    playSad()
        case "😤":    playFrustrated()
        case "🤬":    playAngry()
        case "⚡️":    playLightning()
        case "🔥":    playFire()
        case "💨":    playFart()
        default:      break
        }
    }

    // MARK: - With love

    /// 💜 Soft warm sine pulse, 440→520 Hz over 0.8 s, gentle fades.
    func playHeart() {
        let d = 0.8
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            let phase = sweepPhase(t, f0: 440, f1: 520, d: d)
            let tone  = sin(phase) + 0.3 * sin(phase * 2)   // warm second partial
            data[i] = Float(tone * 0.22 * envelope(p, attack: 0.30, release: 0.40))
        }
        play(buf, volume: 0.5)
    }

    /// 💋 Exaggerated kiss — sharp lip smack, then a comic rounded "mwah"
    /// whose pitch swoops up and falls away. 0.5 s. Unmistakably a kiss.
    func playKiss() {
        let d = 0.5
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
        var rng = SystemRandomNumberGenerator()
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            // Sharp lip smack: noise pop + a bright resonant ping
            if t < 0.045 {
                s += Double.random(in: -1...1, using: &rng) * exp(-t * 120) * 1.2
                s += sin(2 * .pi * 1400 * t) * exp(-t * 90) * 0.8
            }
            // The "mwah": pitch swoops 320→540, then falls comically to 240
            if t >= 0.06 {
                let tt = t - 0.06
                let dd = d - 0.06
                let f: Double = tt < 0.10
                    ? 320 + 2200 * tt
                    : 540 - 300 * ((tt - 0.10) / (dd - 0.10))
                phase += 2 * .pi * f / sampleRate
                let tone = sin(phase) + 0.4 * sin(2 * phase)   // warm, rounded
                s += tone * envelope(tt / dd, attack: 0.12, release: 0.35) * 0.7
            }
            data[i] = Float(max(-1, min(1, s * 0.6)))
        }
        play(buf, volume: 0.65)
    }

    /// 🫂 Warm laughter — four quick "ha" bursts, each a falling voiced tone
    /// with a breathy onset, fading gently across the run. Joyful, not mocking. 0.8 s.
    func playLaugh() {
        let d = 0.8
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
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
                // Voiced "a": fundamental falling ~60 Hz with warm harmonics
                let ph = sweepPhase(tt, f0: ha.f0, f1: ha.f0 - 60, d: 0.15)
                let voice = sin(ph) + 0.5 * sin(2 * ph) + 0.25 * sin(3 * ph)
                // Breathy "h" onset
                let breath = Double.random(in: -1...1, using: &rng) * exp(-tt * 50) * 0.5
                let fade = 1.0 - Double(idx) * 0.12   // each ha a touch softer
                s += (voice * envelope(pp, attack: 0.18, release: 0.45) * 0.5 + breath) * fade
            }
            data[i] = Float(max(-1, min(1, s * 0.45)))
        }
        play(buf, volume: 0.55)
    }

    /// 🌸 Three ascending chimes — C5, E5, G5 — overlapping. Light and delicate.
    func playBlossom() {
        let d = 0.65
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
        let notes: [(start: Double, f: Double)] = [(0.00, 523.25), (0.15, 659.25), (0.30, 783.99)]
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for note in notes where t >= note.start && t < note.start + 0.3 {
                let tt = t - note.start
                s += sin(2 * .pi * note.f * tt)
                   * envelope(tt / 0.3, attack: 0.08, release: 0.55)
            }
            data[i] = Float(s * 0.18)
        }
        play(buf, volume: 0.5)
    }

    /// 🦎 Rapid soft clicks — five quick pips, like a real leopard gecko chirp.
    func playGecko() {
        let d = 0.45
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
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
        play(buf, volume: 0.5)
    }

    /// ✨ High shimmer — randomized pings 800–1200 Hz over 0.6 s.
    func playSparkle() {
        let d = 0.6
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
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
        play(buf, volume: 0.5)
    }

    // MARK: - With feeling

    /// 😢 Soft descending tone 400→220 Hz with a slight vibrato. Melancholy. 1.2 s.
    func playSad() {
        let d = 1.2
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
        var phase = 0.0   // incremental phase so the vibrato stays smooth
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            let f = 400 - 180 * p + 6 * sin(2 * .pi * 5.5 * t)
            phase += 2 * .pi * f / sampleRate
            let tone = sin(phase) + 0.25 * sin(2 * phase)
            data[i] = Float(tone * 0.22 * envelope(p, attack: 0.15, release: 0.30))
        }
        play(buf, volume: 0.55)
    }

    /// 😤 Sharp exhale — a 0.3 s burst of mid-resonant noise.
    func playFrustrated() {
        let d = 0.3
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
        var rng = SystemRandomNumberGenerator()
        let omega = 2 * Double.pi * 900 / sampleRate
        let r = 0.95
        var y1 = 0.0, y2 = 0.0
        for i in 0..<n {
            let p = Double(i) / Double(n)
            let x = Double.random(in: -1...1, using: &rng)
            let y = x + 2 * r * cos(omega) * y1 - r * r * y2
            y2 = y1; y1 = y
            let s = max(-1, min(1, y * 0.05)) * envelope(p, attack: 0.04, release: 0.50)
            data[i] = Float(s)
        }
        play(buf, volume: 0.8)
    }

    /// 🤬 Low aggressive rumble — 80→120 Hz, driven into distortion. 0.6 s.
    func playAngry() {
        let d = 0.6
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
        var rng = SystemRandomNumberGenerator()
        var phase = 0.0
        for i in 0..<n {
            let p = Double(i) / Double(n)
            let f = 80 + 40 * p
            phase += 2 * .pi * f / sampleRate
            var s = sin(phase) * 2.5
            s += 0.35 * Double.random(in: -1...1, using: &rng) * sin(phase)  // growl roughness
            s = tanh(s)                                                       // distortion
            data[i] = Float(s * 0.5 * envelope(p, attack: 0.08, release: 0.25))
        }
        play(buf, volume: 0.85)
    }

    /// ⚡️ Real thunder — a sharp electrical crack, then a deep rolling rumble
    /// (40–80 Hz) with a long natural decay. 1.5 s. Powerful and atmospheric.
    func playLightning() {
        let d = 1.5
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
        var rng = SystemRandomNumberGenerator()
        var prevX = 0.0
        var lp    = 0.0   // deep low-pass: the body of the rumble
        var roll  = 0.0   // very slow follower: the "rolling" undulation
        var phase = 0.0   // wandering sub-bass
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0

            // 1) The crack — instant attack, gone in ~80 ms
            if t < 0.08 {
                let x = Double.random(in: -1...1, using: &rng)
                let hp = x - 0.92 * prevX
                prevX = x
                s += hp * exp(-t * 60) * 0.9
            }

            // 2) The thunder — arrives right behind the crack and rolls away
            if t >= 0.05 {
                let tt = t - 0.05
                let x = Double.random(in: -1...1, using: &rng)
                lp   += 0.015  * (x - lp)          // keep only the lows
                roll += 0.0006 * (abs(x) - roll)   // slow amplitude undulation
                // Sub-bass wandering between 40 and 80 Hz
                let f = 60 + 20 * sin(2 * .pi * 0.7 * tt)
                phase += 2 * .pi * f / sampleRate
                let body   = lp * 6.0 + sin(phase) * 0.5
                let attack = min(1, tt / 0.06)     // sharp arrival
                let decay  = exp(-tt * 2.0)        // long thunder tail
                s += body * (0.5 + roll * 6) * attack * decay * 0.8
            }

            data[i] = Float(max(-1, min(1, s)))
        }
        play(buf, volume: 0.9)
    }

    /// 🔥 Igniting whoosh — resonant noise sweeping 400→2000 Hz with crackles. 0.8 s.
    func playFire() {
        let d = 0.8
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
        var rng = SystemRandomNumberGenerator()
        let r = 0.93
        var y1 = 0.0, y2 = 0.0
        for i in 0..<n {
            let p = Double(i) / Double(n)
            let fc = 400 + 1600 * p
            let omega = 2 * Double.pi * fc / sampleRate
            var x = Double.random(in: -1...1, using: &rng)
            if Double.random(in: 0...1, using: &rng) < 0.0015 { x += 3.0 }   // crackle
            let y = x + 2 * r * cos(omega) * y1 - r * r * y2
            y2 = y1; y1 = y
            let s = max(-1, min(1, y * 0.06)) * envelope(p, attack: 0.15, release: 0.30)
            data[i] = Float(s)
        }
        play(buf, volume: 0.85)
    }

    /// 💨 Classic wet fart — a sputtering 60–120 Hz buzz with a drunken pitch
    /// walk, irregular amplitude wobble, and a bubbly low-passed noise layer,
    /// drooping as it runs out of steam. 0.7 s. Unmistakable, comical, satisfying.
    func playFart() {
        let d = 0.7
        guard let (buf, data, n) = makeBuffer(duration: d) else { return }
        var rng = SystemRandomNumberGenerator()
        var phase    = 0.0
        var wobPhase = 0.0
        var f        = 95.0   // fundamental wanders within 60–120 Hz
        var lp       = 0.0    // wet/bubbly noise state
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let p = t / d
            // Drunken pitch walk, drooping ~25% by the end
            f = max(60, min(120, f + Double.random(in: -1.5...1.5, using: &rng)))
            phase += 2 * .pi * f * (1.0 - 0.25 * p) / sampleRate
            // Irregular sputter: 16–28 Hz amplitude wobble with random depth
            wobPhase += 2 * .pi * (22 + 6 * sin(2 * .pi * 3.1 * t)) / sampleRate
            let sputter = 0.55 + 0.45 * sin(wobPhase)
                          * (0.7 + 0.3 * Double.random(in: 0...1, using: &rng))
            // Wet texture: heavily low-passed noise riding the same sputter
            lp += 0.06 * (Double.random(in: -1...1, using: &rng) - lp)
            var s = (sin(phase) + 0.5 * sin(2 * phase)) * sputter + lp * 1.6 * sputter
            s = tanh(s * 1.8)   // body
            data[i] = Float(s * 0.5 * envelope(p, attack: 0.04, release: 0.30))
        }
        play(buf, volume: 0.85)
    }

    // MARK: - Synthesis plumbing

    private func makeBuffer(duration: Double) -> (AVAudioPCMBuffer, UnsafeMutablePointer<Float>, Int)? {
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard let buf  = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frames
        return (buf, data, Int(frames))
    }

    /// Linear attack/release envelope; attack/release as fractions of duration.
    private func envelope(_ p: Double, attack: Double, release: Double) -> Double {
        if p < attack       { return p / attack }
        if p > 1 - release  { return max(0, (1 - p) / release) }
        return 1
    }

    /// Phase of a linear frequency sweep f0→f1 over duration d, at time t.
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
