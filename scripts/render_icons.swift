import AppKit
import SwiftUI

struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 220, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.07, blue: 0.12),
                        Color(red: 0.06, green: 0.09, blue: 0.16)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))

            ZStack {
                sheet(fill: Color(red: 0.12, green: 0.16, blue: 0.23), strokeOpacity: 0.06, rotation: -8, showContent: false)
                sheet(fill: Color(red: 0.20, green: 0.25, blue: 0.34), strokeOpacity: 0.10, rotation: 0, showContent: false)
                sheet(fill: Color(red: 0.28, green: 0.33, blue: 0.42), strokeOpacity: 0.16, rotation: 4, showContent: true)
            }

            RoundedRectangle(cornerRadius: 220, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.14), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        }
        .frame(width: 1024, height: 1024)
    }

    @ViewBuilder
    private func sheet(fill: Color, strokeOpacity: Double, rotation: Double, showContent: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(strokeOpacity), lineWidth: 2)
                )

            if showContent {
                VStack(alignment: .leading, spacing: 20) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.06, green: 0.09, blue: 0.16))
                        .frame(width: 200, height: 24)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.7))
                        .frame(width: 320, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.7))
                        .frame(width: 280, height: 16)
                    Spacer()
                }
                .frame(width: 480, height: 640, alignment: .topLeading)
                .padding(.top, 88)
                .padding(.leading, 60)

                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.18, green: 0.83, blue: 0.75), Color(red: 0.08, green: 0.72, blue: 0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                    .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 2))
                    .offset(x: 188, y: 268)
            }
        }
        .frame(width: 480, height: 640)
        .rotationEffect(.degrees(rotation))
    }
}

struct MenuBarIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .stroke(Color.black, lineWidth: 1.2)
                .frame(width: 10, height: 13)
                .rotationEffect(.degrees(-10))

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .stroke(Color.black, lineWidth: 1.2)
                .frame(width: 10, height: 13)

            ZStack {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .stroke(Color.black, lineWidth: 1.2)
                    .frame(width: 10, height: 13)
                Circle()
                    .fill(Color.black)
                    .frame(width: 3, height: 3)
                    .offset(x: 3.5, y: 4.5)
            }
            .rotationEffect(.degrees(6))
        }
        .frame(width: 18, height: 18)
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

        for (name, size) in [("MenuBarIcon-18", 18), ("MenuBarIcon-36", 36)] {
            let image = renderToBitmap(view: MenuBarIconView(), size: NSSize(width: size, height: size))
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
