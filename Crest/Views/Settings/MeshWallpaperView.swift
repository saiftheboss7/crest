import SwiftUI

struct MeshWallpaperView: View {
    var body: some View {
        ZStack {
            // Base Linear Gradient
            LinearGradient(
                colors: [
                    Color(red: 0.996, green: 0.882, blue: 0.933), // #ffe1ee
                    Color(red: 0.835, green: 0.890, blue: 1.0),   // #d5e3ff
                    Color(red: 1.0, green: 0.914, blue: 0.788)    // #ffe9c9
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Top-Left Radial Gradient
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.820, blue: 0.871),   // #ffd1de
                    .clear
                ],
                center: .init(x: 0.18, y: 0.18),
                startRadius: 0,
                endRadius: 400
            )
            .blendMode(.multiply)

            // Top-Right Radial Gradient
            RadialGradient(
                colors: [
                    Color(red: 0.784, green: 0.863, blue: 1.0),   // #c8dcff
                    .clear
                ],
                center: .init(x: 0.82, y: 0.28),
                startRadius: 0,
                endRadius: 400
            )

            // Bottom-Center Radial Gradient
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.898, blue: 0.722),   // #ffe5b8
                    .clear
                ],
                center: .init(x: 0.5, y: 0.9),
                startRadius: 0,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
    }
}
