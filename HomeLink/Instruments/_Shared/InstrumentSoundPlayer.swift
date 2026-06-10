// InstrumentSoundPlayer.swift
// Pointward › Instruments › _Shared
//
// FILE-BASED instrument sound playback.
//
// NOTE ON COEXISTENCE:
// The shipping app currently synthesizes instrument
// voices programmatically in SoundEngine.swift
// ("no audio files"). This player is the FOUNDATION
// for the file-based system described in each
// instrument's [Name]Sounds.swift creative brief.
// It is intentionally NOT yet wired into the live
// send/receipt pipeline — adopting it is a future,
// deliberate step. Nothing here changes current
// behavior; it simply provides a clean, shared way
// to play the per-instrument .wav files once they
// are approved and the call sites are switched over.
//
// THE RULES (from InstrumentBoundaries):
// - Sound duration MUST equal animation duration
// - Fade in:  first 2% of duration
// - Fade out: last  5% of duration
// - Send sound never plays during receipt
// - Receipt sound never plays during send
// - Emoji sound ONLY at the reveal moment
//
// Files live flat in the bundle (the synchronized
// file group flattens Sounds/Instruments/*.wav), so
// lookup is by base name + "wav" — matching how
// SoundEngine loads the curated emoji files today.

import AVFoundation

final class InstrumentSoundPlayer {

  static let shared = InstrumentSoundPlayer()

  /// Which phase a sound belongs to — used to enforce
  /// the "send never overlaps receipt" rule.
  enum Phase {
    case send
    case receipt
    case reveal
  }

  private var players: [String: AVAudioPlayer] = [:]
  private var currentPhase: Phase?

  private init() {
    // Ambient: respects the silent switch, mixes with
    // the user's music — same posture as SoundEngine.
    try? AVAudioSession.sharedInstance()
      .setCategory(.ambient, options: [.mixWithOthers])
  }

  // MARK: - Public API

  /// Play an instrument sound file for a given phase.
  /// Stops any sound from a different phase first, so
  /// send and receipt never overlap.
  ///
  /// - Parameters:
  ///   - file: base name, e.g. "wind_send"
  ///   - phase: send / receipt / reveal
  ///   - duration: the matching animation duration —
  ///     used to schedule the fade-out. Pass the
  ///     instrument's value from InstrumentBoundaries.
  ///   - proIntensity: 1.0 free, 1.3 pro (volume lift)
  func play(
    file: String,
    phase: Phase,
    duration: Double,
    proIntensity: Float = 1.0
  ) {
    // Enforce phase exclusivity.
    if let active = currentPhase, active != phase {
      stopAll()
    }
    currentPhase = phase

    guard let player = player(for: file) else { return }

    let peak = min(1.0, 0.85 * proIntensity)

    // Fade in over the first 2% of the duration.
    player.volume = 0
    player.currentTime = 0
    player.play()
    player.setVolume(peak,
                     fadeDuration: duration * 0.02)

    // Fade out over the last 5% of the duration.
    let fadeOutLead = duration * 0.05
    let fadeOutStart = max(0, duration - fadeOutLead)
    DispatchQueue.main.asyncAfter(
      deadline: .now() + fadeOutStart
    ) { [weak player] in
      player?.setVolume(0, fadeDuration: fadeOutLead)
    }
  }

  // MARK: - Per-instrument convenience

  /// Play the SEND sound for an instrument (file + duration matched).
  /// Currently only WIND is approved/wired; others are no-ops until their
  /// .wav files land.
  func playSend(_ instrument: Instrument, proIntensity: Float = 1.0) {
    guard let (file, dur) = Self.sendInfo(instrument) else { return }
    play(file: file, phase: .send, duration: dur, proIntensity: proIntensity)
  }

  /// Play the RECEIPT sound for an instrument (file + duration matched).
  func playReceipt(_ instrument: Instrument, proIntensity: Float = 1.0) {
    guard let (file, dur) = Self.receiptInfo(instrument) else { return }
    play(file: file, phase: .receipt, duration: dur, proIntensity: proIntensity)
  }

  /// Send file + duration per instrument. WIND: wind_send.wav · 6.5s.
  private static func sendInfo(_ instrument: Instrument) -> (String, Double)? {
    switch instrument {
    case .firefly: return (WindSounds.sendFile, WindSounds.sendDuration)
    case .rocket:  return (RocketSounds.sendFile, RocketSounds.sendDuration)
    case .bow:     return (BowSounds.sendFile, BowSounds.sendDuration)
    case .flick:   return (FlickSounds.sendFile, FlickSounds.sendDuration)
    default:       return nil
    }
  }

  /// Receipt file + duration per instrument.
  /// WIND: wind_receipt.wav · 7.2s · ROCKET: rocket_receipt.wav · 7.75s.
  private static func receiptInfo(_ instrument: Instrument) -> (String, Double)? {
    switch instrument {
    case .firefly: return (WindSounds.receiptFile, WindSounds.receiptDuration)
    case .rocket:  return (RocketSounds.receiptFile, RocketSounds.receiptDuration)
    case .bow:     return (BowSounds.receiptFile, BowSounds.receiptDuration)
    case .flick:   return (FlickSounds.receiptFile, FlickSounds.receiptDuration)
    default:       return nil
    }
  }

  // MARK: - One-off cue files (not phase-exclusive)

  /// Play a short cue file directly (e.g. the bow arrow whistle during flight,
  /// or the sparkle-dissolve at the receipt's dissolve moment). These layer on
  /// top of the current phase rather than replacing it, so they do NOT change
  /// `currentPhase` or stop the send/receipt voice.
  func playCue(file: String, duration: Double, proIntensity: Float = 1.0) {
    guard let player = player(for: file) else { return }
    let peak = min(1.0, 0.8 * proIntensity)
    player.volume = 0
    player.currentTime = 0
    player.play()
    player.setVolume(peak, fadeDuration: max(0.01, duration * 0.05))
    let fadeOutLead = duration * 0.1
    DispatchQueue.main.asyncAfter(deadline: .now() + max(0, duration - fadeOutLead)) { [weak player] in
      player?.setVolume(0, fadeDuration: fadeOutLead)
    }
  }

  /// Stop everything immediately (e.g. on cancel).
  func stopAll() {
    for (_, p) in players { p.stop() }
    currentPhase = nil
  }

  // MARK: - Cache

  private func player(for file: String) -> AVAudioPlayer? {
    if let cached = players[file] { return cached }
    guard let url = Bundle.main.url(
      forResource: file, withExtension: "wav"
    ) else {
      #if DEBUG
      print("[InstrumentSoundPlayer] missing: \(file).wav")
      #endif
      return nil
    }
    guard let p = try? AVAudioPlayer(contentsOf: url) else {
      return nil
    }
    p.prepareToPlay()
    players[file] = p
    return p
  }
}
