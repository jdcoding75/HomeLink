// FlickSounds.swift
// Pointward › Instruments › Flick
//
// STATUS:
// flick_send.wav     ✅ real paper snap (~0.3s external asset, NOT from the
//                    silent generator below). Boosted ~+2 dB RMS so the
//                    compass snap reads one notch louder (it was already at
//                    the player's volume ceiling) — see FlickDeskCompassFace.
// flick_receipt.wav  ✅ real thwack (~0.4s external asset, NOT from generator)
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
