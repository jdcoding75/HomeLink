// PlaneSounds.swift
// Pointward › Instruments › Plane
//
// STATUS:
// plane_send.wav     5.0s  ⏳ placeholder (silent) — pending approval
// plane_receipt.wav  5.0s  ⏳ placeholder (silent) — pending approval
//
// CHARACTER:
// Send: toy propeller winding up — light mechanical
//       whir getting faster, then full speed fading
//       as the plane flies away.
// Receipt: propeller approaching and growing louder,
//       a loud flyover pass, then engine slowing,
//       wheels touching, propeller winding down.
//
// TO REGENERATE: python3 PlaneSoundGenerator.py
//
// ElevenLabs prompt (send):
// "Small toy airplane propeller sound, starts slow
//  winding up to full speed, light and charming,
//  5 seconds total"
//
// ElevenLabs prompt (receipt):
// "Small toy airplane landing sound, propeller
//  slowing down, gentle touchdown, charming and
//  light, 5 seconds total"

enum PlaneSounds {
  static let sendFile = "plane_send"
  static let receiptFile = "plane_receipt"
  static let sendDuration: Double = 5.0
  static let receiptDuration: Double = 5.0
}
