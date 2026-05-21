import SwiftUI

enum CrestColors {
    static let meetingIcon: Color = .accentColor
    static let linkColor: Color = .accentColor
}

extension View {
    /// Subtle hover affordance for interactive elements inside the fullscreen
    /// overlays — slight brightness + scale on hover plus a pointing-hand
    /// cursor (`.pointerStyle(.link)`). Pass `enabled: false` for controls
    /// that are visually disabled so the effect and cursor stay neutral.
    func overlayButtonHover(enabled: Bool = true) -> some View {
        modifier(OverlayButtonHover(enabled: enabled))
    }
}

private struct OverlayButtonHover: ViewModifier {
    let enabled: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .brightness(isHovered && enabled ? 0.10 : 0)
            .scaleEffect(isHovered && enabled ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
            .pointerStyle(enabled ? .link : .default)
    }
}
