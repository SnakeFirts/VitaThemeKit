import SwiftUI
import VitaThemeKit

/// Barra superior de la Vita con las medidas de una consola real (pantalla de 960×544).
/// La comparten la vista de la barra y la de la pantalla de bloqueo, para que coincidan.
struct VitaStatusBar: View {
    let colors: ThemeColors
    /// La casa va en el inicio, no en la pantalla de bloqueo.
    var showsHome: Bool = true
    /// Distancia del borde derecho al final de la batería.
    /// En el inicio son 90 px (deja sitio a la bolita de avisos).
    var trailingInset: CGFloat = 90
    var percent: Int = 67

    var body: some View {
        TimelineView(.everyMinute) { tl in
            let clock = ClockText(tl.date)
            let ink = colors.indicator.color
            let r = 960 - trailingInset   // borde derecho de la batería

            ZStack {
                // Señal (izquierda)
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(ink)
                    .frame(width: 15, height: 15)
                    .position(x: 20.5, y: 18)

                // Casa (centro)
                if showsHome {
                    Image(systemName: "house.fill")
                        .font(.system(size: 18, weight: .bold))
                }

                // Hora: se alinea a la derecha contra "AM/PM"
                Text(clock.time)
                    .font(.system(size: 22, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .frame(width: 120, alignment: .trailing)
                    .position(x: r - 142 - 60, y: 15.5)

                Text(clock.ampm)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ink)
                    .frame(width: 40, alignment: .leading)
                    .position(x: r - 134 + 20, y: 17.5)

                Text("\(percent)%")
                    .font(.system(size: 21, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .frame(width: 70, alignment: .trailing)
                    .position(x: r - 48 - 35, y: 16)

                batteryIcon
                    .position(x: r - 19, y: 15.5)
            }
            .frame(width: 960, height: 32)
            .background(colors.bar.color)
        }
    }

    /// 38×20. Se llena desde la derecha y el lado izquierdo queda gris.
    private var batteryIcon: some View {
        let level = Double(min(max(percent, 0), 100)) / 100
        let fillWidth = 38 * (0.12 + 0.88 * level)
        let shape = RoundedRectangle(cornerRadius: 3.5, style: .continuous)
        return ZStack(alignment: .trailing) {
            shape.fill(Color(white: 0.41))
            shape
                .fill(LinearGradient(stops: [
                    .init(color: Color(red: 0.62, green: 0.75, blue: 0.31), location: 0.00),
                    .init(color: Color(red: 0.84, green: 0.91, blue: 0.60), location: 0.10),
                    .init(color: Color(red: 0.90, green: 0.94, blue: 0.73), location: 0.18),
                    .init(color: Color(red: 0.80, green: 0.86, blue: 0.57), location: 0.36),
                    .init(color: Color(red: 0.58, green: 0.77, blue: 0.34), location: 0.55),
                    .init(color: Color(red: 0.35, green: 0.68, blue: 0.15), location: 0.73),
                    .init(color: Color(red: 0.33, green: 0.55, blue: 0.16), location: 1.00)
                ], startPoint: .top, endPoint: .bottom))
                .frame(width: fillWidth)
        }
        .frame(width: 38, height: 20)
        .clipShape(shape)
    }
}

// MARK: - Fecha y hora

struct ClockText {
    let date: String
    let time: String
    let ampm: String

    init(_ d: Date) {
        let cal = Calendar.current
        let h = cal.component(.hour, from: d)
        let m = cal.component(.minute, from: d)
        let h12 = (h % 12 == 0) ? 12 : (h % 12)
        time = "\(h12):" + String(format: "%02d", m)
        ampm = h < 12 ? "AM" : "PM"

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "LLLL d (EEEE)"
        let raw = f.string(from: d)
        date = String(raw.prefix(1)).uppercased() + String(raw.dropFirst())
    }
}
