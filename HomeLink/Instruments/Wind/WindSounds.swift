// WindSounds.swift
// Pointward › Instruments › Wind
//
// STATUS:
// wind_send.wav     6.5s  ⏳ placeholder (silent) — pending approval
// wind_receipt.wav  7.2s  ⏳ placeholder (silent) — pending approval
//
// CHARACTER:
// Send: silence → breath → organic swirl →
//       build → departure fade
// Receipt: arrives full → long gradient
//          fade to silence at landing
//
// TO REGENERATE: python3 WindSoundGenerator.py
//
// ElevenLabs prompt (send):
// "Gentle organic wind building from near
//  silence to full presence, pure wind
//  no music or tones, 6.5 seconds total"
//
// ElevenLabs prompt (receipt):
// "Wind arriving and gradually settling
//  to silence, same character as send,
//  7.2 seconds total"

enum WindSounds {
  static let sendFile = "wind_send"
  static let receiptFile = "wind_receipt"
  static let sendDuration: Double = 6.5
  static let receiptDuration: Double = 7.2

  // ACT 1 — the compass face plays NO sound.
  // Reason: the user's own breath IS the sound.
  // WindSounds.compassFaceSound = .none
}
