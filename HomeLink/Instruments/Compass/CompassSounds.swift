// CompassSounds.swift
// Pointward › Instruments › Compass
//
// STATUS:
// compass_send.wav     3.5s  ⏳ placeholder (silent) — pending approval
// compass_receipt.wav  1.5s  ⏳ placeholder (silent) — pending approval
//
// CHARACTER:
// Send: warm singing-bowl tone, gentle strike
//       building during hold then fading as the
//       orb departs. Intimate and peaceful.
// Receipt: same bowl arriving — tone descends
//       gently and resolves to silence.
//
// TO REGENERATE: python3 CompassSoundGenerator.py
//
// ElevenLabs prompt (send):
// "Warm soft singing bowl tone, gentle strike
//  building slowly then fading, intimate and
//  peaceful, 3.5 seconds"
//
// ElevenLabs prompt (receipt):
// "Soft singing bowl arrival tone, descending
//  gently to silence, peaceful and complete,
//  1.5 seconds"

enum CompassSounds {
  static let sendFile = "compass_send"
  static let receiptFile = "compass_receipt"
  static let sendDuration: Double = 3.5
  static let receiptDuration: Double = 1.5
}
