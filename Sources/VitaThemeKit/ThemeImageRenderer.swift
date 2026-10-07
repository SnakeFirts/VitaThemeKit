import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ThemeImageError: Error {
    case cannotReadImage(URL)
    case cannotCreateContext
    case cannotCrop
    case cannotEncodePNG
}

public enum ThemeImageRenderer {

    /// Carga una imagen respetando la orientación EXIF. `maxPixelSize` limita el lado mayor
    /// (útil para vistas previas ligeras).
    public static func load(url: URL, maxPixelSize: Int = 16384) throws -> CGImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ThemeImageError.cannotReadImage(url)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
            throw ThemeImageError.cannotReadImage(url)
        }
        return img
    }

    /// Genera la imagen final del tamaño exacto pedido.
    public static func render(_ source: CGImage,
                              kind: ThemeImageKind,
                              framing: Framing = .default) throws -> CGImage {
        try render(source, targetSize: kind.pixelSize, framing: framing)
    }

    /// Contexto sRGB de 8 bits del tamaño pedido.
    private static func makeContext(size: CGSize) throws -> (ctx: CGContext, space: CGColorSpace) {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ThemeImageError.cannotCreateContext }
        ctx.interpolationQuality = .high
        return (ctx, space)
    }

    public static func render(_ source: CGImage,
                              targetSize: CGSize,
                              framing: Framing = .default) throws -> CGImage {
        let (ctx, space) = try makeContext(size: targetSize)
        let w = Int(targetSize.width), h = Int(targetSize.height)
        let srcSize = CGSize(width: source.width, height: source.height)
        let full = CGRect(x: 0, y: 0, width: w, height: h)

        switch framing.mode {
        case .cover:
            let crop = FramingMath.coverCrop(source: srcSize, target: targetSize, framing: framing)
            guard let cropped = source.cropping(to: crop.integral) else {
                throw ThemeImageError.cannotCrop
            }
            ctx.draw(cropped, in: full)

        case .contain:
            let f = framing.fill
            ctx.setFillColor(CGColor(colorSpace: space, components: [f.r, f.g, f.b, f.a].map { CGFloat($0) })!)
            ctx.fill(full)
            // El contexto tiene origen abajo-izquierda; el rect del cálculo
            // usa origen arriba-izquierda, así que se invierte Y.
            let r = FramingMath.containRect(source: srcSize, target: targetSize, framing: framing)
            let flipped = CGRect(x: r.minX, y: targetSize.height - r.maxY,
                                 width: r.width, height: r.height)
            ctx.draw(source, in: flipped)
        }

        guard let out = ctx.makeImage() else { throw ThemeImageError.cannotCreateContext }
        return out
    }

    /// Dibuja exactamente la región `crop` de la imagen original en un
    /// lienzo del tamaño final. Se usa para cada página del panorama.
    public static func render(_ source: CGImage,
                              crop: CGRect,
                              targetSize: CGSize) throws -> CGImage {
        let (ctx, _) = try makeContext(size: targetSize)
        guard let cropped = source.cropping(to: crop) else {
            throw ThemeImageError.cannotCrop
        }
        ctx.draw(cropped, in: CGRect(origin: .zero, size: targetSize))
        guard let out = ctx.makeImage() else { throw ThemeImageError.cannotCreateContext }
        return out
    }

    public static func pngData(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw ThemeImageError.cannotEncodePNG
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ThemeImageError.cannotEncodePNG }
        return data as Data
    }
}
