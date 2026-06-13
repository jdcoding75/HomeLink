// BirthdaySounds.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// Sound constants for the Birthday cake instrument.
//
// MELODY:
// birthday_melody.wav — a gentle music-box / chime rendition of "Happy Birthday
// to You" that plays as a warm celebratory bed under BOTH the SEND and RECEIPT
// screens. Light and charming, never loud or brash (the file sits at ~0.6 full
// scale and the player layers it softly via playCue). It starts at the top of
// each screen and rings out across the animation.
//
// TO REGENERATE: python3 BirthdayMelodyGenerator.py
//
// (The short event cues — birthday_confetti / birthday_blow_first /
// birthday_blow_out / birthday_reveal — live in Sounds/Emoji and are referenced
// inline at their moment; only the melody bed is centralized here.)

enum BirthdaySounds {
  static let melodyFile = "birthday_melody"
  static let melodyDuration: Double = 14.45
}
