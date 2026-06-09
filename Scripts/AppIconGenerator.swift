// AppIconGenerator.swift
// Pointward › Scripts (NOT part of the app target — imports AppKit)
//
// THE POINTWARD APP ICON — a clean, symbolic compass needle on a deep
// purple-black ground. A single warm lavender needle points toward the upper
// right (northeast), its tip softly glowing, a small pivot at the centre.
// Minimal and emotional: "point toward the people you love."
//
// The view is fully parametric on `size`, so every required iOS size is
// rendered NATIVELY (crisp) rather than downscaled from one image.
//
// Run from the repo root (renders one size):
//   swift Scripts/AppIconGenerator.swift <pixelSize> <outputPath>
// Or render the whole set with Scripts/generate-app-icons.sh.

import SwiftUI
import AppKit

// MARK: - Palette  (matches the in-app Design System)

private let ground     = Color(red: 0x0d / 255.0, green: 0x0d / 255.0, blue: 0x14 / 255.0) // #0d0d14
private let groundLift = Color(red: 0x16 / 255.0, green: 0x12 / 255.0, blue: 0x22 / 255.0) // subtle vignette top
private let lavender   = Color(red: 0xc4 / 255.0, green: 0xa8 / 255.0, blue: 0xd4 / 255.0) // #c4a8d4
private let lavenderHi = Color(red: 0xe0 / 255.0, green: 0xcc / 255.0, blue: 0xee / 255.0) // #e0ccee
private let purpleDeep = Color(red: 0x5a / 255.0, green: 0x48 / 255.0, blue: 0x70 / 255.0) // tail half
private let purpleGlow = Color(red: 0x9b / 255.0, green: 0x7f / 255.0, blue: 0xc0 / 255.0) // #9b7fc0

// MARK: - Needle half (a slim kite — pivot at base, point at top)

private struct NeedleHalf: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))                       // pivot
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.26)) // left shoulder
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))                    // tip
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.26)) // right shoulder
            p.closeSubpath()
        }
    }
}

// MARK: - Icon

struct PointwardIcon: View {
    let size: CGFloat

    var body: some View {
        let s = size
        ZStack {
            // Deep purple-black ground (iOS masks the corners).
            Rectangle().fill(ground)

            // A faint top-down lift so the square never reads as flat black.
            LinearGradient(colors: [groundLift, ground],
                           startPoint: .top, endPoint: .center)

            // Ambient purple breath out of the centre — depth, not a ring.
            RadialGradient(colors: [purpleGlow.opacity(0.34), purpleGlow.opacity(0.10), .clear],
                           center: .center, startRadius: s * 0.03, endRadius: s * 0.56)

            // Soft bloom behind the needle TIP (upper right) — the warm light
            // someone is pointing toward.
            Circle()
                .fill(lavender.opacity(0.55))
                .frame(width: s * 0.34, height: s * 0.34)
                .blur(radius: s * 0.11)
                .offset(x: s * 0.20, y: -s * 0.20)

            // ── The needle — points NORTHEAST (rotated 45° clockwise) ──
            ZStack {
                // Pointing half — long, warm lavender, gently glowing.
                NeedleHalf()
                    .fill(LinearGradient(colors: [lavenderHi, lavender],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: s * 0.085, height: s * 0.345)
                    .offset(y: -s * 0.1725)
                    .shadow(color: purpleGlow.opacity(0.85), radius: s * 0.035)
                    .shadow(color: lavender.opacity(0.55), radius: s * 0.018)

                // Tail half — shorter, deep muted purple.
                NeedleHalf()
                    .fill(LinearGradient(colors: [purpleDeep, purpleDeep.opacity(0.85)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.072, height: s * 0.255)
                    .rotationEffect(.degrees(180))
                    .offset(y: s * 0.1275)
            }
            .rotationEffect(.degrees(45))

            // ── Pivot — a small jewel at the centre ──
            Circle()
                .fill(ground)
                .frame(width: s * 0.066, height: s * 0.066)
            Circle()
                .stroke(lavender.opacity(0.9), lineWidth: max(1, s * 0.007))
                .frame(width: s * 0.066, height: s * 0.066)
            Circle()
                .fill(lavenderHi)
                .frame(width: s * 0.024, height: s * 0.024)
                .shadow(color: lavenderHi.opacity(0.8), radius: s * 0.012)
        }
        .frame(width: s, height: s)
        .clipped()
    }
}

// MARK: - Render to PNG

let args = CommandLine.arguments
let pixelSize = args.count > 1 ? (Double(args[1]) ?? 1024) : 1024
let outPath   = args.count > 2
    ? args[2]
    : "HomeLink/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

// Scripts run on the main thread; ImageRenderer is MainActor-isolated.
try MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: PointwardIcon(size: CGFloat(pixelSize)))
    renderer.proposedSize = ProposedViewSize(width: CGFloat(pixelSize), height: CGFloat(pixelSize))
    renderer.scale = 1   // proposedSize is already in pixels → native resolution

    guard let cgImage = renderer.cgImage else {
        fputs("error: ImageRenderer produced no image\n", stderr)
        exit(1)
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = NSSize(width: pixelSize, height: pixelSize)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fputs("error: PNG encoding failed\n", stderr)
        exit(1)
    }
    try png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath) (\(cgImage.width)x\(cgImage.height))")
}
