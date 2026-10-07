import SwiftUI
import VitaThemeKit

enum LockpaperError: LocalizedError {
    case noImage
    var errorDescription: String? { "Choose an image for the lock screen." }
}

/// Imagen de la pantalla de bloqueo (lockpaper.png) con su encuadre.
/// `center` es el centro del recorte, normalizado (0...1) sobre la imagen original.
final class LockpaperModel: ObservableObject {
    static let outputSize = CGSize(width: 960, height: 544)

    @Published private(set) var sourceURL: URL?
    @Published private(set) var cgImage: CGImage?
    @Published private(set) var nsImage: NSImage?
    @Published private(set) var zoom: Double = 1
    @Published private(set) var center = CGPoint(x: 0.5, y: 0.5)
    @Published var status: String?

    var hasImage: Bool { cgImage != nil }

    // MARK: Carga

    func setImage(from url: URL) {
        guard let cg = try? ThemeImageRenderer.load(url: url, maxPixelSize: 8192) else {
            status = "Could not open the image."
            return
        }
        cgImage = cg
        nsImage = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        sourceURL = url
        zoom = 1
        center = CGPoint(x: 0.5, y: 0.5)
        status = nil
    }

    func clear() {
        cgImage = nil
        nsImage = nil
        sourceURL = nil
        zoom = 1
        center = CGPoint(x: 0.5, y: 0.5)
        status = nil
    }

    // MARK: Encuadre

    func setZoom(_ value: Double) {
        zoom = Framing.clampZoom(value)
        center = clampedCenter(center)
    }

    func reset() {
        zoom = 1
        center = CGPoint(x: 0.5, y: 0.5)
    }

    func pan(from start: CGPoint, translation: CGSize, displayedWidth w: CGFloat) {
        guard let cg = cgImage, w > 0 else { return }
        let sw = CGFloat(cg.width)
        let sh = CGFloat(cg.height)
        let cropW = baseCrop(cg).width / CGFloat(zoom)
        let pxPerPoint = cropW / w
        let nx = start.x - (translation.width * pxPerPoint) / sw
        let ny = start.y - (translation.height * pxPerPoint) / sh
        center = clampedCenter(CGPoint(x: nx, y: ny))
    }

    /// Recorte en píxeles de la imagen original (misma proporción que la pantalla).
    var cropRect: CGRect? {
        guard let cg = cgImage else { return nil }
        let sw = CGFloat(cg.width)
        let sh = CGFloat(cg.height)
        let base = baseCrop(cg)
        let z = CGFloat(zoom)
        let cw = base.width / z
        let ch = base.height / z
        let cx = min(max(center.x * sw, cw / 2), sw - cw / 2)
        let cy = min(max(center.y * sh, ch / 2), sh - ch / 2)
        return CGRect(x: cx - cw / 2, y: cy - ch / 2, width: cw, height: ch)
    }

    /// > 1 significa que la imagen se amplía para llenar 960 px de ancho.
    var upscaleFactor: Double {
        guard let r = cropRect, r.width > 0 else { return 1 }
        return Double(Self.outputSize.width / r.width)
    }

    private func baseCrop(_ cg: CGImage) -> CGSize {
        let sw = CGFloat(cg.width)
        let sh = CGFloat(cg.height)
        let ratio = Self.outputSize.width / Self.outputSize.height
        if sw / sh > ratio { return CGSize(width: sh * ratio, height: sh) }
        return CGSize(width: sw, height: sw / ratio)
    }

    private func clampedCenter(_ c: CGPoint) -> CGPoint {
        guard let cg = cgImage else { return c }
        let sw = CGFloat(cg.width)
        let sh = CGFloat(cg.height)
        let base = baseCrop(cg)
        let z = CGFloat(zoom)
        let hx = (base.width / z) / 2 / sw
        let hy = (base.height / z) / 2 / sh
        return CGPoint(x: min(max(c.x, hx), 1 - hx),
                       y: min(max(c.y, hy), 1 - hy))
    }

    // MARK: Exportar

    @discardableResult
    func export(to directory: URL) throws -> URL {
        guard let cg = cgImage, let crop = cropRect else { throw LockpaperError.noImage }
        return try PageImages.writeLockpaper(image: cg, crop: crop, to: directory)
    }
}

// MARK: - Imagen encuadrada

/// Dibuja la imagen exactamente como saldrá en lockpaper.png, a cualquier tamaño.
struct LockpaperImage: View {
    @ObservedObject var model: LockpaperModel
    let size: CGSize

    var body: some View {
        content
            .frame(width: size.width, height: size.height)
            .clipped()
    }

    @ViewBuilder
    private var content: some View {
        if let ns = model.nsImage, let cg = model.cgImage, let r = model.cropRect {
            let s = size.width / r.width
            Image(nsImage: ns)
                .resizable()
                .interpolation(.high)
                .frame(width: CGFloat(cg.width) * s, height: CGFloat(cg.height) * s)
                .offset(x: -r.minX * s, y: -r.minY * s)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
        } else {
            Color.clear
        }
    }
}

// MARK: - Barra de zoom

struct LockpaperZoomBar: View {
    @ObservedObject var model: LockpaperModel
    var tint: Color = Color.blueDeep

    private var zoomBinding: Binding<Double> {
        Binding(get: { model.zoom }, set: { model.setZoom($0) })
    }

    var body: some View {
        HStack(spacing: 10) {
            step("minus", shortcut: "-") { model.setZoom(model.zoom - 0.5) }
                .disabled(model.zoom <= Framing.zoomRange.lowerBound)

            Slider(value: zoomBinding, in: Framing.zoomRange)
                .tint(tint)
                .controlSize(.small)
                .frame(width: 150)

            step("plus", shortcut: "+") { model.setZoom(model.zoom + 0.5) }
                .disabled(model.zoom >= Framing.zoomRange.upperBound)

            Text(String(format: "%.1f×", model.zoom))
                .monospacedDigit()
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42)

            Divider().frame(height: 18)

            Button { model.reset() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("0", modifiers: .command)
            .help("Reset framing")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.92)))
        .overlay(Capsule().strokeBorder(Color.white, lineWidth: 1))
        .shadow(color: Color.ink.opacity(0.12), radius: 12, y: 5)
    }

    private func step(_ icon: String, shortcut: KeyEquivalent,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(tint.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut, modifiers: .command)
    }
}
