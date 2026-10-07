import SwiftUI

/// Logos de marca para el panel de contacto, dibujados como vectores
/// (se escalan sin perder nitidez y no necesitan archivos de imagen).
/// Trazados de Simple Icons (licencia CC0): https://simpleicons.org
/// Los logos son marcas de sus dueños; aquí solo se usan para enlazar a tus perfiles.
enum BrandIcon {
    case github, kofi, gmail

    /// Color oficial de la marca.
    var color: Color {
        switch self {
        case .github: return Color(red: 0x18 / 255, green: 0x17 / 255, blue: 0x17 / 255)
        case .kofi:   return Color(red: 0xFF / 255, green: 0x64 / 255, blue: 0x33 / 255)
        case .gmail:  return Color(red: 0xEA / 255, green: 0x43 / 255, blue: 0x35 / 255)
        }
    }

    /// Trazado en un lienzo de 24 x 24. Solo usa M, L, C y Z con coordenadas absolutas.
    fileprivate var data: String {
        switch self {
        case .github:
            return "M 12 0.297 C 5.37 0.297 0 5.67 0 12.297 C 0 17.6 3.438 22.097 8.205 23.682 C 8.805 23.795 9.025 23.424 9.025 23.105 C 9.025 22.82 9.015 22.065 9.01 21.065 C 5.672 21.789 4.968 19.455 4.968 19.455 C 4.422 18.07 3.633 17.7 3.633 17.7 C 2.546 16.956 3.717 16.971 3.717 16.971 C 4.922 17.055 5.555 18.207 5.555 18.207 C 6.625 20.042 8.364 19.512 9.05 19.205 C 9.158 18.429 9.467 17.9 9.81 17.6 C 7.145 17.3 4.344 16.268 4.344 11.67 C 4.344 10.36 4.809 9.29 5.579 8.45 C 5.444 8.147 5.039 6.927 5.684 5.274 C 5.684 5.274 6.689 4.952 8.984 6.504 C 9.944 6.237 10.964 6.105 11.984 6.099 C 13.004 6.105 14.024 6.237 14.984 6.504 C 17.264 4.952 18.269 5.274 18.269 5.274 C 18.914 6.927 18.509 8.147 18.389 8.45 C 19.154 9.29 19.619 10.36 19.619 11.67 C 19.619 16.28 16.814 17.295 14.144 17.59 C 14.564 17.95 14.954 18.686 14.954 19.81 C 14.954 21.416 14.939 22.706 14.939 23.096 C 14.939 23.411 15.149 23.786 15.764 23.666 C 20.565 22.092 24 17.592 24 12.297 C 24 5.67 18.627 0.297 12 0.297"
        case .kofi:
            return "M 11.351 2.715 C 8.651 2.715 6.365 2.74 4.521 2.975 C 2.078 3.285 0 5.154 0 8.61 C 0 12.116 0.182 14.74 1.585 17.103 C 3.169 19.804 5.818 21.285 9.247 21.285 L 10.077 21.285 C 14.286 21.285 16.571 19.051 17.714 17.285 C 17.9478 16.9225 18.1568 16.5441 18.3392 16.1532 C 18.5216 15.7623 18.6774 15.359 18.805 14.947 C 21.792 14.688 24 12.22 24 9.208 L 24 8.793 C 24 5.546 21.87 3.286 18.208 2.923 C 16.65 2.767 15.558 2.715 11.351 2.715 M 11.351 4.662 C 15.559 4.662 16.441 4.714 17.922 4.844 C 20.546 5.155 22.052 6.428 22.052 8.844 L 22.052 9.234 C 22.052 11.39 20.26 13.078 18.182 13.078 L 17.247 13.078 L 17.091 13.727 C 16.883 14.74 16.494 15.545 16.052 16.273 C 15.143 17.701 13.507 19.337 10.13 19.337 L 9.325 19.337 C 6.754 19.337 4.494 18.454 3.247 16.142 C 2.157 14.142 1.949 11.987 1.949 8.636 C 1.949 6.455 2.806 5.234 4.961 4.922 C 6.494 4.689 8.52 4.662 11.351 4.662 M 17.898 6.949 C 17.482 6.949 17.248 7.183 17.248 7.495 L 17.248 10.43 C 17.248 10.741 17.482 10.975 17.898 10.975 C 19.222 10.975 19.949 10.221 19.949 8.975 C 19.949 7.729 19.222 6.949 17.897 6.949 M 7.507 7.131 C 5.689 7.131 4.494 8.611 4.494 10.273 C 4.494 11.806 5.352 13.13 6.443 14.17 C 7.17 14.871 8.313 15.599 9.092 16.066 C 9.1826 16.1201 9.279 16.1644 9.379 16.1978 C 9.4791 16.2313 9.5827 16.254 9.6876 16.2653 C 9.7925 16.2766 9.8985 16.2766 10.0034 16.2653 C 10.1083 16.254 10.2119 16.2313 10.312 16.1978 C 10.412 16.1644 10.5084 16.1201 10.599 16.066 C 11.379 15.599 12.521 14.871 13.222 14.17 C 14.339 13.131 15.196 11.806 15.196 10.273 C 15.196 8.611 13.949 7.131 12.157 7.131 C 11.092 7.131 10.365 7.676 9.819 8.429 C 9.326 7.676 8.573 7.131 7.507 7.131"
        case .gmail:
            return "M 24 5.457 L 24 19.366 C 24 20.27 23.268 21.002 22.364 21.002 L 18.545 21.002 L 18.545 11.73 L 12 16.64 L 5.455 11.73 L 5.455 21.003 L 1.636 21.003 C 1.5136 21.003 1.3912 20.9892 1.2718 20.962 C 1.1525 20.9347 1.0362 20.894 0.9259 20.8409 C 0.8156 20.7877 0.7113 20.7222 0.6156 20.6458 C 0.5199 20.5695 0.4329 20.4823 0.3566 20.3866 C 0.2803 20.2908 0.2148 20.1865 0.1617 20.0762 C 0.1086 19.9659 0.068 19.8496 0.0408 19.7302 C 0.0136 19.6108 -0.0001 19.4884 0 19.366 L 0 5.457 C 0 3.434 2.309 2.279 3.927 3.493 L 5.455 4.64 L 12 9.548 L 18.545 4.638 L 20.073 3.493 C 21.69 2.28 24 3.434 24 5.457 Z"
        }
    }
}

/// Dibuja el logo ocupando el rectángulo donde se coloque.
/// Uso: `BrandMark(icon: .github).frame(width: 20, height: 20)`
struct BrandMark: View {
    let icon: BrandIcon
    /// `nil` = color oficial de la marca. Pasa un color para teñirlo (por ejemplo, todo en gris).
    var tint: Color? = nil

    var body: some View {
        BrandShape(icon: icon)
            .fill(tint ?? icon.color)
            .aspectRatio(1, contentMode: .fit)
    }
}

struct BrandShape: Shape {
    let icon: BrandIcon

    func path(in rect: CGRect) -> Path {
        let unit = Self.parse(icon.data)
        let scale = min(rect.width, rect.height) / 24
        let offsetX = rect.minX + (rect.width - 24 * scale) / 2
        let offsetY = rect.minY + (rect.height - 24 * scale) / 2
        let transform = CGAffineTransform(translationX: offsetX, y: offsetY).scaledBy(x: scale, y: scale)
        return unit.applying(transform)
    }

    /// Lee "M x y L x y C x1 y1 x2 y2 x y Z", todo separado por espacios.
    private static func parse(_ d: String) -> Path {
        var path = Path()
        let tokens = d.split(separator: " ").map(String.init)
        var i = 0

        func number() -> CGFloat {
            defer { i += 1 }
            return i < tokens.count ? CGFloat(Double(tokens[i]) ?? 0) : 0
        }
        func point() -> CGPoint {
            let x = number()
            let y = number()
            return CGPoint(x: x, y: y)
        }

        while i < tokens.count {
            let command = tokens[i]
            i += 1
            switch command {
            case "M": path.move(to: point())
            case "L": path.addLine(to: point())
            case "C":
                let c1 = point()
                let c2 = point()
                let end = point()
                path.addCurve(to: end, control1: c1, control2: c2)
            case "Z": path.closeSubpath()
            default: break
            }
        }
        return path
    }
}
