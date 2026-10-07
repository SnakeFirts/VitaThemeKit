import SwiftUI

/// Estilo compartido de la app: esquinas sobrias, titulares con serif y botones planos.
enum AppStyle {
    /// Radio de las esquinas: menor = más sobrio.
    static let radius: CGFloat = 8

    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    /// Titulares con la serif del sistema (New York).
    /// Para una fuente propia: Font.custom("Nombre", size: size).
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func label() -> Font { .system(size: 10.5, weight: .semibold) }

    static func body(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

/// Botón plano, sin cristal ni sombras. `prominent: false` = solo contorno.
struct FlatButtonStyle: ButtonStyle {
    var prominent: Bool = true
    var tint: Color = Color.blueDeep
    /// Oscurece el color para que el texto contraste (útil con verdes y colores claros).
    var darken: Double = 0
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let textColor: Color = prominent ? Color.white : tint
        let fill: Color = prominent ? tint : Color.clear
        let lineAlpha: Double = prominent ? 0 : 0.5
        return configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(textColor)
            .brightness(prominent ? 0 : -darken)   // solo oscurece el texto del botón de contorno
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(AppStyle.shape.fill(fill).brightness(-darken))
            .overlay(AppStyle.shape.strokeBorder(tint.opacity(lineAlpha), lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}
