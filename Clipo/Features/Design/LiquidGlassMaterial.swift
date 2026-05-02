import SwiftUI

struct LiquidGlassMaterial: View {
    let cornerRadius: CGFloat

    @State private var blurRadius: CGFloat = 20
    @State private var saturation: Double = 1.8

    init(cornerRadius: CGFloat = 18) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ZStack {
            // Background blur with dynamic refraction
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .blur(radius: blurRadius)
                .saturation(saturation)

            // Specular highlights on edges
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            // Deep gradient overlay
            LinearGradient(
                colors: [
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
