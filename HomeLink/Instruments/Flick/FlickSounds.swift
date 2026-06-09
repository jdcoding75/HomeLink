// FlickSounds.swift
// Pointward › Instruments › Flick
//
// STATUS:
// flick_send.wav     0.7s  ⏳ placeholder (silent) — pending approval
// flick_receipt.wav  1.0s  ⏳ placeholder (silent) — pending approval
//
// CHARACTER:
// Send: a single sharp paper snap — like flicking a
//       thick sticky note. Crisp and satisfying.
// Receipt: subtle paper flutter then a solid THWACK
//       of the note slapping onto the cork board with
//       a brief vibration.
//
// TO REGENERATE: python3 FlickSoundGenerator.py
//
// ElevenLabs prompt (send):
// "Paper flick snap sound, single sharp snap like
//  flicking a sticky note, 0.7 seconds"
//
// ElevenLabs prompt (receipt):
// "Sticky note slapping onto a cork board, sharp
//  thwack sound with brief vibration, 1.0 seconds"

enum FlickSounds {
  static let sendFile = "flick_send"
  static let receiptFile = "flick_receipt"
  static let sendDuration: Double = 0.7
  static let receiptDuration: Double = 1.0
}
