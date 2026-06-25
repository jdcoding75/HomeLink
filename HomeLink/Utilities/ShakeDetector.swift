// ShakeDetector.swift
// Pointward › Utilities
//
// THE SHAKE — the wand instrument's charge. Reads the accelerometer and
// counts deliberate shakes: each sharp spike past the threshold (and back
// down) is one shake, five fill the crystal. A debounce keeps a single
// flick of the wrist from registering as many.
//
// Privacy: motion stays on the device. When CoreMotion is unavailable
// (Simulator, or no hardware) the wand degrades to hold-to-charge.

import Foundation
import Combine
#if canImport(CoreMotion)
import CoreMotion
#endif

@MainActor
final class ShakeDetector: ObservableObject {

    /// 0…1 magic charge — five shakes to full.
    @Published private(set) var charge: Double = 0
    /// Whole shakes counted so far (0…5), for the visual charge bands.
    @Published private(set) var shakes: Int = 0
    /// True once the accelerometer is delivering — false on Simulator/no HW.
    @Published private(set) var motionAvailable = false

    /// Fires once per counted shake (haptic + shimmer + particle burst).
    var onShake: ((_ shakes: Int) -> Void)?
    /// Fires the instant the charge first reaches full.
    var onFull: (() -> Void)?

    // [2/6] Magical and responsive — a gentle shake counts, and only THREE
    // fill the crystal (≈34 % each). Was 2.5 g / 5 shakes, which felt like a
    // workout.
    static let shakesToFull = 3
    // [wand-mechanic] Metric is now |magnitude − 1.0| (gravity-removed, see start()) → ~0 at rest
    // AND at each stroke turnaround, so re-arm is reliable during CONTINUOUS shaking (raw-with-gravity
    // never dipped below 1.2 g between strokes → shakes 2-3 dropped). Thresholds rescaled to that
    // gravity-removed baseline. Invariant: shakeThreshold > resetThreshold. Device-tunable STARTING values.
    // PRIOR (raw magnitude incl. gravity, [wand-fix]): shakeThreshold 1.5 / resetThreshold 1.2 / minInterval 0.12
    private let shakeThreshold: Double = 0.45   // g of net motion above gravity — a deliberate shake
    private let resetThreshold: Double = 0.15   // must settle below before the next shake counts (0.30 g gap)
    private let minInterval: Double    = 0.08   // seconds between counted shakes (was 0.12 — snappier)

    #if canImport(CoreMotion)
    private let motion = CMMotionManager()
    #endif
    private var armed = true                 // ready to count the next spike
    private var lastShakeAt: TimeInterval = 0
    private var didFire = false

    func start() {
        #if canImport(CoreMotion)
        guard motion.isAccelerometerAvailable else {
            motionAvailable = false
            return
        }
        guard !motion.isAccelerometerActive else { return }
        motion.accelerometerUpdateInterval = 1.0 / 50.0   // 50 Hz
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            // [wand-mechanic] gravity-removed shake intensity: deviation of total accel from the
            // 1 g baseline. ~0 at rest and at each stroke turnaround → reliable re-arm during
            // continuous shaking. PRIOR: let magnitude = (a.x*a.x + a.y*a.y + a.z*a.z).squareRoot()  // incl. gravity
            let raw = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()   // includes gravity (~1 g at rest)
            let intensity = abs(raw - 1.0)                              // gravity-removed
            self.consume(magnitude: intensity, at: data?.timestamp ?? 0)
        }
        motionAvailable = true
        #else
        motionAvailable = false
        #endif
    }

    func stop() {
        #if canImport(CoreMotion)
        if motion.isAccelerometerActive { motion.stopAccelerometerUpdates() }
        #endif
        reset()
    }

    /// Clear the charge (after a send, or when the thought is unloaded).
    func reset() {
        charge = 0
        shakes = 0
        armed = true
        didFire = false
    }

    // ── Internals ─────────────────────────────────────────────────────────

    private func consume(magnitude: Double, at timestamp: TimeInterval) {
        // Re-arm once the motion settles back down between shakes.
        if magnitude < resetThreshold { armed = true }

        guard armed,
              magnitude > shakeThreshold,
              timestamp - lastShakeAt > minInterval else { return }

        armed = false
        lastShakeAt = timestamp
        registerShake()
    }

    private func registerShake() {
        guard shakes < Self.shakesToFull else { return }
        shakes += 1
        charge = min(1, Double(shakes) / Double(Self.shakesToFull))
        onShake?(shakes)
        if charge >= 1 && !didFire {
            didFire = true
            onFull?()
        }
    }

    // ── Fallback (no motion hardware): hold-to-charge ─────────────────────

    /// Drive the charge from a timer when CoreMotion isn't delivering — one
    /// "shake" worth of charge per call, so the wand still works in the
    /// Simulator and on the rare device without an accelerometer.
    func holdCharge(_ amount: Double) {
        guard !motionAvailable, charge < 1 else { return }
        charge = min(1, charge + amount)
        let crossed = Int(charge * Double(Self.shakesToFull))
        if crossed > shakes {
            shakes = crossed
            onShake?(shakes)
        }
        if charge >= 1 && !didFire {
            didFire = true
            onFull?()
        }
    }
}
