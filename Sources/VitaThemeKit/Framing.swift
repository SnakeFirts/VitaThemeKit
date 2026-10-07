import Foundation
import CoreGraphics

/// Cómo se acomoda la imagen original dentro del marco final.
public enum FitMode: Sendable, Equatable {
    /// Llena todo el marco recortando lo que sobre (por defecto).
    case cover
    /// Cabe completa; el espacio sobrante se rellena con `fill`.
    case contain
}

/// Color de relleno RGBA (0...1) para el modo `.contain`.
public struct FillColor: Sendable, Equatable {
    public var r, g, b, a: Double
    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
    public static let black = FillColor(r: 0, g: 0, b: 0)
}

/// Encuadre editable por el usuario.
public struct Framing: Sendable, Equatable {
    public var mode: FitMode
    /// 1 = ajuste base; mayor que 1 acerca. Se limita a `zoomRange`.
    public var zoom: Double
    /// Punto de la imagen (0...1, origen arriba-izquierda) que se intenta
    /// centrar en el marco. (0.5, 0.5) = centro.
    public var focus: CGPoint
    public var fill: FillColor

    public init(mode: FitMode = .cover,
                zoom: Double = 1,
                focus: CGPoint = CGPoint(x: 0.5, y: 0.5),
                fill: FillColor = .black) {
        self.mode = mode
        self.zoom = zoom
        self.focus = focus
        self.fill = fill
    }

    public static let `default` = Framing()

    /// Zoom permitido: 1 = ajuste base.
    public static let zoomRange: ClosedRange<Double> = 1...8

    public static func clampZoom(_ zoom: Double) -> Double {
        min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound)
    }
}

/// Matemática pura del encuadre (sin dependencias gráficas, fácil de probar).
public enum FramingMath {

    /// Región de la imagen original (en píxeles, origen arriba-izquierda)
    /// que debe verse en el marco cuando el modo es `.cover`.
    public static func coverCrop(source: CGSize,
                                 target: CGSize,
                                 framing: Framing) -> CGRect {
        let zoom = Framing.clampZoom(framing.zoom)
        // Escala que hace que la imagen apenas llene el marco.
        let baseScale = max(target.width / source.width,
                            target.height / source.height)
        let scale = baseScale * zoom
        let cropW = min(target.width / scale, source.width)
        let cropH = min(target.height / scale, source.height)

        let fx = min(max(Double(framing.focus.x), 0), 1)
        let fy = min(max(Double(framing.focus.y), 0), 1)
        var x = fx * source.width - cropW / 2
        var y = fy * source.height - cropH / 2
        x = min(max(x, 0), source.width - cropW)
        y = min(max(y, 0), source.height - cropH)
        return CGRect(x: x, y: y, width: cropW, height: cropH)
    }

    /// Centro real del recorte (0...1). Evita "zonas muertas" al arrastrar.
    public static func actualCenter(source: CGSize, target: CGSize, framing: Framing) -> CGPoint {
        let c = coverCrop(source: source, target: target, framing: framing)
        return CGPoint(x: c.midX / source.width, y: c.midY / source.height)
    }

    /// Nuevo `focus` después de arrastrar `translation` puntos sobre una vista de tamaño `displayed`.
    public static func pannedFocus(from start: CGPoint,
                                   translation t: CGSize,
                                   displayed: CGSize,
                                   source: CGSize,
                                   target: CGSize,
                                   framing: Framing) -> CGPoint {
        let crop = coverCrop(source: source, target: target, framing: framing)
        let dx = -t.width / displayed.width * crop.width / source.width
        let dy = -t.height / displayed.height * crop.height / source.height
        return CGPoint(x: min(max(start.x + dx, 0), 1),
                       y: min(max(start.y + dy, 0), 1))
    }

    /// Rectángulo dentro del marco donde se dibuja la imagen en `.contain`.
    public static func containRect(source: CGSize,
                                   target: CGSize,
                                   framing: Framing) -> CGRect {
        let zoom = Framing.clampZoom(framing.zoom)
        let scale = min(target.width / source.width,
                        target.height / source.height) * zoom
        let w = source.width * scale
        let h = source.height * scale
        // Con zoom 1 queda centrada; con zoom mayor se respeta el focus.
        let fx = Double(framing.focus.x), fy = Double(framing.focus.y)
        var x = target.width / 2 - fx * w
        var y = target.height / 2 - fy * h
        if w <= target.width { x = (target.width - w) / 2 }
        else { x = min(max(x, target.width - w), 0) }
        if h <= target.height { y = (target.height - h) / 2 }
        else { y = min(max(y, target.height - h), 0) }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

/// Dirección en la que se corta la imagen larga.
public enum PanoramaAxis: Sendable, Equatable {
    /// Páginas una al lado de otra: bg1 a la izquierda.
    case horizontal
    /// Páginas apiladas: bg1 arriba, la última abajo.
    case vertical
}

/// Resultado de repartir una imagen larga entre varias páginas.
public struct PanoramaPlan: Sendable, Equatable {
    public let pageCount: Int
    public let axis: PanoramaAxis
    /// Región de la imagen original (píxeles, origen arriba-izquierda)
    /// que corresponde a cada página, en orden: índice 0 = bg1.
    public let pageCrops: [CGRect]
    /// Mayor que 1 = la imagen se amplía respecto al original (pierde nitidez).
    public let scaleFactor: Double
}

extension FramingMath {

    /// Si la imagen es más ancha que una página, se corta en horizontal;
    /// si es más angosta (alta), en vertical.
    public static func autoAxis(source: CGSize,
                                page: CGSize = ThemeImageKind.background.pixelSize) -> PanoramaAxis {
        (source.width / source.height) >= (page.width / page.height) ? .horizontal : .vertical
    }

    /// Cuántas páginas "caben" en la imagen: se escala para que llene el
    /// marco en el lado corto y se cuenta cuántas páginas resultan a lo largo
    /// (redondeado, entre 1 y 10).
    public static func autoPageCount(source: CGSize,
                                     axis: PanoramaAxis? = nil,
                                     page: CGSize = ThemeImageKind.background.pixelSize) -> Int {
        let resolved = axis ?? autoAxis(source: source, page: page)
        let pageAspect = page.width / page.height
        let count: Double
        switch resolved {
        case .horizontal: count = (source.width / source.height) / pageAspect
        case .vertical:   count = (source.height / source.width) * pageAspect
        }
        return min(max(Int(count.rounded()), 1), Theme.maxPages)
    }

    /// Trata las N páginas como un solo lienzo (N páginas en fila o en columna),
    /// le aplica el encuadre `.cover` (con zoom/enfoque globales) y lo corta en
    /// N tramos contiguos, sin huecos ni solapes.
    public static func panoramaPlan(source: CGSize,
                                    pages: Int? = nil,
                                    axis: PanoramaAxis? = nil,
                                    framing: Framing = .default,
                                    page: CGSize = ThemeImageKind.background.pixelSize) -> PanoramaPlan {
        let resolvedAxis = axis ?? autoAxis(source: source, page: page)
        let n = min(max(pages ?? autoPageCount(source: source, axis: resolvedAxis, page: page), 1), Theme.maxPages)
        let count = CGFloat(n)

        let canvas: CGSize
        switch resolvedAxis {
        case .horizontal: canvas = CGSize(width: page.width * count, height: page.height)
        case .vertical:   canvas = CGSize(width: page.width, height: page.height * count)
        }
        let crop = coverCrop(source: source, target: canvas, framing: framing)

        var crops: [CGRect] = []
        switch resolvedAxis {
        case .horizontal:
            let y = crop.minY.rounded(.down)
            let h = min(crop.height.rounded(), source.height - y)
            for i in 0..<n {
                let x0 = (crop.minX + crop.width * CGFloat(i) / count).rounded()
                let x1 = (crop.minX + crop.width * CGFloat(i + 1) / count).rounded()
                crops.append(CGRect(x: x0, y: y, width: x1 - x0, height: h))
            }
        case .vertical:
            let x = crop.minX.rounded(.down)
            let w = min(crop.width.rounded(), source.width - x)
            for i in 0..<n {
                let y0 = (crop.minY + crop.height * CGFloat(i) / count).rounded()
                let y1 = (crop.minY + crop.height * CGFloat(i + 1) / count).rounded()
                crops.append(CGRect(x: x, y: y0, width: w, height: y1 - y0))
            }
        }
        return PanoramaPlan(pageCount: n,
                            axis: resolvedAxis,
                            pageCrops: crops,
                            scaleFactor: Double(canvas.width / crop.width))
    }
}
