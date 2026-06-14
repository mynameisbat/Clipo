import AppKit
import SwiftUI

struct PaperclipShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        let x0 = w * 0.24
        let x1 = w * 0.40
        let x2 = w * 0.56
        let x3 = w * 0.72
        
        let yTopOuter = h * 0.20
        let yTopInner = h * 0.35
        let yBottomInner = h * 0.65
        let yBottomOuter = h * 0.80
        
        // Start at inner tip
        path.move(to: CGPoint(x: x2, y: h * 0.48))
        
        // Inner line going down
        path.addLine(to: CGPoint(x: x2, y: yBottomInner))
        
        // Inner bottom bend
        path.addArc(
            center: CGPoint(x: (x1 + x2)/2, y: yBottomInner),
            radius: (x2 - x1)/2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Inner left line going up
        path.addLine(to: CGPoint(x: x1, y: yTopInner))
        
        // Top outer bend
        path.addArc(
            center: CGPoint(x: (x1 + x3)/2, y: yTopInner),
            radius: (x3 - x1)/2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // Outer right line going down
        path.addLine(to: CGPoint(x: x3, y: yBottomOuter))
        
        // Bottom outer bend
        path.addArc(
            center: CGPoint(x: (x0 + x3)/2, y: yBottomOuter),
            radius: (x3 - x0)/2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Outer left line going up
        path.addLine(to: CGPoint(x: x0, y: yTopOuter))
        
        return path
    }
}

struct AppIconView: View {
    var body: some View {
        ZStack {
            // Transparent outer container (1024x1024)
            Color.clear

            // Squircle background with shadows
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.075, green: 0.078, blue: 0.11), // surfaceElevated
                        Color(red: 0.043, green: 0.047, blue: 0.063)  // surface
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 824, height: 824)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 15)
                .shadow(color: Color.black.opacity(0.4), radius: 32, x: 0, y: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 824, height: 824)
                )

            // Radial Glow Behind Paperclip for Glass/Neon effect
            RadialGradient(
                colors: [
                    Color(red: 0.00, green: 0.86, blue: 0.51).opacity(0.18),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 320
            )
            .frame(width: 640, height: 640)

            // 3D Glass/Metallic Paperclip Element
            ZStack {
                // 1. Drop Shadow under the paperclip itself (for 3D floating effect)
                PaperclipShape()
                    .stroke(Color.black.opacity(0.6), style: StrokeStyle(lineWidth: 42, lineCap: .round, lineJoin: .round))
                    .frame(width: 320, height: 440)
                    .offset(x: 10, y: 24)
                    .blur(radius: 16)

                // 2. Base Dark Reflection Border (adds depth)
                PaperclipShape()
                    .stroke(
                        Color(red: 0.02, green: 0.16, blue: 0.12),
                        style: StrokeStyle(lineWidth: 45, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 320, height: 440)

                // 3. Main Emerald Mint Body
                PaperclipShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.95, blue: 0.58), // Neon Mint
                                Color(red: 0.00, green: 0.86, blue: 0.51)  // Emerald Mint
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 40, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 320, height: 440)

                // 4. Inner Glass Glow (Semi-transparent white highlight at the top-left edges)
                PaperclipShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 308, height: 428)
                    .offset(x: -4, y: -4)
                    .blendMode(.screen)
            }
            .rotationEffect(.degrees(-15))
            .offset(x: 10, y: -10)
        }
        .frame(width: 1024, height: 1024)
    }
}

struct MenuBarPaperclipShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Custom paperclip dimensions optimized for small sizes (wider loop spacings to prevent blur/merging)
        let x0 = w * 0.15
        let x1 = w * 0.38
        let x2 = w * 0.62
        let x3 = w * 0.85
        
        let yTopInner = h * 0.32
        let yBottomInner = h * 0.68
        let yBottomOuter = h * 0.72
        
        // Start at inner tip
        path.move(to: CGPoint(x: x2, y: h * 0.45))
        
        // Inner line going down
        path.addLine(to: CGPoint(x: x2, y: yBottomInner))
        
        // Inner bottom bend
        path.addArc(
            center: CGPoint(x: (x1 + x2)/2, y: yBottomInner),
            radius: (x2 - x1)/2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Inner left line going up
        path.addLine(to: CGPoint(x: x1, y: yTopInner))
        
        // Top outer bend
        path.addArc(
            center: CGPoint(x: (x1 + x3)/2, y: yTopInner),
            radius: (x3 - x1)/2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // Outer right line going down
        path.addLine(to: CGPoint(x: x3, y: yBottomOuter))
        
        // Bottom outer bend
        path.addArc(
            center: CGPoint(x: (x0 + x3)/2, y: yBottomOuter),
            radius: (x3 - x0)/2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Outer left line going up
        path.addLine(to: CGPoint(x: x0, y: h * 0.22))
        
        return path
    }
}

struct MenuBarIconView: View {
    var size: CGFloat = 22
    
    var body: some View {
        let scale = size / 22.0
        ZStack {
            Color.clear
            
            MenuBarPaperclipShape()
                .stroke(
                    Color.black,
                    style: StrokeStyle(
                        lineWidth: 2.2 * scale,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: 12 * scale, height: 16 * scale)
                .offset(y: 0.5 * scale)
        }
        .frame(width: size, height: size)
    }
}

@main
struct IconRenderer {
    @MainActor
    static func main() throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appIconSet = repoRoot.appendingPathComponent("Clipo/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
        let menuBarSet = repoRoot.appendingPathComponent("Clipo/Resources/Assets.xcassets/MenuBarIcon.imageset", isDirectory: true)

        try FileManager.default.createDirectory(at: appIconSet, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: menuBarSet, withIntermediateDirectories: true)

        let master = renderToBitmap(view: AppIconView(), size: NSSize(width: 1024, height: 1024))

        let appIconSizes: [(String, Int)] = [
            ("AppIcon-1024", 1024),
            ("AppIcon-512", 512),
            ("AppIcon-256", 256),
            ("AppIcon-128", 128),
            ("AppIcon-64", 64),
            ("AppIcon-32", 32),
            ("AppIcon-16", 16)
        ]

        for (name, size) in appIconSizes {
            let target = NSSize(width: size, height: size)
            let image = size == 1024 ? master : downscale(image: master, to: target)
            let data = try pngData(from: image)
            try data.write(to: appIconSet.appendingPathComponent("\(name).png"))
            print("Wrote \(name).png (\(size)x\(size))")
        }

        for (name, size) in [("MenuBarIcon-22", 22), ("MenuBarIcon-44", 44)] {
            let image = renderToBitmap(view: MenuBarIconView(size: CGFloat(size)), size: NSSize(width: size, height: size))
            let data = try pngData(from: image)
            try data.write(to: menuBarSet.appendingPathComponent("\(name).png"))
            print("Wrote \(name).png (\(size)x\(size))")
        }

        print("Done.")
    }

    @MainActor
    private static func renderToBitmap<V: View>(view: V, size: NSSize) -> NSImage {
        let renderer = ImageRenderer(content: view.colorScheme(.dark).frame(width: size.width, height: size.height))
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)

        guard let cgImage = renderer.cgImage else {
            fatalError("Failed to render CGImage for size \(size)")
        }
        return NSImage(cgImage: cgImage, size: size)
    }

    private static func downscale(image: NSImage, to size: NSSize) -> NSImage {
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        let width = Int(size.width)
        let height = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let scaled = context.makeImage() else {
            return image
        }

        return NSImage(cgImage: scaled, size: size)
    }

    private static func pngData(from image: NSImage) throws -> Data {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "IconRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
        }
        return data
    }
}
