// PlaneSounds.swift — FINAL
// Pointward › Instruments › Plane
//
// All soft, gentle, minimal — like a distant toy plane. Pure filtered noise.
//
// COMPASS FACE: plane_prop_idle (loop) → plane_prop_spinup (winding)
// SEND:    plane_flight.wav  5.0s ✅  (+ plane_launch.wav cue at launch)
// RECEIPT: plane_flight.wav  5.0s ✅  (+ plane_drop.wav, plane_catch.wav cues)
// EMOJI:   handled by EmojiRevealSound
//
// All sounds generated and durations match InstrumentBoundaries.
// TO REGENERATE: python3 PlaneSoundGenerator.py

enum PlaneSounds {
  // The full send/receipt voice (the gentle 5s flight ambient).
  static let sendFile = "plane_flight"
  static let receiptFile = "plane_flight"
  static let sendDuration: Double = 5.0
  static let receiptDuration: Double = 5.0

  // Per-phase one-shot cues (layered via InstrumentSoundPlayer.playCue).
  static let propIdleFile   = "plane_prop_idle"
  static let propSpinupFile = "plane_prop_spinup"
  // COMPASS wind-circle cue — an ultra-light rubber-band propeller wind-up
  // (replaces the harsh "plane.wind" ratchet click). Compass face only.
  static let windupFile     = "plane_windup"
  static let windupDuration: Double = 0.55
  static let launchFile     = "plane_launch"
  static let flightFile     = "plane_flight"
  static let approachFile   = "plane_approach"   // receipt: plane growing toward the viewer
  static let dropFile       = "plane_drop"
  static let catchFile      = "plane_catch"
}
