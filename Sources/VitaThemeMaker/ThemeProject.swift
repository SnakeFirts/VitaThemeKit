import SwiftUI
import AppKit
import VitaThemeKit

/// Una página de fondo (bgN.png + bgtN.png): su imagen, su encuadre y su estilo.
struct PageDraft: Identifiable {
    let id = UUID()
    var sourceURL: URL
    var proxy: CGImage            // versión reducida, solo para la vista previa
    var originalSize: CGSize
    var zoom: Double = 1
    var focus = CGPoint(x: 0.5, y: 0.5)
    var style = ThemePage()       // color de fuente y sombra (de VitaThemeKit)

    var framing: Framing { Framing(mode: .cover, zoom: zoom, focus: focus) }
    var proxySize: CGSize { CGSize(width: proxy.width, height: proxy.height) }
}

extension ThemeColor {
    var color: Color {
        Color(.sRGB,
              red: Double((argb >> 16) & 0xff) / 255,
              green: Double((argb >> 8) & 0xff) / 255,
              blue: Double(argb & 0xff) / 255,
              opacity: Double((argb >> 24) & 0xff) / 255)
    }

    init(color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        let a = UInt32((ns.alphaComponent * 255).rounded())
        let r = UInt32((ns.redComponent * 255).rounded())
        let g = UInt32((ns.greenComponent * 255).rounded())
        let b = UInt32((ns.blueComponent * 255).rounded())
        self.init(argb: a << 24 | r << 16 | g << 8 | b)
    }
}

@MainActor
final class ThemeProject: ObservableObject {
    static let pageSize = ThemeImageKind.background.pixelSize
    
    let lockpaper = LockpaperModel()
    let notices = NoticeModel()

    @Published var pages: [PageDraft] = []
    @Published var selection: UUID?
    @Published var isExporting = false
    @Published var status: String?
    
    // Datos del tema (pantalla inicial)
    @Published var name = ""
    @Published var version = "01.00"
    @Published var creator = ""
    @Published var setupDone = false

    // Colores y ajustes que van al XML
    @Published var colors = ThemeColors()
    @Published var dateLayout = DateLayout.bottomLeft.rawValue
    @Published var showClock = true
    @Published var clockColor = ThemeColor.white
    /// basePage.png y curPage.png (aún sin pantalla propia en la app).
    @Published var pageIndicators = false
    
    // Exportación del tema completo (carpeta + ZIP)
    @Published var isExportingTheme = false
    @Published var themeExportStatus: String?
    @Published var themeExportProblems: [String] = []
    @Published var lastExportedZip: URL?

    /// El tema completo, listo para pasarlo a ThemeXML.make cuando exportemos.
    var theme: Theme {
        // El reloj se oculta con transparencia total (alfa 00) en <m_dateColor>.
        var c = colors
        c.date = clockColor.withAlpha(showClock ? 0xff : 0x00)
        return Theme(info: ThemeInfo(title: name, provider: creator, contentVersion: version),
                     colors: c,
                     pages: pages.map(\.style),
                     dateLayout: dateLayout,
                     pageIndicators: pageIndicators)
    }

    // MARK: - Consultas

    var canAddPage: Bool { pages.count < Theme.maxPages }
    var remainingSlots: Int { Theme.maxPages - pages.count }

    func index(of id: UUID) -> Int? { pages.firstIndex { $0.id == id } }
    func page(_ id: UUID) -> PageDraft? { pages.first { $0.id == id } }
    var selectedPage: PageDraft? { selection.flatMap { page($0) } }

    func preview(for p: PageDraft) -> NSImage? {
        let r = FramingMath.coverCrop(source: p.proxySize, target: Self.pageSize, framing: p.framing)
        guard let cropped = p.proxy.cropping(to: r.integral) else { return nil }
        return NSImage(cgImage: cropped, size: .zero)
    }

    /// Mayor que 1 = la imagen se amplía respecto al original (pierde nitidez).
    func scaleFactor(for p: PageDraft) -> Double {
        let crop = FramingMath.coverCrop(source: p.originalSize, target: Self.pageSize, framing: p.framing)
        return Double(Self.pageSize.width / crop.width)
    }

    // MARK: - Agregar / quitar

    /// Devuelve una versión reducida (para la vista previa) y el tamaño real de la imagen.
    private static func loadSource(_ url: URL) throws -> (CGImage, CGSize) {
        let full = try ThemeImageRenderer.load(url: url)
        let size = CGSize(width: full.width, height: full.height)
        let proxy = (try? ThemeImageRenderer.load(url: url, maxPixelSize: 4096)) ?? full
        return (proxy, size)
    }

    func addPage(from url: URL) {
        guard canAddPage else { status = "Maximum \(Theme.maxPages) pages."; return }
        do {
            let (proxy, size) = try Self.loadSource(url)
            let p = PageDraft(sourceURL: url, proxy: proxy, originalSize: size)
            pages.append(p)
            selection = p.id
            status = nil
        } catch {
            status = "Could not open the image: \(error)"
        }
    }

    /// Reparte una imagen larga en varias páginas. Cada corte se convierte en una
    /// página normal (misma imagen, con su propio zoom y enfoque), así que luego
    /// se puede ajustar una por una.
    func addPanorama(from url: URL) {
        guard canAddPage else { status = "Maximum \(Theme.maxPages) pages."; return }
        do {
            let (proxy, size) = try Self.loadSource(url)
            let plan = FramingMath.panoramaPlan(source: size)
            let usable = Array(plan.pageCrops.prefix(remainingSlots))
            let page = Self.pageSize
            let base = max(page.width / size.width, page.height / size.height)

            var created: [PageDraft] = []
            for crop in usable {
                var p = PageDraft(sourceURL: url, proxy: proxy, originalSize: size)
                p.zoom = Framing.clampZoom(Double(page.width / (base * crop.width)))
                p.focus = CGPoint(x: crop.midX / size.width, y: crop.midY / size.height)
                created.append(p)
            }
            pages += created
            selection = created.first?.id
            status = plan.pageCrops.count > usable.count
                ? "The image yielded \(plan.pageCrops.count) pages; only \(usable.count) fit (maximum \(Theme.maxPages))."
                : nil
        } catch {
            status = "Could not open the image: \(error)"
        }
    }

    func remove(_ id: UUID) {
        guard let i = index(of: id) else { return }
        pages.remove(at: i)
        if selection == id { selection = pages.isEmpty ? nil : pages[min(i, pages.count - 1)].id }
    }

    func move(_ id: UUID, by offset: Int) {
        guard let i = index(of: id) else { return }
        let j = i + offset
        guard pages.indices.contains(j) else { return }
        pages.swapAt(i, j)
    }

    func update(_ id: UUID, _ change: (inout PageDraft) -> Void) {
        guard let i = index(of: id) else { return }
        change(&pages[i])
    }

    func resetFraming(_ id: UUID) {
        update(id) { $0.zoom = 1; $0.focus = CGPoint(x: 0.5, y: 0.5) }
    }

    // MARK: - Arrastrar el encuadre

    /// Centro real del recorte (0...1). Evita "zonas muertas" al arrastrar.
    func actualCenter(_ id: UUID) -> CGPoint {
        guard let p = page(id) else { return CGPoint(x: 0.5, y: 0.5) }
        return FramingMath.actualCenter(source: p.proxySize, target: Self.pageSize, framing: p.framing)
    }

    func pan(_ id: UUID, from start: CGPoint, translation t: CGSize, displayed: CGSize) {
        guard let i = index(of: id), displayed.width > 0, displayed.height > 0 else { return }
        let p = pages[i]
        pages[i].focus = FramingMath.pannedFocus(from: start, translation: t, displayed: displayed,
                                                 source: p.proxySize, target: Self.pageSize,
                                                 framing: p.framing)
    }

    // MARK: - Exportar

    func exportBackgrounds(to dir: URL) {
        // La posición en la lista decide el número: la primera es bg1.
        let jobs = pages.map { (source: $0.sourceURL, framing: $0.framing) }
        guard !jobs.isEmpty else { return }
        isExporting = true
        status = nil
        Task.detached {
            do {
                try PageImages.writePages(jobs, to: dir)
                await MainActor.run {
                    self.status = "Done: \(jobs.count) pages in \(dir.lastPathComponent)"
                    self.isExporting = false
                }
            } catch {
                await MainActor.run {
                    self.status = "Error: \(error)"
                    self.isExporting = false
                }
            }
        }
    }
}
