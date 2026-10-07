import SwiftUI
import VitaThemeKit

/// Colores aproximados de cada wave (esquina oscura -> esquina clara), tomados de
/// assets/waves.png de ThemeBUILDER. El índice es el valor que va en <m_waveType>.
enum WavePalette {
    static let colors: [(dark: UInt32, light: UInt32)] = [
        (0x030bd9, 0x2e97ec),
        (0xd5def6, 0xdce0f7),
        (0xff4242, 0xf7aa5e),
        (0xcd0e1f, 0xe61034),
        (0x05719d, 0x01b2c9),
        (0x350015, 0x810837),
        (0x315af6, 0xb4c8f2),
        (0x84b5ef, 0xbbdcf7),
        (0x00315c, 0x063c6f),
        (0xf7279a, 0xf5abd4),
        (0xf2ce02, 0xf2e823),
        (0x000000, 0x000000),
        (0x3110a3, 0x6e5ecd),
        (0x031356, 0x0919d2),
        (0xfdea54, 0xf9603e),
        (0xec7b6b, 0xf7a59c),
        (0x0acbb7, 0x94ddda),
        (0x00afe2, 0x00c9e2),
        (0x190031, 0x6503a5),
        (0xc0adad, 0xe7c9ca),
        (0x544a46, 0x6f5e5c),
        (0xac08cf, 0xe320d6),
        (0xe50e66, 0xf751a7),
        (0xe7e6e8, 0xd9d7d6),
        (0xc492db, 0xe0a7e6),
        (0x299c00, 0x94dc13),
        (0x00aed6, 0x1dd3e5),
        (0xaeb719, 0xeee6c3),
        (0x566b4e, 0xbdc4b3),
        (0x6e9ca4, 0xb5d6e9),
        (0x5d697a, 0xc3cdcb)
    ]

    static func gradient(_ value: Int) -> LinearGradient {
        let c = colors[min(max(value, 0), colors.count - 1)]
        return LinearGradient(colors: [rgb(c.dark), rgb(c.light)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// true si el color es claro (el número se dibuja en oscuro para que se lea).
    static func isLight(_ value: Int) -> Bool {
        let c = colors[min(max(value, 0), colors.count - 1)]
        let avg: Double = (luminance(c.dark) + luminance(c.light)) / 2
        return avg > 0.66
    }

    private static func luminance(_ v: UInt32) -> Double {
        let r: Double = Double((v >> 16) & 0xff) / 255
        let g: Double = Double((v >> 8) & 0xff) / 255
        let b: Double = Double(v & 0xff) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    private static func rgb(_ v: UInt32) -> Color {
        Color(.sRGB,
              red: Double((v >> 16) & 0xff) / 255,
              green: Double((v >> 8) & 0xff) / 255,
              blue: Double(v & 0xff) / 255)
    }
}

/// Selector de las 31 waves. Cada casilla muestra su número (el valor del XML).
struct WavePicker: View {
    @Binding var selection: Int

    private let columns = [GridItem(.adaptive(minimum: 40, maximum: 52), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            current
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(ThemeWaves.range, id: \.self) { v in
                    WaveSwatch(value: v, selected: selection == v) {
                        selection = v
                    }
                }
            }
        }
    }

    // Wave seleccionada, en grande

    private var currentShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    private var current: some View {
        HStack(spacing: 12) {
            currentShape
                .fill(WavePalette.gradient(selection))
                .frame(width: 72, height: 34)
                .overlay(currentShape.strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                .shadow(color: Color.ink.opacity(0.12), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text("Wave \(selection)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Text("<m_waveType> value")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.ink.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Casilla

private struct WaveSwatch: View {
    let value: Int
    let selected: Bool
    let action: () -> Void

    @State private var hovering = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }
    private var ringShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
    }
    private var labelColor: Color {
        WavePalette.isLight(value) ? Color.ink.opacity(0.75) : Color.white
    }
    private var raised: Bool { hovering || selected }

    var body: some View {
        Button(action: action) { swatch }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
            .animation(.easeOut(duration: 0.15), value: selected)
    }

    private var swatch: some View {
        shape
            .fill(WavePalette.gradient(value))
            .frame(height: 36)
            .overlay(label)
            .overlay(shape.strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
            .padding(3)
            .overlay(ring)
            .scaleEffect(raised ? 1.06 : 1)
            .shadow(color: Color.ink.opacity(hovering ? 0.18 : 0.08),
                    radius: hovering ? 8 : 4, y: 3)
    }

    private var label: some View {
        Text("\(value)")
            .font(.system(size: 11.5, weight: .bold, design: .rounded))
            .foregroundStyle(labelColor)
    }

    @ViewBuilder
    private var ring: some View {
        if selected {
            ringShape.strokeBorder(Color.blueMid, lineWidth: 2.5)
        }
    }
}
