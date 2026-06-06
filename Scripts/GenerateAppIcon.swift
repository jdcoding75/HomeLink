// GenerateAppIcon.swift
// Pointward › Scripts (not part of the app target)
//
// Renders the Pointward app icon as a SwiftUI view → 1024×1024 PNG.
// Run from the repo root:
//   swift Scripts/GenerateAppIcon.swift
// Then downscale to the remaining sizes with sips (see generate-icons.sh).

import SwiftUI
import AppKit

// MARK: - Palette

let ground      = Color(red: 0x0d / 255.0, green: 0x0d / 255.0, blue: 0x14 / 255.0) // #0d0d14
let lavender    = Color(red: 0xc4 / 255.0, green: 0xa8 / 255.0, blue: 0xd4 / 255.0) // #c4a8d4
let lavenderHi  = Color(red: 0xe0 / 255.0, green: 0xcc / 255.0, blue: 0xee / 255.0)
let purpleDeep  = Color(red: 0x5a / 255.0, green: 0x48 / 255.0, blue: 0x70 / 255.0) // #5a4870
let purpleGlow  = Color(red: 0x9b / 255.0, green: 0x7f / 255.0, blue: 0xc0 / 255.0) // #9b7fc0
let brassBright = Color(red: 0xe3 / 255.0, green: 0xc8 / 255.0, blue: 0x87 / 255.0) // #e3c887
let brass       = Color(red: 0xc9 / 255.0, green: 0xa8 / 255.0, blue: 0x6a / 255.0) // #c9a86a
let brassDim    = Color(red: 0x8a / 255.0, green: 0x70 / 255.0, blue: 0x3f / 255.0) // #8a703f

// MARK: - Needle (kite shape, two-tone like the in-app needle)

struct NeedleHalf: Shape {
    // Tip up, shoulder ~30% from pivot
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))             // pivot
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.30))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))          // tip
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.30))
            p.closeSubpath()
        }
    }
}

// MARK: - Icon

struct AppIconView: View {
    let size: CGFloat = 1024

    var body: some View {
        ZStack {
            // Deep purple-black ground
            ground

            // Soft purple glow breathing out from the center
            RadialGradient(
                colors: [purpleGlow.opacity(0.32), purpleGlow.opacity(0.10), .clear],
                center: .center, startRadius: 40, endRadius: 470
            )

            // Vintage brass double ring border
            Circle()
                .stroke(brassBright.opacity(0.95), lineWidth: 11)
                .frame(width: 880, height: 880)
            Circle()
                .stroke(brass.opacity(0.75), lineWidth: 4)
                .frame(width: 838, height: 838)
            Circle()
                .stroke(brassDim.opacity(0.8), lineWidth: 6)
                .frame(width: 800, height: 800)

            // Fine degree tick marks
            Canvas { ctx, sz in
                let cx = sz.width / 2, cy = sz.height / 2
                let tickOuter: CGFloat = 395
                for deg in stride(from: 0, to: 360, by: 2) {
                    let rad  = Double(deg) * .pi / 180
                    let is90 = deg % 90 == 0
                    let is10 = deg % 10 == 0
                    let len: CGFloat = is90 ? 46 : is10 ? 34 : 16
                    let sw:  CGFloat = is90 ? 6 : is10 ? 3.5 : 2
                    let col  = is90 ? brassBright : is10 ? brass.opacity(0.9) : brassDim.opacity(0.85)
                    var path = Path()
                    path.move(to: CGPoint(x: cx + CGFloat(sin(rad)) * tickOuter,
                                          y: cy - CGFloat(cos(rad)) * tickOuter))
                    path.addLine(to: CGPoint(x: cx + CGFloat(sin(rad)) * (tickOuter - len),
                                             y: cy - CGFloat(cos(rad)) * (tickOuter - len)))
                    ctx.stroke(path, with: .color(col), lineWidth: sw)
                }
            }

            // Cardinal letters in lavender
            ForEach(0..<4, id: \.self) { i in
                let letters = ["N", "E", "S", "W"]
                let rad = Double(i) * 90 * .pi / 180
                Text(letters[i])
                    .font(.system(size: 92, weight: i == 0 ? .bold : .semibold, design: .serif))
                    .foregroundColor(i == 0 ? lavenderHi : lavender)
                    .offset(x: CGFloat(sin(rad)) * 300, y: -CGFloat(cos(rad)) * 300)
            }

            // Glow disc right behind the needle pivot
            Circle()
                .fill(purpleGlow.opacity(0.35))
                .frame(width: 230, height: 230)
                .blur(radius: 60)

            // Needle — pointing NNW (-22.5°), south tip in darker purple
            ZStack {
                // North half (long, lavender, subtle inner highlight)
                NeedleHalf()
                    .fill(LinearGradient(colors: [lavenderHi, lavender],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 92, height: 350)
                    .offset(y: -175)
                    .shadow(color: purpleGlow.opacity(0.8), radius: 28)
                // South half (shorter, deep purple)
                NeedleHalf()
                    .fill(purpleDeep)
                    .frame(width: 78, height: 230)
                    .rotationEffect(.degrees(180))
                    .offset(y: 115)
            }
            .rotationEffect(.degrees(-22.5))

            // Pivot
            Circle()
                .fill(ground)
                .frame(width: 58, height: 58)
            Circle()
                .stroke(brassBright, lineWidth: 6)
                .frame(width: 58, height: 58)
            Circle()
                .fill(lavenderHi)
                .frame(width: 22, height: 22)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Render to PNG

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Pointward/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

// Scripts run on the main thread; ImageRenderer is MainActor-isolated.
try MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: AppIconView())
    renderer.proposedSize = ProposedViewSize(width: 1024, height: 1024)
    renderer.scale = 1

    guard let cgImage = renderer.cgImage else {
        fputs("error: ImageRenderer produced no image\n", stderr)
        exit(1)
    }

    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fputs("error: PNG encoding failed\n", stderr)
        exit(1)
    }
    try png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath) (\(cgImage.width)x\(cgImage.height))")
}
