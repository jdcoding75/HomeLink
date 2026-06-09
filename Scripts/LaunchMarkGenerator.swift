// LaunchMarkGenerator.swift
// Pointward › Scripts (NOT part of the app target — imports AppKit)
//
// THE LAUNCH LOCKUP — the Pointward needle above the wordmark, in elegant
// serif lavender, on a transparent ground (the launch storyboard supplies the
// deep-purple #0d0d14 background). Rendered to a single high-res PNG centred
// on screen at launch.
//
// Run from the repo root:
//   swift Scripts/LaunchMarkGenerator.swift <width> <height> <outputPath>

import SwiftUI
import AppKit

private let lavender   = Color(red: 0xc4 / 255.0, green: 0xa8 / 255.0, blue: 0xd4 / 255.0) // #c4a8d4
private let lavenderHi = Color(red: 0xe0 / 255.0, green: 0xcc / 255.0, blue: 0xee / 255.0) // #e0ccee
private let purpleDeep = Color(red: 0x5a / 255.0, green: 0x48 / 255.0, blue: 0x70 / 255.0)
private let purpleGlow = Color(red: 0x9b / 255.0, green: 0x7f / 255.0, blue: 0xc0 / 255.0) // #9b7fc0

private struct NeedleHalf: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.26))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.26))
            p.closeSubpath()
        }
    }
}

struct LaunchMark: View {
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        let unit = min(w, h)
        ZStack {
            Color.clear

            // ── The needle, NE, centred a touch above the middle ──
            ZStack {
                // Tip bloom
                Circle()
                    .fill(lavender.opacity(0.5))
                    .frame(width: unit * 0.34, height: unit * 0.34)
                    .blur(radius: unit * 0.10)
                    .offset(x: unit * 0.16, y: -unit * 0.16)

                ZStack {
                    NeedleHalf()
                        .fill(LinearGradient(colors: [lavenderHi, lavender],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: unit * 0.075, height: unit * 0.30)
                        .offset(y: -unit * 0.15)
                        .shadow(color: purpleGlow.opacity(0.85), radius: unit * 0.03)
                    NeedleHalf()
                        .fill(purpleDeep)
                        .frame(width: unit * 0.064, height: unit * 0.225)
                        .rotationEffect(.degrees(180))
                        .offset(y: unit * 0.1125)
                }
                .rotationEffect(.degrees(45))

                Circle().fill(Color(red: 0x0d/255, green: 0x0d/255, blue: 0x14/255))
                    .frame(width: unit * 0.058, height: unit * 0.058)
                Circle().stroke(lavender.opacity(0.9), lineWidth: max(1, unit * 0.006))
                    .frame(width: unit * 0.058, height: unit * 0.058)
                Circle().fill(lavenderHi).frame(width: unit * 0.021, height: unit * 0.021)
            }
            .offset(y: -h * 0.12)

            // ── The wordmark, elegant serif ──
            Text("Pointward")
                .font(.system(size: unit * 0.115, weight: .medium, design: .serif))
                .foregroundColor(lavenderHi)
                .shadow(color: purpleGlow.opacity(0.5), radius: unit * 0.02)
                .offset(y: h * 0.26)
        }
        .frame(width: w, height: h)
    }
}

let args = CommandLine.arguments
let w = args.count > 1 ? (Double(args[1]) ?? 720) : 720
let h = args.count > 2 ? (Double(args[2]) ?? 960) : 960
let outPath = args.count > 3 ? args[3] : "HomeLink/Assets.xcassets/LaunchMark.imageset/LaunchMark.png"

try MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: LaunchMark(w: CGFloat(w), h: CGFloat(h)))
    renderer.proposedSize = ProposedViewSize(width: CGFloat(w), height: CGFloat(h))
    renderer.scale = 1
    guard let cgImage = renderer.cgImage else {
        fputs("error: ImageRenderer produced no image\n", stderr); exit(1)
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = NSSize(width: w, height: h)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fputs("error: PNG encoding failed\n", stderr); exit(1)
    }
    try png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath) (\(cgImage.width)x\(cgImage.height))")
}
