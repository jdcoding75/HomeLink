// DirectionalCatchReceiptLab.swift
// Pointward › Views (ANIMATION LAB — PROTOTYPE ONLY)
//
// ⚗️ LAB-ONLY CONCEPT — NOT wired into the live receipt pipeline. Reachable only
// from the Animation Test Lab ("Directional Catch (concept)"). Touches NO live
// file: CompassView / CompassManager / ReceiptView / the live receipts are all
// left alone.
//
// CONCEPT: the directional INVERSE of the send mechanic. The sender points AT the
// recipient; here the RECIPIENT turns their phone to align with the sender's
// direction in order to "receive" the thought. Align within 15° for 1.0 s → the
// thought arrives and hands off to the standard EmojiRevealView (same terminal
// beat as every other receipt). No bucket, no spin-to-catch.
//
// BEARING:
//   • Sender has a stored location (lat/lng) in the local people store → the REAL
//     bearing from the device's current location to that person, via the existing
//     BearingCalculator (same infra as the send compass).
//   • No stored location → a RANDOM bearing in [20°, 340°] (picked once, held
//     stable), which avoids 0/360 ± 10° so the user always has to physically turn.
//   Either way it's a pure feel-test: no location-passing, no server calls.
//
// HEADING SOURCE: CompassManager publishes no RAW device heading (only the
// relative `state.bearingDegrees` of a tracked located person), and the random
// case needs raw heading vs an arbitrary target — so this prototype runs its OWN
// tiny CLHeading reader, fully self-contained here. CompassManager is NOT touched.

import SwiftUI
import CoreLocation
import Combine

// MARK: - Self-contained heading + location reader (Lab-only)

/// A minimal CLLocationManager wrapper that publishes the live magnetic heading
/// and last known location. Exists only so this prototype can read raw heading
/// against an arbitrary target bearing without modifying CompassManager.
@MainActor
final class LabHeadingReader: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double = 0          // degrees, magnetic
    @Published var location: CLLocation?
    @Published var headingAvailable = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1               // degrees — smooth-ish updates
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            headingAvailable = true
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingHeading()
        manager.stopUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let h = newHeading.magneticHeading
        Task { @MainActor in self.heading = h }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in self.location = loc }
    }
}

// MARK: - The prototype

struct DirectionalCatchReceiptLab: View {

    /// Lab dismiss.
    var onFinished: () -> Void = {}

    @EnvironmentObject private var people: PeopleManager
    @StateObject private var reader = LabHeadingReader()

    // Demo values (Lab run).
    private let emoji: String
    private let senderName: String

    init(onFinished: @escaping () -> Void = {},
         senderName: String = "them",
         emoji: String = "🤗") {
        self.onFinished = onFinished
        self.senderName = senderName
        self.emoji = emoji
    }

    // Tunables (mirror the send compass; hold is shorter — a catch, not a deliberate send).
    private let alignThreshold: Double = 15      // same as the send compass start threshold
    private let holdDuration:   Double = 1.0     // slightly < the send's 1.33 s

    @State private var targetBearing: Double = 0
    @State private var bearingResolved = false
    @State private var usingRealBearing = false
    @State private var holdProgress: Double = 0
    @State private var wasAligned = false
    @State private var arrived = false

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    /// The sender's display name — the selected person's, falling back to the init value ("them").
    private var displayName: String {
        if let n = people.selectedPerson?.name, !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
        return senderName
    }

    // Relative bearing the user must zero out: target − heading, normalised [0,360).
    private var relativeBearing: Double {
        (targetBearing - reader.heading + 360).truncatingRemainder(dividingBy: 360)
    }
    private var alignmentError: Double {
        BearingCalculator.alignmentError(relativeBearing: relativeBearing)
    }

    var body: some View {
        ZStack {
            DesignTokens.Color.background.ignoresSafeArea()

            if arrived {
                // Same terminal beat as every receipt.
                EmojiRevealView(emoji: emoji, message: nil, tagline: nil,
                                context: .received(fromName: displayName),
                                ambient: .compass,
                                onDismiss: onFinished)
                    .transition(.opacity)
            } else {
                catchScreen
            }
        }
        .onAppear {
            reader.start()
            resolveTargetBearing()
        }
        .onDisappear { reader.stop() }
        .onReceive(tick) { _ in advanceHold() }
    }

    // MARK: - Catch screen

    private var catchScreen: some View {
        VStack(spacing: 26) {

            // Close affordance (Lab exit before aligning).
            HStack {
                Button("close") { onFinished() }
                    .font(DesignTokens.Font.label)
                    .foregroundColor(DesignTokens.Color.textMuted)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.top, DesignTokens.Spacing.md)

            Spacer()

            // Instruction — serif, warm (matches the send screen voice).
            Text("Turn toward \(displayName) to receive your thought ✦")
                .font(.system(size: 21, design: .serif).italic())
                .foregroundColor(DesignTokens.Color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 36)

            // The vintage dial (rose spins so N keeps pointing to real north) +
            // the shared DirectionIndicator marker, which floats at the sender's
            // relative bearing and brightens as the aim closes in.
            ZStack {
                SkinFaceView(skin: .vintage,
                             bearing: relativeBearing,
                             locked: alignmentError <= alignThreshold,
                             quietMode: false,
                             pingRingActive: false)
                    .frame(width: 240, height: 240)
                    .scaleEffect(370.0 / 240.0)
                    .frame(width: 370, height: 370)
                    .rotationEffect(.degrees(-reader.heading))
                    .animation(.easeOut(duration: 0.18), value: reader.heading)
                    .overlay(
                        DirectionIndicator(
                            bearingDegrees: relativeBearing,
                            personName: displayName,
                            personEmoji: emoji,
                            ringRadius: 180,
                            distanceText: nil
                        )
                    )
            }
            .frame(width: 370, height: 370)

            // Hold progress + a tiny live degree readout (feel-test feedback).
            VStack(spacing: 10) {
                ProgressView(value: holdProgress)
                    .progressViewStyle(.linear)
                    .tint(Color(hex: "#c4a8d4"))
                    .frame(width: 180)
                    .opacity(holdProgress > 0 ? 1 : 0)

                Text(readout)
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundColor(DesignTokens.Color.textMuted)
            }

            Spacer()
            Spacer()
        }
    }

    private var readout: String {
        if !bearingResolved { return "finding the direction…" }
        if alignmentError <= alignThreshold { return "hold it there ✦" }
        return "\(Int(alignmentError.rounded()))° to go" + (usingRealBearing ? "" : "  ·  demo bearing")
    }

    // MARK: - Bearing resolution

    private func resolveTargetBearing() {
        guard !bearingResolved else { return }
        let p = people.selectedPerson
        let hasStored = (p?.latitude ?? 0) != 0 || (p?.longitude ?? 0) != 0
        if let p, hasStored, let here = reader.location {
            let target = CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude)
            targetBearing = BearingCalculator.bearing(from: here.coordinate, to: target)
            usingRealBearing = true
        } else {
            // No stored location → a stable random bearing that always requires a turn.
            // [20,340] already excludes 0/360 ± 10°.
            targetBearing = Double.random(in: 20...340)
            usingRealBearing = false
        }
        bearingResolved = true
    }

    // MARK: - Hold → arrival

    private func advanceHold() {
        guard bearingResolved, !arrived else { return }

        let aligned = alignmentError <= alignThreshold
        if aligned && !wasAligned {
            HapticEngine.lockOn()                       // a gentle tap as the aim locks
        }
        wasAligned = aligned

        if aligned {
            holdProgress += 0.05 / holdDuration
            if holdProgress >= 1.0 {
                holdProgress = 1.0
                HapticEngine.caughtConfirmation()
                withAnimation(.easeIn(duration: 0.35)) { arrived = true }
            }
        } else if holdProgress > 0 {
            withAnimation(.easeOut(duration: 0.3)) { holdProgress = 0 }
        }
    }
}
