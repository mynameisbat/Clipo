import SwiftUI

struct LiquidGlassMaterial: View {
    let cornerRadius: CGFloat

    @State private var blurRadius: CGFloat = 20
    @State private var saturation: Double = 1.2

    init(cornerRadius: CGFloat = 18) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .blur(radius: blurRadius)
                .saturation(saturation)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}
