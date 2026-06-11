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

/// The FIVE canonical stages of any Pointward animation (the new spec standard).
/// These names are the ONLY stage labels allowed anywhere in the UI. The old
/// "Reveal" stage is dropped — the reveal is the tail of Target, not a stage.
enum AnimationStage: String, CaseIterable, Identifiable {
    case compassIdle     = "Compass Idle"      // resting mechanism
    case compassCharging = "Compass Charging"  // mechanism IN ACTION (drawing, lighting, fuse)
    case send            = "Send"              // launch / the big moment
    case approach        = "Approach"          // payload travelling in
    case target          = "Target"            // payload landing in the bucket / settling

    var id: String { rawValue }

    /// Which underlying animation renders this stage. Idle+Charging share the
    /// compass face; Approach+Target share the receipt animation. Surfaces use
    /// this to play each underlying animation once in a full workflow.
    enum Source { case compass, send, receipt }
    var source: Source {
        switch self {
        case .compassIdle, .compassCharging: return .compass
        case .send:                          return .send
        case .approach, .target:             return .receipt
        }
    }
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
    // Instruments first (live V1 carries Compass + Reveal, which are shared/
    // version-agnostic; the extracted V2 rows carry only Send + Receipt).
    // Then the emoji mechanisms.
    static let all: [AnimationDefinition] = [
        // ── Instruments ──────────────────────────────────────────────────
        AnimationDefinition(
            icon: "🧭", name: "Compass", version: nil, style: .glow,
            instrument: .compass, kind: .instrument,
            stages: [.compassIdle, .compassCharging, .send, .approach, .target], fixedEmoji: nil),

        AnimationDefinition(
            icon: "🏹", name: "Bow", version: "V1", style: .bowArrow,
            instrument: .bow, kind: .instrument,
            stages: [.compassIdle, .compassCharging, .send, .approach, .target], fixedEmoji: nil),
        AnimationDefinition(
            icon: "🏹", name: "Bow", version: "V2", style: .bowArrow,
            instrument: .bow, kind: .instrument,
            stages: [.send, .approach, .target], fixedEmoji: nil),

        AnimationDefinition(
            icon: "👆", name: "Flick", version: "V1", style: .fingerFlick,
            instrument: .flick, kind: .instrument,
            stages: [.compassIdle, .compassCharging, .send, .approach, .target], fixedEmoji: nil),
        AnimationDefinition(
            icon: "👆", name: "Flick", version: "V2", style: .fingerFlick,
            instrument: .flick, kind: .instrument,
            stages: [.send, .approach, .target], fixedEmoji: nil),

        AnimationDefinition(
            icon: "🚀", name: "Rocket", version: nil, style: .rocket,
            instrument: .rocket, kind: .instrument,
            stages: [.compassIdle, .compassCharging, .send, .approach, .target], fixedEmoji: nil),

        AnimationDefinition(
            icon: "🌬️", name: "Wind", version: nil, style: .firefly,
            instrument: .firefly, kind: .instrument,
            stages: [.compassIdle, .compassCharging, .send, .approach, .target], fixedEmoji: nil),

        AnimationDefinition(
            icon: "🪄", name: "Wand", version: "V1", style: .wand,
            instrument: .wand, kind: .instrument,
            stages: [.compassIdle, .compassCharging, .send, .approach, .target], fixedEmoji: nil),

        AnimationDefinition(
            icon: "✈️", name: "Plane", version: "V1", style: .plane,
            instrument: .plane, kind: .instrument,
            stages: [.compassIdle, .compassCharging, .send, .approach, .target], fixedEmoji: nil),
        AnimationDefinition(
            icon: "✈️", name: "Plane", version: "V2", style: .plane,
            instrument: .plane, kind: .instrument,
            stages: [.send, .approach, .target], fixedEmoji: nil),

        // ── Emoji mechanisms (ship their own full mechanic) ───────────────
        AnimationDefinition(
            icon: "🎆", name: "Firework", version: nil, style: .glow,
            instrument: nil, kind: .emoji,
            stages: [.compassIdle, .compassCharging, .send, .approach, .target], fixedEmoji: "🎆"),

        AnimationDefinition(
            icon: "🎂", name: "Birthday Cake", version: "V1", style: .glow,
            instrument: nil, kind: .emoji,
            stages: [.compassIdle, .compassCharging, .approach, .target], fixedEmoji: "🎂"),
        AnimationDefinition(
            icon: "🎂", name: "Birthday Cake", version: "V2", style: .glow,
            instrument: nil, kind: .emoji,
            stages: [.compassIdle, .compassCharging, .send, .approach, .target], fixedEmoji: "🎂"),
    ]

    // ── Derived views of the catalog ─────────────────────────────────────

    /// All instrument-kind definitions, in catalog order.
    static var instruments: [AnimationDefinition] { all.filter { $0.kind == .instrument } }

    /// All emoji-kind definitions, in catalog order.
    static var emoji: [AnimationDefinition] { all.filter { $0.kind == .emoji } }

    /// The single live (V1 / nil-version) instrument row per instrument, in the
    /// user-facing order — the source for the "test all" runner and any place
    /// that wants "one of each instrument".
    static var liveInstruments: [AnimationDefinition] {
        instruments.filter { $0.version == nil || $0.version == "V1" }
    }

    static func definition(id: String) -> AnimationDefinition? { all.first { $0.id == id } }

    /// The live instrument definition for a routing style (V1 / nil-version).
    static func liveInstrument(for style: SenderStyle) -> AnimationDefinition? {
        liveInstruments.first { $0.style == style }
    }
}
