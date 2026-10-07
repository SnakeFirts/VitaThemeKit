import SwiftUI
import AppKit
import VitaThemeKit

// MARK: - Imagen reducida de cada página (se crea una sola vez)

/// `NSImage` de la versión reducida de cada página, guardada por id.
/// Así la imagen no se vuelve a crear ni a subir a la GPU en cada fotograma.
final class ProxyImageCache: @unchecked Sendable {
    static let shared = ProxyImageCache()
    private let cache = NSCache<NSUUID, NSImage>()

    func image(for page: PageDraft) -> NSImage {
        let key = page.id as NSUUID
        if let hit = cache.object(forKey: key) { return hit }
        let image = NSImage(cgImage: page.proxy, size: .zero)
        cache.setObject(image, forKey: key)
        return image
    }
}

// MARK: - Página con su encuadre (solo escala y desplazamiento)

/// Dibuja la página tal como saldrá, sin recortar la imagen cada vez:
/// la imagen completa se escala y se desplaza dentro de un marco con recorte.
/// Arrastrar o hacer zoom solo cambia números; no se crea ninguna imagen nueva.
/// Funciona a cualquier tamaño (lienzo grande, tarjeta del menú lateral...).
struct PageImageView: View {
    let page: PageDraft
    let size: CGSize

    var body: some View {
        let ps = page.proxySize
        let r = FramingMath.coverCrop(source: ps, target: ThemeProject.pageSize, framing: page.framing)
        // Escala que hace que el recorte llene el marco (si la proporción es otra, recorta un poco).
        let s = max(size.width / max(r.width, 1), size.height / max(r.height, 1))
        Image(nsImage: ProxyImageCache.shared.image(for: page))
            .resizable()
            .interpolation(.high)
            .frame(width: ps.width * s, height: ps.height * s)
            // Deja el centro del recorte en el centro del marco.
            .offset(x: size.width / 2 - r.midX * s,
                    y: size.height / 2 - r.midY * s)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
    }
}

// MARK: - Miniatura de la tira

/// Miniatura que solo se redibuja cuando cambia su propio encuadre (`.equatable()`),
/// y que renderiza fuera del hilo principal, esperando a que dejes de arrastrar.
struct PageThumb: View, Equatable {
    let page: PageDraft
    let index: Int
    let selected: Bool
    let accent: Color
    let size: CGSize
    let onSelect: () -> Void

    @State private var image: NSImage?

    static func == (lhs: PageThumb, rhs: PageThumb) -> Bool {
        lhs.page.id == rhs.page.id
            && lhs.page.zoom == rhs.page.zoom
            && lhs.page.focus == rhs.page.focus
            && lhs.index == rhs.index
            && lhs.selected == rhs.selected
    }

    private struct Key: Hashable {
        let zoom: Double
        let x: Double
        let y: Double
    }

    private var key: Key {
        Key(zoom: page.zoom, x: Double(page.focus.x), y: Double(page.focus.y))
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        Button(action: onSelect) {
            ZStack(alignment: .topLeading) {
                thumbImage
                numberBadge
            }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(selected ? accent : Color.white.opacity(0.55),
                                        lineWidth: selected ? 2.5 : 1))
        }
        .buttonStyle(.plain)
        .task(id: key) { await refresh() }
    }

    @ViewBuilder
    private var thumbImage: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.medium)
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            Rectangle().fill(Color.blueIce)
        }
    }

    private var numberBadge: some View {
        Text("\(index + 1)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(minWidth: 16)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.ink.opacity(0.75)))
    }

    // MARK: Render en segundo plano

    private struct Job: @unchecked Sendable {
        let proxy: CGImage
        let framing: Framing

        func render() -> Rendered {
            Rendered(image: try? ThemeImageRenderer.render(proxy, kind: .thumbnail, framing: framing))
        }
    }

    private struct Rendered: @unchecked Sendable {
        let image: CGImage?
    }

    private func refresh() async {
        // La primera vez se dibuja enseguida; después espera a que dejes de arrastrar.
        if image != nil {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
        }
        let job = Job(proxy: page.proxy, framing: page.framing)
        let rendered = await Task.detached(priority: .utility) { job.render() }.value
        if Task.isCancelled { return }
        if let cg = rendered.image {
            image = NSImage(cgImage: cg, size: .zero)
        }
    }
}
