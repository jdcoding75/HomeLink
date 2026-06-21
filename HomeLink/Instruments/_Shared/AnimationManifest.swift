// AnimationManifest.swift
// Pointward › Instruments › _Shared
//
// THE SINGLE SOURCE OF TRUTH for every animation in Pointward — instrument
// mechanisms (compass · bow · flick · rocket · wind · wand · plane) AND emoji
// reveals that ship their own full mechanic (firework · birthday cake).
//
// WHY THIS EXISTS:
// Every surface that lists, previews, labels, or test-plays an animation used
// to keep its OWN private list. They drifted — the test lab grew mangled labels
// ("Firework Send Send"), the runner hard-coded a 7-tuple, the Pro preview and
// compass selector each re-derived names. This manifest ends that: an animation
// is registered HERE (with its version + the stages it provides + ONE canonical
// label) or it appears nowhere. Consistency by construction.
//
// CANONICAL STAGE NAMES (the only five, ever):
//   Compass Idle · Compass Charging · Send · Approach · Target
//
// CANONICAL LABEL FORMAT:
//   "<Instrument> <Version> — <Stage>"   e.g. "Bow V2 — Receipt"
//   (version omitted when there's only one)
//
// WHAT THIS MANIFEST IS NOT:
// It does NOT route or re-wire the live app. Per the framework, V1 stays the
// live path until explicitly promoted, and the compass mechanic is never
// rewritten. The manifest is the CATALOG — names, versions, stages, icons,
// styles — that every surface reads so none can disagree.

import SwiftUI

// MARK: - Stage

/// The THREE canonical stages of any Pointward animation. These names are the
/// ONLY stage labels allowed anywhere in the UI.
///
/// Collapsed from the old five (Compass Idle/Charging, Send, Approach, Target):
/// the compass mechanic plays rest→action as ONE watchable performance (no
/// idle/charging double-step), and the receipt plays approach→landing as ONE
/// continuous beat (no Approach/Target double-play). "Reveal" stays retired —
/// the reveal is the tail of Receipt, not a stage.
enum AnimationStage: String, CaseIterable, Identifiable {
    case compass = "Compass"   // the interactive mechanic, rest → action, ONCE
    case send    = "Send"      // launch / the big moment
    case receipt = "Receipt"   // approach → landing, ONE continuous beat

    var id: String { rawValue }
}

// MARK: - Kind

enum AnimationKind {
    case instrument   // a send-instrument personality (routes a real thought)
    case emoji        // an emoji that ships its own full mechanic
}

// MARK: - Definition

/// One catalogued animation. Keyed by name + optional version, it declares the
/// stages it can play and produces its own canonical labels.
struct AnimationDefinition: Identifiable, Hashable {
    let icon: String
    let name: String              // "Bow" · "Wind" · "Firework" · "Birthday Cake"
    let version: String?          // nil (single) · "V1" (live) · "V2" (extracted)
    let style: SenderStyle        // the personality its thoughts travel/land with
    let instrument: Instrument?   // nil for emoji-only animations
    let kind: AnimationKind
    let stages: [AnimationStage]  // which of the four stages this row provides
    /// Canonical glyph emoji-mechanic animations reveal (🎂 / 🎆); nil for
    /// instruments (which carry whatever feeling the user chose).
    let fixedEmoji: String?

    /// [bottom-band redesign] The feeling sent when the user performs the
    /// instrument gesture WITHOUT explicitly choosing an emoji — a default
    /// always supplies a payload, so the send is never gated on a selection.
    /// Set to 🤗 (hug) for ALL animations for now; `var` + default keeps every
    /// existing initializer in `all` unchanged while allowing a future
    /// per-animation override. Read via `effectiveToken`, never hardcoded at
    /// the send site.
    var defaultEmoji: String = "🤗"

    /// [per-instrument default message] The starting compose text when THIS instrument is
    /// selected — PREFERRED over the per-emoji `CuratedEmoji.defaultMessage` (which stays the
    /// fallback). Optional + default nil: an unset instrument keeps EXACTLY today's per-emoji
    /// behavior (no regression). Deliberate intermediate state (per-instrument preferred,
    /// per-emoji fallback) — NOT a full migration. Read via `CompassView.seedMessage`, never
    /// hardcoded at the seed site. Only Birthday sets a value today.
    var defaultMessage: String? = nil

    /// [per-instrument default tagline] FIELD ONLY — not yet wired (no values set). The
    /// traveling tagline currently rides from the selected PERSON
    /// (`people.selectedPerson?.tagline`), a different/entangled path than the message seed,
    /// so wiring is deliberately deferred. Added now so the manifest is the future home for a
    /// per-instrument tagline default. Default nil → zero effect today.
    var defaultTagline: String? = nil

    /// Stable id, e.g. "bow.v2" / "firework" / "compass".
    var id: String {
        let base = name.lowercased().replacingOccurrences(of: " ", with: "-")
        return version.map { "\(base).\($0.lowercased())" } ?? base
    }

    /// "Bow V2" · "Wand V1" · "Compass" · "Firework".
    var displayName: String { version.map { "\(name) \($0)" } ?? name }

    /// The ONE canonical label for a given stage: "<Instrument> <Version> — <Stage>".
    func label(for stage: AnimationStage) -> String {
        "\(displayName) — \(stage.rawValue)"
    }

    func provides(_ stage: AnimationStage) -> Bool { stages.contains(stage) }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (a: AnimationDefinition, b: AnimationDefinition) -> Bool { a.id == b.id }
}

// MARK: - Manifest

enum AnimationManifest {

    // The full catalog. ORDER MATTERS — surfaces present in this order.
    //
    // Instruments first. Every version (V1 AND V2) declares its FULL stage set
    // so each is a complete, selectable workflow in the test lab. The compass
    // (Idle + Charging) is the instrument's single shared face — version-
    // agnostic — so both V1 and V2 reference it; their Send + Approach + Target
    // differ (V1 = inline dispatcher path, V2 = the extracted ACT structs).
    // Then the emoji mechanisms.
    static let all: [AnimationDefinition] = [
        // ── Instruments ──────────────────────────────────────────────────
        AnimationDefinition(
            icon: "🧭", name: "Compass", version: nil, style: .glow,
            instrument: .compass, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: nil),

        AnimationDefinition(
            icon: "🏹", name: "Bow", version: "V1", style: .bowArrow,
            instrument: .bow, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: nil),
        AnimationDefinition(
            icon: "🏹", name: "Bow", version: "V2", style: .bowArrow,
            instrument: .bow, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: nil),

        AnimationDefinition(
            icon: "👆", name: "Flick", version: "V1", style: .fingerFlick,
            instrument: .flick, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: nil),
        AnimationDefinition(
            icon: "👆", name: "Flick", version: "V2", style: .fingerFlick,
            instrument: .flick, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: nil),

        // Rocket has THREE selectable receipts — all labeled. "Merged" is the
        // LIVE receipt: the legs-down landing + emoji-popped-from-the-cone into
        // the bucket, played over the parachute receipt's earth/bucket
        // environment (RocketLandingReceiptAnimation). The other two are kept
        // as labeled alternates for comparison: "Parachute" = the original v2
        // RocketReceiptAnimation; "Legs-down" = the raw RocketLanding lander.
        AnimationDefinition(
            icon: "🚀", name: "Rocket", version: "Merged", style: .rocket,
            instrument: .rocket, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: nil),
        AnimationDefinition(
            icon: "🚀", name: "Rocket", version: "Parachute", style: .rocket,
            instrument: .rocket, kind: .instrument,
            stages: [.receipt], fixedEmoji: nil),
        AnimationDefinition(
            icon: "🚀", name: "Rocket", version: "Legs-down", style: .rocket,
            instrument: .rocket, kind: .instrument,
            stages: [.receipt], fixedEmoji: nil),

        AnimationDefinition(
            icon: "🌬️", name: "Wind", version: nil, style: .firefly,
            instrument: .firefly, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: nil),

        AnimationDefinition(
            icon: "🪄", name: "Wand", version: "V1", style: .wand,
            instrument: .wand, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: nil),

        AnimationDefinition(
            icon: "✈️", name: "Plane", version: "V1", style: .plane,
            instrument: .plane, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: nil),
        AnimationDefinition(
            icon: "✈️", name: "Plane", version: "V2", style: .plane,
            instrument: .plane, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: nil),

        // ── Special moments — now FIRST-CLASS PEER INSTRUMENTS ─────────────
        // [special moments — peer animations] Reclassified from kind:.emoji /
        // instrument:nil / style:.glow → instruments with their OWN instrument +
        // style, so `liveInstruments` surfaces them as selectable picker cards and
        // the sender dispatch keys on selection/style (not the emoji). The default
        // PAYLOAD stays 🎁/🎆 (changeable); the fixedEmoji 🎂/🎆 remains the
        // canonical glyph used by the (Stage-3-pending) emoji-keyed receipt.
        // PRIOR (emoji-mechanism rows):
        //   icon "🎆" Firework      version nil  style .glow  instrument nil  kind .emoji
        //   icon "🎂" Birthday Cake version V1   style .glow  instrument nil  kind .emoji
        //   icon "🎂" Birthday Cake version V2   style .glow  instrument nil  kind .emoji
        AnimationDefinition(
            icon: "🎆", name: "Firework", version: nil, style: .firework,
            instrument: .firework, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: "🎆", defaultEmoji: "🎆"),

        // [STAGE 3 DONE] Birthday default restored to the intended 🎁 (gift). Safe
        // now: ReceiptView routes the arrival by `style == .birthday` (the wire
        // sender_style), not the emoji — so a 🎁 default birthday plays the cake on
        // the recipient. (Interim 🎂 was the Stage-2 stopgap for the emoji-keyed
        // recipient; flipped here with the Stage-3 re-key. Firework default 🎆
        // already matched its key.)
        AnimationDefinition(
            icon: "🎂", name: "Birthday Cake", version: "V1", style: .birthday,
            instrument: .birthday, kind: .instrument,
            stages: [.compass, .receipt], fixedEmoji: "🎂", defaultEmoji: "🎁", defaultMessage: "Happy Birthday"),  // [Stage 3] restored from interim 🎂; [per-instrument default] Birthday seeds "Happy Birthday" (others stay nil)
        AnimationDefinition(
            icon: "🎂", name: "Birthday Cake", version: "V2", style: .birthday,
            instrument: .birthday, kind: .instrument,
            stages: [.compass, .send, .receipt], fixedEmoji: "🎂", defaultEmoji: "🎁", defaultMessage: "Happy Birthday"),  // [Stage 3] restored from interim 🎂; [per-instrument default] Birthday seeds "Happy Birthday" (others stay nil)
    ]

    // ── Derived views of the catalog ─────────────────────────────────────

    /// All instrument-kind definitions, in catalog order.
    static var instruments: [AnimationDefinition] { all.filter { $0.kind == .instrument } }

    /// All emoji-kind definitions, in catalog order.
    static var emoji: [AnimationDefinition] { all.filter { $0.kind == .emoji } }

    /// One live row per instrument, in the user-facing order — the source for
    /// any place that wants "one of each instrument". Skips the secondary
    /// variants (V2, the rocket "Parachute"/"Legs-down" alternates) and dedups
    /// by style, so rocket's primary "Merged" (live) row wins.
    private static let secondaryVersions: Set<String> = ["V2", "Parachute", "Legs-down"]
    static var liveInstruments: [AnimationDefinition] {
        var seen = Set<SenderStyle>()
        return instruments
            .filter { !($0.version.map(secondaryVersions.contains) ?? false) }
            .filter { seen.insert($0.style).inserted }
    }

    static func definition(id: String) -> AnimationDefinition? { all.first { $0.id == id } }

    /// The live instrument definition for a routing style (V1 / nil-version).
    static func liveInstrument(for style: SenderStyle) -> AnimationDefinition? {
        liveInstruments.first { $0.style == style }
    }
}
