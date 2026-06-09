// WindSounds.swift — FINAL
// Pointward › Instruments › Wind
//
// COMPASS FACE: none (user breath)
// SEND:    wind_send.wav    6.5s ✅
// RECEIPT: wind_receipt.wav 7.2s ✅
// EMOJI:   emoji_hug_v2.wav 2.8s ✅
//          (handled by EmojiRevealSound)
//
// All sounds generated and approved
// All durations match InstrumentBoundaries
// Wind instrument sound system complete
//
// TO REGENERATE: python3 WindSoundGenerator.py

enum WindSounds {
  static let compassFaceSound: SoundCategory = .none
  static let sendFile = "wind_send"
  static let receiptFile = "wind_receipt"
  static let sendDuration: Double = 6.5
  static let receiptDuration: Double = 7.2
}
