import SwiftUI

// MARK: - Panel plano: papel blanco, borde fino y sombra dura (sin blur, más barata)

extension View {
    func flatPanel(radius: CGFloat = 3, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(shape.fill(Color.white.opacity(0.92)))
            .overlay(alignment: .top) {
                if let tint { tint.frame(height: 3) }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.ink.opacity(0.14), lineWidth: 1))
            .background(shape.fill(Color.ink.opacity(0.10)).offset(x: 4, y: 4))
    }
}

/// Tarjeta con título en monoespaciada, un símbolo de PlayStation y una franja de su color.
struct PanelCard<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    let content: Content

    init(_ title: String, symbol: String, tint: Color,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                Text(title.uppercased())
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.ink.opacity(0.55))
            }
            content
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .padding(.top, 3)
        .flatPanel(tint: tint)
    }
}

// MARK: - Botón plano para dentro de las tarjetas

/// Contorno fino por defecto; `filled: true` para la acción principal (usa el acento).
struct PanelButtonStyle: ButtonStyle {
    var tint: Color = Color.ink
    var filled: Bool = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        let shade = LinearGradient(colors: [Color.clear, Color.black.opacity(0.20)],
                                   startPoint: .top, endPoint: .bottom)
        return configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(filled ? Color.white : Color.ink)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background {
                if filled {
                    shape.fill(tint).overlay(shape.fill(shade))
                } else {
                    shape.fill(tint.opacity(configuration.isPressed ? 0.12 : 0))
                }
            }
            .overlay(shape.strokeBorder(filled ? Color.clear : Color.ink.opacity(0.28), lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}
