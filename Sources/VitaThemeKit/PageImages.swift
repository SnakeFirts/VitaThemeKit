import Foundation
import CoreGraphics

/// Escribe en disco las imágenes del tema (PNG indexado de 256 colores).
public enum PageImages {

    // MARK: - Helpers

    /// Cuantiza a paleta y escribe `name` dentro de `directory` (la crea si no existe).
    @discardableResult
    private static func write(_ rendered: CGImage, as name: String, to directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try ThemeImageRenderer.pngData(PaletteQuantizer.quantize(rendered)).write(to: url)
        return url
    }

    /// Carga `source`, la encuadra al tamaño de `kind` y la escribe como `name`.
    private static func write(source: URL, kind: ThemeImageKind, as name: String,
                              framing: Framing, to directory: URL) throws -> URL {
        let image = try ThemeImageRenderer.load(url: source)
        return try write(ThemeImageRenderer.render(image, kind: kind, framing: framing),
                         as: name, to: directory)
    }

    // MARK: - Fondos

    /// Escribe `bg<N>.png` y `bgt<N>.png`. Ambos tamaños tienen la misma proporción,
    /// así que el encuadre se ve igual en el fondo y en la miniatura.
    @discardableResult
    public static func writePage(number: Int,
                                 source: URL,
                                 framing: Framing = .default,
                                 to directory: URL) throws -> [URL] {
        let image = try ThemeImageRenderer.load(url: source)
        return try writePage(number: number, image: image, framing: framing, to: directory)
    }

    @discardableResult
    public static func writePage(number: Int,
                                 image: CGImage,
                                 framing: Framing = .default,
                                 to directory: URL) throws -> [URL] {
        let outputs: [(ThemeImageKind, String)] = [(.background, "bg\(number).png"),
                                                   (.thumbnail, "bgt\(number).png")]
        return try outputs.map { kind, name in
            try write(ThemeImageRenderer.render(image, kind: kind, framing: framing),
                      as: name, to: directory)
        }
    }

    /// Escribe bg1/bgt1, bg2/bgt2... en el orden dado (la primera página es la 1).
    /// Cada archivo de origen se lee una sola vez aunque se repita (panoramas).
    public static func writePages(_ pages: [(source: URL, framing: Framing)], to directory: URL) throws {
        var cache: [URL: CGImage] = [:]
        for (index, page) in pages.enumerated() {
            let image = try cache[page.source] ?? ThemeImageRenderer.load(url: page.source)
            cache[page.source] = image
            try writePage(number: index + 1, image: image, framing: page.framing, to: directory)
        }
    }

    /// Reparte una imagen larga entre varias páginas y escribe bg1.png, bgt1.png, bg2.png...
    /// (de izquierda a derecha, o de arriba hacia abajo si es vertical).
    /// - Parameters:
    ///   - pages: número de páginas; `nil` = automático (máximo 10).
    ///   - axis: dirección del corte; `nil` = automática según la proporción.
    /// `framing.zoom` y `framing.focus` se aplican al panorama completo.
    public static func writePanorama(source: URL,
                                     pages: Int? = nil,
                                     axis: PanoramaAxis? = nil,
                                     framing: Framing = .default,
                                     to directory: URL) throws -> PanoramaResult {
        let image = try ThemeImageRenderer.load(url: source)
        let size = CGSize(width: image.width, height: image.height)
        let plan = FramingMath.panoramaPlan(source: size, pages: pages, axis: axis, framing: framing)

        var files: [URL] = []
        for (index, crop) in plan.pageCrops.enumerated() {
            let number = index + 1
            let outputs: [(ThemeImageKind, String)] = [(.background, "bg\(number).png"),
                                                       (.thumbnail, "bgt\(number).png")]
            for (kind, name) in outputs {
                let page = try ThemeImageRenderer.render(image, crop: crop, targetSize: kind.pixelSize)
                files.append(try write(page, as: name, to: directory))
            }
        }
        return PanoramaResult(plan: plan, files: files, sourceSize: size)
    }

    // MARK: - Iconos, vistas previas y avisos

    /// Escribe `icon_<name>.png`.
    @discardableResult
    public static func writeIcon(name: String, source: URL,
                                 framing: Framing = .default, to directory: URL) throws -> URL {
        try write(source: source, kind: .icon, as: "icon_\(name).png", framing: framing, to: directory)
    }

    /// Escribe `preview_thumbnail.png`.
    @discardableResult
    public static func writePreviewThumbnail(source: URL,
                                             framing: Framing = .default, to directory: URL) throws -> URL {
        try write(source: source, kind: .previewThumbnail, as: "preview_thumbnail.png",
                  framing: framing, to: directory)
    }

    /// Escribe `preview_page.png`.
    @discardableResult
    public static func writePreviewPage(source: URL,
                                        framing: Framing = .default, to directory: URL) throws -> URL {
        try write(source: source, kind: .previewPage, as: "preview_page.png",
                  framing: framing, to: directory)
    }

    /// Escribe `preview_lockscreen.png` a partir de una imagen y un encuadre.
    @discardableResult
    public static func writePreviewLockscreen(source: URL,
                                              framing: Framing = .default, to directory: URL) throws -> URL {
        try write(source: source, kind: .previewLockscreen, as: "preview_lockscreen.png",
                  framing: framing, to: directory)
    }

    /// Variante que parte del mismo recorte que `lockpaper.png`, para que la vista
    /// previa coincida con la pantalla de bloqueo.
    @discardableResult
    public static func writePreviewLockscreen(image: CGImage, crop: CGRect, to directory: URL) throws -> URL {
        let rendered = try ThemeImageRenderer.render(image, crop: crop,
                                                     targetSize: ThemeImageKind.previewLockscreen.pixelSize)
        return try write(rendered, as: "preview_lockscreen.png", to: directory)
    }

    /// Escribe la imagen de la bolita de la barra (120×110): `notice.png` si `hasNew`,
    /// `notices.png` si no.
    @discardableResult
    public static func writeNotice(hasNew: Bool, source: URL,
                                   framing: Framing = .default, to directory: URL) throws -> URL {
        try write(source: source, kind: .notice, as: hasNew ? "notice.png" : "notices.png",
                  framing: framing, to: directory)
    }

    // MARK: - Pantalla de bloqueo

    /// Escribe `lockpaper.png` a partir de una imagen ya cargada y un recorte en píxeles.
    @discardableResult
    public static func writeLockpaper(image: CGImage, crop: CGRect, to directory: URL) throws -> URL {
        let rendered = try ThemeImageRenderer.render(image, crop: crop,
                                                     targetSize: ThemeImageKind.background.pixelSize)
        return try write(rendered, as: "lockpaper.png", to: directory)
    }

    /// Escribe `lockpaper.png` a partir de un archivo y un `Framing`.
    @discardableResult
    public static func writeLockpaper(source: URL,
                                      framing: Framing = .default, to directory: URL) throws -> URL {
        try write(source: source, kind: .background, as: "lockpaper.png", framing: framing, to: directory)
    }
}

public struct PanoramaResult: Sendable {
    public let plan: PanoramaPlan
    public let files: [URL]
    public let sourceSize: CGSize
}
