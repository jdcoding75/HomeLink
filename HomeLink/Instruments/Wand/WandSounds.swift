// WandSounds.swift
// Pointward › Instruments › Wand
//
// STATUS:
// wand_send.wav     2.0s  ⏳ placeholder (silent) — pending approval
// wand_receipt.wav  1.1s  ⏳ placeholder (silent) — pending approval
//
// CHARACTER:
// Send: crystal resonance building like a struck
//       singing bowl, then ~0.1s of complete silence
//       (the supernova moment), then a bright sparkle
//       burst.
// Receipt: a cluster of crystal chimes sounding
//       simultaneously — bright and mystical.
//
// TO REGENERATE: python3 WandSoundGenerator.py
//
// ElevenLabs prompt (send):
// "Magical wand charging sound, crystal resonance
//  building in intensity, then brief silence
//  followed by sparkle burst, 2 seconds total,
//  mystical and bright"
//
// ElevenLabs prompt (receipt):
// "Magical sparkle arrival sound, multiple crystal
//  chimes simultaneously, bright and mystical,
//  1.1 seconds"

enum WandSounds {
  static let sendFile = "wand_send"
  static let receiptFile = "wand_receipt"
  static let sendDuration: Double = 2.0
  static let receiptDuration: Double = 1.1
}
