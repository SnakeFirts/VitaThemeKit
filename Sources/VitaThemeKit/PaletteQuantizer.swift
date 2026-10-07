import Foundation
import CoreGraphics

/// Reduce una imagen a una paleta de hasta 256 colores (median cut)
/// y devuelve un CGImage indexado de 8 bits.
public enum PaletteQuantizer {

    public static func quantize(_ source: CGImage,
                                maxColors: Int = 256,
                                dither: Bool = true) throws -> CGImage {
        let w = source.width, h = source.height
        guard let rgb = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: rgb,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              ctx.data != nil
        else { throw ThemeImageError.cannotCreateContext }
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)

        // 1. Histograma con 5 bits por canal (32768 casillas).
        var count = [Int](repeating: 0, count: 32768)
        var sumR = count, sumG = count, sumB = count
        for i in 0..<(w * h) {
            let r = Int(px[i * 4]), g = Int(px[i * 4 + 1]), b = Int(px[i * 4 + 2])
            let key = (r >> 3) << 10 | (g >> 3) << 5 | (b >> 3)
            count[key] += 1
            sumR[key] += r; sumG[key] += g; sumB[key] += b
        }

        // 2. Median cut sobre las casillas usadas.
        struct Box { var bins: [Int]; var n: Int }
        let used = (0..<32768).filter { count[$0] > 0 }
        var boxes = [Box(bins: used, n: w * h)]

        while boxes.count < maxColors {
            guard let idx = boxes.indices
                .filter({ boxes[$0].bins.count > 1 })
                .max(by: { boxes[$0].n < boxes[$1].n }) else { break }
            var box = boxes[idx]

            // canal con más rango
            var lo = [31, 31, 31], hi = [0, 0, 0]
            for k in box.bins {
                let c = [k >> 10, (k >> 5) & 31, k & 31]
                for j in 0..<3 { lo[j] = min(lo[j], c[j]); hi[j] = max(hi[j], c[j]) }
            }
            let ranges = (0..<3).map { hi[$0] - lo[$0] }
            let ch = ranges.firstIndex(of: ranges.max()!)!
            let shift = [10, 5, 0][ch]
            box.bins.sort { (($0 >> shift) & 31) < (($1 >> shift) & 31) }

            // corte en la mediana ponderada por cantidad de píxeles
            var acc = 0, cut = 1
            for (i, k) in box.bins.enumerated() {
                acc += count[k]
                if acc * 2 >= box.n { cut = min(max(i + 1, 1), box.bins.count - 1); break }
            }
            let a = Array(box.bins[..<cut]), b = Array(box.bins[cut...])
            let na = a.reduce(0) { $0 + count[$1] }
            boxes[idx] = Box(bins: a, n: na)
            boxes.append(Box(bins: b, n: box.n - na))
        }

        // 3. Color promedio real de cada caja = entrada de la paleta.
        var pr = [Int](), pg = [Int](), pb = [Int]()
        for box in boxes {
            var n = 0, r = 0, g = 0, b = 0
            for k in box.bins { n += count[k]; r += sumR[k]; g += sumG[k]; b += sumB[k] }
            pr.append(r / n); pg.append(g / n); pb.append(b / n)
        }
        let size = pr.count

        // 4. Asignar cada píxel al color más cercano (con Floyd-Steinberg opcional).
        var indices = [UInt8](repeating: 0, count: w * h)
        var cur = [Float](repeating: 0, count: (w + 2) * 3)
        var nxt = cur
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                var c: [Float] = [Float(px[i]), Float(px[i + 1]), Float(px[i + 2])]
                if dither {
                    for j in 0..<3 { c[j] = min(max(c[j] + cur[(x + 1) * 3 + j], 0), 255) }
                }
                let r = Int(c[0]), g = Int(c[1]), b = Int(c[2])
                var best = 0, bestD = Int.max
                for k in 0..<size {
                    let dr = r - pr[k], dg = g - pg[k], db = b - pb[k]
                    let d = dr * dr + dg * dg + db * db
                    if d < bestD { bestD = d; best = k }
                }
                indices[y * w + x] = UInt8(best)
                if dither {
                    let p = [pr[best], pg[best], pb[best]]
                    for j in 0..<3 {
                        let e = c[j] - Float(p[j])
                        cur[(x + 2) * 3 + j] += e * 7 / 16
                        nxt[x * 3 + j]       += e * 3 / 16
                        nxt[(x + 1) * 3 + j] += e * 5 / 16
                        nxt[(x + 2) * 3 + j] += e * 1 / 16
                    }
                }
            }
            swap(&cur, &nxt)
            nxt = [Float](repeating: 0, count: (w + 2) * 3)
        }

        // 5. Armar el CGImage indexado.
        var table = [UInt8]()
        for k in 0..<size { table += [UInt8(pr[k]), UInt8(pg[k]), UInt8(pb[k])] }
        guard let space = table.withUnsafeBufferPointer({
                  CGColorSpace(indexedBaseSpace: rgb, last: size - 1, colorTable: $0.baseAddress!)
              }),
              let provider = CGDataProvider(data: Data(indices) as CFData),
              let out = CGImage(width: w, height: h,
                                bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w,
                                space: space,
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                provider: provider, decode: nil,
                                shouldInterpolate: false, intent: .defaultIntent)
        else { throw ThemeImageError.cannotCreateContext }
        return out
    }
}
