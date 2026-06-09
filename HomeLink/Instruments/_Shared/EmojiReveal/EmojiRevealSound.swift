// EmojiRevealSound.swift
// Pointward › Instruments › _Shared › EmojiReveal
//
// RULES:
// Sound plays ONLY at reveal moment
// NEVER during send or receipt animation
// Each emoji has its own sound file
// Files in: HomeLink/Sounds/Emoji/
//
// APPROVED SOUNDS:
// 🤗 emoji_hug_v2.wav  2.8s ✅ approved
//    breath + 3 heartbeat pulses
//    synced to arm squeeze animation
// 😘 emoji_kiss.wav    ✅
// 🙌 emoji_celebration.wav ✅
// 👊 emoji_fistbump.wav ✅
// 🖐️ emoji_highfive.wav ✅
// 🫶 emoji_hearthands.wav ✅
//
// TO ADD NEW EMOJI SOUND:
// 1. Add .wav to Sounds/Emoji/
// 2. Add case to soundFile() below
// 3. Done — no other changes needed

import AudioToolbox

enum EmojiRevealSound {

    /// Cache: filename → created system sound id (built once per file).
    private static var soundIDs: [String: SystemSoundID] = [:]

    static func play(_ emoji: String) {
        guard let filename = soundFile(emoji) else {
            return
        }
        if let id = soundIDs[filename] {
            AudioServicesPlaySystemSound(id)
            return
        }
        // The synchronized file group flattens Sounds/Emoji/*.wav into the
        // bundle root, so look there first, then in the structured subdirectory
        // (covers both flattened and folder-reference builds).
        guard let url = Bundle.main.url(forResource: filename, withExtension: "wav")
            ?? Bundle.main.url(forResource: filename, withExtension: "wav",
                               subdirectory: "Sounds/Emoji")
            ?? Bundle.main.url(forResource: filename, withExtension: "wav",
                               subdirectory: "Sounds")
        else {
            print("Emoji sound missing: \(filename).wav")
            return
        }
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        soundIDs[filename] = soundID
        AudioServicesPlaySystemSound(soundID)
    }

    private static func soundFile(
        _ emoji: String
    ) -> String? {
        switch emoji {
        case "🤗": return "emoji_hug_v2"
        case "😘": return "emoji_kiss"
        case "🙌": return "emoji_celebration"
        case "👊": return "emoji_fistbump"
        case "🖐️": return "emoji_highfive"
        case "🫶": return "emoji_hearthands"
        default:   return nil
        }
    }
}
