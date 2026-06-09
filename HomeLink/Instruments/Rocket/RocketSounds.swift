// RocketSounds.swift
// Pointward › Instruments › Rocket
//
// STATUS:
// rocket_send.wav     4.0s  ⏳ placeholder (silent) — pending approval
// rocket_receipt.wav  4.0s  ⏳ placeholder (silent) — pending approval
//
// CHARACTER:
// Send: deep subwoofer rumble building from near
//       silence over ~2.5s, full-spectrum burst at
//       ignition, crackling fire exhaust tail.
// Receipt: same rumble character but descending —
//       roar fades to thruster burns, then silence
//       at touchdown.
//
// TO REGENERATE: python3 RocketSoundGenerator.py
//
// ElevenLabs prompt (send):
// "Deep rumbling rocket launch sound, starting
//  almost silent, building over 2 seconds to a
//  thunderous roar with crackling fire exhaust
//  tail, 4 seconds total, very bass heavy"
//
// ElevenLabs prompt (receipt):
// "Rocket descending and landing, deep rumble
//  fading to thruster burns then silence at
//  touchdown, 4 seconds total, bass heavy"

enum RocketSounds {
  static let sendFile = "rocket_send"
  static let receiptFile = "rocket_receipt"
  static let sendDuration: Double = 4.0
  static let receiptDuration: Double = 4.0
}
