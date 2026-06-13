// CompassSounds.swift
// Pointward › Instruments › Compass
//
// STATUS:
// compass_send.wav     2.2s  ✅ synthesized — soft departing breath/whoosh
// compass_receipt.wav  1.5s  ✅ synthesized — warm welcoming chime
//
// CHARACTER:
// Send: a very soft, airy departing breath that
//       swells then drifts away, with a faint low
//       tone gliding down — a thought leaving.
// Receipt: a very soft, warm singing-bowl chime —
//       a gentle strike resolving to a long warm
//       decay. A warm welcome.
//
// TO REGENERATE: python3 CompassSoundGenerator.py
// (pure-stdlib synthesis lives in that script).
//
// ElevenLabs prompt (send):
// "Soft airy departing breath whoosh, gentle swell
//  then fading away, intimate and peaceful, 2.2s"
//
// ElevenLabs prompt (receipt):
// "Warm soft singing bowl arrival chime, gentle
//  strike resolving to a long warm decay, peaceful
//  and welcoming, 1.5 seconds"

enum CompassSounds {
  static let sendFile = "compass_send"
  static let receiptFile = "compass_receipt"
  static let sendDuration: Double = 2.2
  static let receiptDuration: Double = 1.5
}
