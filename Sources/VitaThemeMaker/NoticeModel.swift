import SwiftUI
import AppKit
import VitaThemeKit

/// Imágenes de la bolita de la barra:
/// notices.png (hay avisos nuevos) y notice.png (sin avisos), 120×110, con su encuadre.
final class NoticeModel: ObservableObject {
    /// Tamaño final de notice.png / notices.png.
    static let outputSize = ThemeImageKind.notice.pixelSize

    private struct Slot {
        var source: URL
        /// Copia reducida para editar rápido. El encuadre es normalizado, así que vale igual para el original.
        var proxy: CGImage
        var framing = Framing.default

        var proxySize: CGSize { CGSize(width: proxy.width, height: proxy.height) }
    }

    @Published private var newSlot: Slot?
    @Published private var noneSlot: Slot?
    @Published private(set) var newThumb: NSImage?
    @Published private(set) var noneThumb: NSImage?
    @Published var status: String?

    var hasAny: Bool { newSlot != nil || noneSlot != nil }

    func thumb(hasNew: Bool) -> NSImage? { hasNew ? newThumb : noneThumb }
    func source(hasNew: Bool) -> URL? { slot(hasNew)?.source }
    func framing(hasNew: Bool) -> Framing? { slot(hasNew)?.framing }

    private func slot(_ hasNew: Bool) -> Slot? { hasNew ? newSlot : noneSlot }

    // MARK: Cargar y quitar

    func set(hasNew: Bool, url: URL) {
        // Copia de lado mayor 1200 px: basta para editar rápido.
        guard let proxy = try? ThemeImageRenderer.load(url: url, maxPixelSize: 1200) else {
            status = "Could not open the image: \(url.lastPathComponent)"
            return
        }
        store(Slot(source: url, proxy: proxy), hasNew: hasNew)
        status = nil
    }

    func remove(hasNew: Bool) {
        store(nil, hasNew: hasNew)
    }

    /// Guarda el slot y vuelve a dibujar su miniatura de 120×110.
    private func store(_ value: Slot?, hasNew: Bool) {
        var thumb: NSImage?
        if let v = value,
           let out = try? ThemeImageRenderer.render(v.proxy, kind: .notice, framing: v.framing) {
            thumb = NSImage(cgImage: out, size: .zero)
        }
        if hasNew {
            newSlot = value
            newThumb = thumb
        } else {
            noneSlot = value
            noneThumb = thumb
        }
    }

    private func update(_ hasNew: Bool, _ change: (inout Slot) -> Void) {
        guard var s = slot(hasNew) else { return }
        change(&s)
        store(s, hasNew: hasNew)
    }

    // MARK: Encuadre

    func setZoom(_ value: Double, hasNew: Bool) {
        update(hasNew) { $0.framing.zoom = Framing.clampZoom(value) }
    }

    func resetFraming(hasNew: Bool) {
        update(hasNew) {
            $0.framing.zoom = 1
            $0.framing.focus = CGPoint(x: 0.5, y: 0.5)
        }
    }

    func actualCenter(hasNew: Bool) -> CGPoint {
        guard let s = slot(hasNew) else { return CGPoint(x: 0.5, y: 0.5) }
        return FramingMath.actualCenter(source: s.proxySize, target: Self.outputSize, framing: s.framing)
    }

    func pan(hasNew: Bool, from start: CGPoint, translation t: CGSize, displayed: CGSize) {
        guard let s = slot(hasNew), displayed.width > 0, displayed.height > 0 else { return }
        let focus = FramingMath.pannedFocus(from: start, translation: t, displayed: displayed,
                                            source: s.proxySize, target: Self.outputSize,
                                            framing: s.framing)
        update(hasNew) { $0.framing.focus = focus }
    }

    /// La imagen tal como saldrá, a un tamaño mayor para el editor (mismo aspecto 120:110).
    func editorImage(hasNew: Bool, width: CGFloat) -> NSImage? {
        guard let s = slot(hasNew) else { return nil }
        let size = CGSize(width: width,
                          height: (width * Self.outputSize.height / Self.outputSize.width).rounded())
        guard let out = try? ThemeImageRenderer.render(s.proxy, targetSize: size, framing: s.framing)
        else { return nil }
        return NSImage(cgImage: out, size: .zero)
    }

    // MARK: Exportar

    /// Escribe solo las que tengan imagen, con su encuadre, desde el archivo original.
    func export(to dir: URL) {
        var written: [String] = []
        do {
            if let s = noneSlot {
                let out = try PageImages.writeNotice(hasNew: false, source: s.source,
                                                     framing: s.framing, to: dir)
                written.append(out.lastPathComponent)
            }
            if let s = newSlot {
                let out = try PageImages.writeNotice(hasNew: true, source: s.source,
                                                     framing: s.framing, to: dir)
                written.append(out.lastPathComponent)
            }
            status = written.isEmpty
                ? "There are no images to export."
                : "Done: \(written.joined(separator: " and ")) in \(dir.lastPathComponent)"
        } catch {
            status = "Error: \(error)"
        }
    }
}
