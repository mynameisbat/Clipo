import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct GPUAcceleratedGlassView: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = GlassEffectView()
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.cornerRadius = cornerRadius
    }

    class GlassEffectView: NSView {
        private let ciContext = CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .useSoftwareRenderer: false
        ])

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            guard let context = NSGraphicsContext.current?.cgContext else { return }

            // Capture background
            guard let windowImage = captureBackground() else { return }

            // Apply glass effect using CoreImage filters
            let glassImage = applyGlassEffect(to: windowImage)

            // Draw result
            if let cgImage = glassImage {
                context.draw(cgImage, in: bounds)
            }
        }

        private func captureBackground() -> CIImage? {
            guard let window = self.window else { return nil }

            let windowFrame = window.frame
            let screenFrame = NSScreen.main?.frame ?? .zero

            // Create image from screen content behind window
            guard let screenImage = CGWindowListCreateImage(
                CGRect(x: windowFrame.origin.x, y: screenFrame.height - windowFrame.origin.y - windowFrame.height,
                       width: windowFrame.width, height: windowFrame.height),
                .optionOnScreenBelowWindow,
                CGWindowID(window.windowNumber),
                .bestResolution
            ) else {
                return nil
            }

            return CIImage(cgImage: screenImage)
        }

        private func applyGlassEffect(to image: CIImage) -> CGImage? {
            // Gaussian blur for glass effect
            let blurFilter = CIFilter.gaussianBlur()
            blurFilter.inputImage = image
            blurFilter.radius = 20.0

            guard var blurred = blurFilter.outputImage else { return nil }

            // Color controls for saturation boost
            let colorFilter = CIFilter.colorControls()
            colorFilter.inputImage = blurred
            colorFilter.saturation = 1.8
            colorFilter.brightness = 0.0
            colorFilter.contrast = 1.0

            guard var saturated = colorFilter.outputImage else { return nil }

            // Add gradient overlay for depth
            let gradientFilter = CIFilter.linearGradient()
            gradientFilter.point0 = CGPoint(x: 0, y: bounds.height)
            gradientFilter.point1 = CGPoint(x: 0, y: 0)
            gradientFilter.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
            gradientFilter.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0.1)

            guard let gradient = gradientFilter.outputImage else { return nil }

            // Composite gradient over saturated blur
            let compositeFilter = CIFilter.sourceOverCompositing()
            compositeFilter.inputImage = gradient
            compositeFilter.backgroundImage = saturated

            guard let final = compositeFilter.outputImage else { return nil }

            // Render to CGImage
            let rect = CGRect(origin: .zero, size: bounds.size)
            return ciContext.createCGImage(final, from: rect)
        }
    }
}

struct GPUAcceleratedGlassMaterial: View {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 18) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        GPUAcceleratedGlassView(cornerRadius: cornerRadius)
    }
}
