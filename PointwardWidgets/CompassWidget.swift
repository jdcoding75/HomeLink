// CompassWidget.swift
// PointwardWidgets — systemSmall home screen widget (Phase 1)
//
// Reads shared state from AppGroupStore (group.com.jdcoding75.pointward):
// the active person's name/emoji/tagline, last bearing, and distance.
// The main app refreshes these on every compass update and calls
// WidgetCenter.reloadAllTimelines(), so the widget stays fresh whenever
// the app runs; between app launches it shows the last-known needle.
//
// Shared files required in BOTH targets (app + PointwardWidgetsExtension):
//   AppGroupStore.swift, BearingCalculator.swift, TaglineSystem.swift,
//   CompassSkins.swift, DesignTokens.swift

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct CompassEntry: TimelineEntry {
    let date: Date
    let personName: String
    let personEmoji: String
    let bearing: Double
    let distanceKm: Double
    let tagline: String

    static func current(date: Date = .now) -> CompassEntry {
        CompassEntry(
            date:        date,
            personName:  AppGroupStore.activePersonName,
            personEmoji: AppGroupStore.activePersonEmoji,
            bearing:     AppGroupStore.activeBearing,
            distanceKm:  AppGroupStore.activeDistanceKm,
            tagline:     AppGroupStore.activeTagline
        )
    }

    static let placeholder = CompassEntry(
        date: .now, personName: "Mum", personEmoji: "🏠",
        bearing: 337.5, distanceKm: 142, tagline: TaglineSystem.defaultTagline
    )
}

struct CompassProvider: TimelineProvider {
    func placeholder(in context: Context) -> CompassEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CompassEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CompassEntry>) -> Void) {
        // The app pushes reloads on every update; this refresh interval is
        // just a fallback so the timestamp doesn't go stale.
        let entry = CompassEntry.current()
        let next  = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - View

struct CompassWidgetEntryView: View {
    var entry: CompassEntry

    @Environment(\.widgetFamily) private var family

    private let lavender   = Color(hex: "#c4a8d4")
    private let lavenderHi = Color(hex: "#e0ccee")
    private let purpleDeep = Color(hex: "#5a4870")
    private let dim        = Color(hex: "#7c6b8e")

    /// Short single-unit distance for the tight lock-screen layouts.
    private var compactDistance: String {
        if Locale.current.measurementSystem == .us {
            let miles = entry.distanceKm * 0.621371
            return miles >= 1 ? "\(Int(miles.rounded())) mi"
                              : "\(Int((miles * 5280).rounded())) ft"
        }
        return entry.distanceKm >= 1 ? "\(Int(entry.distanceKm.rounded())) km"
                                     : "\(Int((entry.distanceKm * 1000).rounded())) m"
    }

    private var cardinal: String {
        BearingCalculator.cardinalDirection(entry.bearing)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:    circularView
        case .accessoryRectangular: rectangularView
        case .accessoryInline:      inlineView
        default:                    smallView
        }
    }

    // MARK: Lock screen — circular: emoji inside a tiny needle ring

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Circle()
                .stroke(.secondary.opacity(0.5), lineWidth: 1)
                .padding(2)
            // Needle marker on the ring, pointing the live bearing
            Circle()
                .fill(.primary)
                .frame(width: 6, height: 6)
                .offset(y: -24)
                .rotationEffect(.degrees(entry.bearing))
            NeedleKite()
                .fill(.primary)
                .frame(width: 7, height: 12)
                .offset(y: -16)
                .rotationEffect(.degrees(entry.bearing))
            Text(entry.personEmoji)
                .font(.system(size: 22))
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: Lock screen — rectangular: emoji + name/distance + tagline

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Text(entry.personEmoji)
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.personName.isEmpty ? "Pointward" : entry.personName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("\(compactDistance) · \(cardinal)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(entry.tagline)
                    .font(.system(size: 10).italic())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: Lock screen — inline: "🏠 Mum · 142 km · NNW"

    private var inlineView: some View {
        Text("\(entry.personEmoji) \(entry.personName.isEmpty ? "Pointward" : entry.personName) · \(compactDistance) · \(cardinal)")
            .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: Home screen — systemSmall (unchanged)

    private var smallView: some View {
        VStack(spacing: 4) {
            Text(entry.personName.isEmpty ? "Pointward" : entry.personName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(lavenderHi)
                .lineLimit(1)

            // Mini compass face
            ZStack {
                Circle()
                    .stroke(dim.opacity(0.6), lineWidth: 1)
                Circle()
                    .stroke(dim.opacity(0.25), lineWidth: 0.5)
                    .padding(3)

                // Cardinal ticks
                ForEach(0..<8, id: \.self) { i in
                    let major = i % 2 == 0
                    Capsule()
                        .fill(dim.opacity(major ? 0.8 : 0.4))
                        .frame(width: major ? 1.5 : 1, height: major ? 6 : 4)
                        .offset(y: -34)
                        .rotationEffect(.degrees(Double(i) * 45))
                }

                // Needle
                ZStack {
                    NeedleKite()
                        .fill(lavender)
                        .frame(width: 9, height: 30)
                        .offset(y: -15)
                    NeedleKite()
                        .fill(purpleDeep)
                        .frame(width: 7, height: 20)
                        .rotationEffect(.degrees(180))
                        .offset(y: 10)
                }
                .rotationEffect(.degrees(entry.bearing))

                // Emoji at center
                Text(entry.personEmoji)
                    .font(.system(size: 15))
                    .background(
                        Circle()
                            .fill(Color(hex: "#0d0d14").opacity(0.75))
                            .frame(width: 24, height: 24)
                    )
            }
            .frame(width: 76, height: 76)

            Text(BearingCalculator.formattedDistance(entry.distanceKm))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(lavender)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .containerBackground(for: .widget) {
            ZStack {
                Color(hex: "#0d0d14")
                RadialGradient(
                    colors: [Color(hex: "#9b7fc0").opacity(0.15), .clear],
                    center: .center, startRadius: 5, endRadius: 90
                )
            }
        }
    }
}

/// Kite-shaped needle half (tip up, shoulders 30% above the pivot).
struct NeedleKite: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.30))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.30))
            p.closeSubpath()
        }
    }
}

// MARK: - Widget

struct CompassWidget: Widget {
    let kind: String = "CompassWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CompassProvider()) { entry in
            CompassWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pointward Compass")
        .description("The needle that points to them.")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular,     // lock screen: emoji in a needle ring
            .accessoryRectangular,  // lock screen: name · distance · tagline
            .accessoryInline,       // lock screen: above the clock
        ])
    }
}

@main
struct PointwardWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CompassWidget()
    }
}

#Preview(as: .systemSmall) {
    CompassWidget()
} timeline: {
    CompassEntry.placeholder
}
