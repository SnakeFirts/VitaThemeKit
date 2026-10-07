import SwiftUI

// MARK: - Paleta

extension Color {
    static let ink      = Color(red: 0.09, green: 0.10, blue: 0.16)

    // Familia azul
    static let blueDeep = Color(red: 0.20, green: 0.38, blue: 0.95)
    static let blueMid  = Color(red: 0.30, green: 0.52, blue: 1.00)
    static let blueSky  = Color(red: 0.42, green: 0.74, blue: 1.00)
    static let blueIce  = Color(red: 0.88, green: 0.94, blue: 1.00)

    // Los 4 de PlayStation, solo para acentos pequeños
    static let psGreen  = Color(red: 0.12, green: 0.78, blue: 0.62)
    static let psRed    = Color(red: 1.00, green: 0.36, blue: 0.42)
    static let psBlue   = Color(red: 0.30, green: 0.52, blue: 1.00)
    static let psPink   = Color(red: 1.00, green: 0.46, blue: 0.78)

    static let accentA  = blueMid
}

// MARK: - Glass

extension View {
    func glassCard(radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let fill = LinearGradient(
            colors: [Color.white.opacity(0.80), Color.white.opacity(0.48)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let border = LinearGradient(
            colors: [Color.white, Color.white.opacity(0.25)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return self
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border, lineWidth: 1.2))
            .shadow(color: Color.accentA.opacity(0.10), radius: 40, y: 22)
            .shadow(color: Color.ink.opacity(0.05), radius: 6, y: 2)
    }
}

// MARK: - Fondo con olas

struct WaveBackground: View {
    var tint: Color? = nil
    var colors: [Color]? = nil
    var intensity: Double = 1

    private struct Layer {
        let y: Double
        let freq: Double
        let amp: Double
        let speed: Double
        let color: Color
    }

    private var palette: [Color] {
        if let tint {
            return [tint, tint, tint]
        }
        if let colors, colors.count >= 3 { return colors }
        return [Color.blueSky, Color.blueMid, Color.blueDeep]
    }

    private var layers: [Layer] {
        let c = palette
        return [
            Layer(y: 0.64, freq: 1.2, amp: 34, speed: 0.30,  color: c[0].opacity(0.20 * intensity)),
            Layer(y: 0.72, freq: 1.7, amp: 28, speed: -0.25, color: c[1].opacity(0.16 * intensity)),
            Layer(y: 0.80, freq: 2.3, amp: 22, speed: 0.40,  color: c[2].opacity(0.14 * intensity))
        ]
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            waveCanvas(time: timeline.date.timeIntervalSinceReferenceDate)
        }
    }

    private func waveCanvas(time: Double) -> some View {
        Canvas { ctx, size in
            drawBase(ctx: ctx, size: size)
            let all = layers
            for index in all.indices {
                let path = wavePath(layer: all[index], index: index, time: time, size: size)
                ctx.fill(path, with: .color(all[index].color))
            }
        }
    }

    private func drawBase(ctx: GraphicsContext, size: CGSize) {
        guard tint == nil else { return }
        let rect = Path(CGRect(origin: .zero, size: size))
        // Con colores propios el fondo base es neutro; sin ellos, el azul pálido de siempre.
        let bottom: Color = colors == nil ? Color(red: 0.92, green: 0.96, blue: 1.0) : Color(white: 0.955)
        let gradient = Gradient(colors: [
            Color(white: 0.995),
            bottom
        ])
        let end = CGPoint(x: size.width, y: size.height)
        ctx.fill(rect, with: .linearGradient(gradient, startPoint: .zero, endPoint: end))
    }

    private func wavePath(layer: Layer, index: Int, time: Double, size: CGSize) -> Path {
        let width = Double(size.width)
        let height = Double(size.height)
        let baseY: Double = height * layer.y
        let phase: Double = time * layer.speed + Double(index)
        let twoPi: Double = 2.0 * Double.pi

        var p = Path()
        p.move(to: CGPoint(x: 0, y: height))

        var x: Double = 0
        while x <= width {
            let rel: Double = x / width
            let angle: Double = rel * twoPi * layer.freq + phase
            let y: Double = baseY + sin(angle) * layer.amp
            p.addLine(to: CGPoint(x: x, y: y))
            x += 5
        }

        p.addLine(to: CGPoint(x: width, y: height))
        p.closeSubpath()
        return p
    }
}

struct PSSymbols: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "triangle").foregroundStyle(Color.psGreen)
            Image(systemName: "circle").foregroundStyle(Color.psRed)
            Image(systemName: "xmark").foregroundStyle(Color.psBlue)
            Image(systemName: "square").foregroundStyle(Color.psPink)
        }
        .font(.system(size: 11, weight: .bold))
    }
}
