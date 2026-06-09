// BowSounds.swift
// Pointward › Instruments › Bow
//
// STATUS:
// bow_send.wav     0.8s  ⏳ placeholder (silent) — pending approval
// bow_receipt.wav  1.1s  ⏳ placeholder (silent) — pending approval
//
// CHARACTER:
// Send: wood creak under tension building, then a
//       sharp CRACK of release followed by a high
//       Doppler whistle fading to nothing.
// Receipt: sharp metallic THUNK into the target with
//       a brief vibration tail.
//
// TO REGENERATE: python3 BowSoundGenerator.py
//
// ElevenLabs prompt (send):
// "Compound bow release sound, sharp crack
//  followed by high pitched arrow whistle doppler
//  fading away quickly, 0.8 seconds total"
//
// ElevenLabs prompt (receipt):
// "Arrow hitting archery target, sharp thud with
//  brief vibration, 1.1 seconds"

enum BowSounds {
  static let sendFile = "bow_send"
  static let receiptFile = "bow_receipt"
  static let sendDuration: Double = 0.8
  static let receiptDuration: Double = 1.1
}
