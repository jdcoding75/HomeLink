// ShortCode.swift
// Pointward › Utilities
//
// Phase 2 Build 4b — the short-code fallback (no-link receive path).
//
// A sender's per-user `short_code` (minted in the Build 2 migration) is the
// human-typable key a recipient enters when they have the app but NO link. The
// charset deliberately excludes the visually ambiguous characters
//   no O/0, no I/1/L  →  A–Z minus I,L,O  +  2–9
// so a 6-char code is easy to read off a screen and type back.
//
// These are PURE helpers (no I/O) so the entry UI and the claim split stay
// unit-testable; the actual fetch is SupabaseService.getUnopenedForShortCode.

import Foundation

enum ShortCode {

    /// Code length (matches the DB `gen_short_code()` generator).
    static let length = 6

    /// The unambiguous charset (matches the migration's generator exactly).
    static let charset = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

    /// Canonicalize typed input: uppercase + strip ALL whitespace. (We tolerate
    /// spaces and lowercase rather than over-policing; the server also uppercases,
    /// so this is belt-and-suspenders.) We intentionally do NOT strip "invalid"
    /// characters — an unknown code simply resolves to zero messages downstream.
    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
        })
    }

    /// A complete code is exactly `length` characters after normalization — used
    /// only to gate the confirm button (a gentle guide, not strict validation).
    static func isComplete(_ raw: String) -> Bool {
        normalize(raw).count == length
    }
}

/// The claim split: the RPC returns a sender's unopened messages NEWEST-FIRST.
/// The newest plays now (via the 4a receive chain); the rest drop into history.
enum ShortCodeClaim {

    /// Split a newest-first result into (the one to play, the ones to keep).
    /// Empty input → (nil, []) so the caller shows the empty state.
    static func split(_ messages: [Message]) -> (newest: Message?, rest: [Message]) {
        (messages.first, Array(messages.dropFirst()))
    }
}
