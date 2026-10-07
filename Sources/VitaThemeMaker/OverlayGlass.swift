import SwiftUI

// MARK: - Cristal oscuro para todo lo que flota sobre la imagen

struct OverlayGlass: ViewModifier {
    var radius: CGFloat = AppStyle.radius + 2

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .environment(\.colorScheme, .dark)
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Color.ink.opacity(0.30))
                }
                .environment(\.colorScheme, .dark)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }
}

extension View {
    func overlayGlass(radius: CGFloat = AppStyle.radius + 2) -> some View {
        modifier(OverlayGlass(radius: radius))
    }
}

// MARK: - Exportar: misma forma y altura que los botones de la barra

/// Funciona con cualquier acento: oscurece la parte baja con negro en vez de usar un segundo color.
struct ExportButtonStyle: ButtonStyle {
    let accent: Color
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let shade = LinearGradient(colors: [Color.clear, Color.black.opacity(0.20)],
                                   startPoint: .top, endPoint: .bottom)
        return configuration.label
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(AppStyle.shape.fill(accent).overlay(AppStyle.shape.fill(shade)))
            .overlay(AppStyle.shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .shadow(color: accent.opacity(0.35), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(enabled ? 1 : 0.45)
    }
}
