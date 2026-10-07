import SwiftUI
import AppKit
import VitaThemeKit

@MainActor
final class IconsModel: ObservableObject {
    static let all = ThemeIcons.all

    /// Un icono asignado: el archivo original y su miniatura.
    /// Todo en un solo valor, así cada cambio publica una sola vez.
    struct Item {
        let url: URL
        let thumb: NSImage
    }

    @Published private(set) var items: [String: Item] = [:]
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var status: String?

    /// Lo que usan las demás pantallas (Inicio y exportación del tema).
    var sources: [String: URL] { items.mapValues(\.url) }

    // MARK: - Decodificar fuera del hilo principal

    /// Resultado de decodificar un icono (CGImage es inmutable, es seguro pasarlo entre hilos).
    private struct Loaded: @unchecked Sendable {
        let name: String
        let url: URL
        let image: CGImage
    }

    /// Lee una versión reducida (512 px) de la imagen y la deja en 128x128.
    /// El archivo original solo se vuelve a leer al exportar.
    nonisolated private static func decode(name: String, url: URL) -> Loaded? {
        guard let base = try? ThemeImageRenderer.load(url: url, maxPixelSize: 512),
              let out = try? ThemeImageRenderer.render(base, kind: .icon, framing: .default)
        else { return nil }
        return Loaded(name: name, url: url, image: out)
    }

    private func apply(_ loaded: [Loaded]) {
        var next = items
        for l in loaded {
            next[l.name] = Item(url: l.url, thumb: NSImage(cgImage: l.image, size: .zero))
        }
        items = next   // una sola publicación para todo el lote
    }

    // MARK: - Asignar

    /// Un solo slot (clic o soltar una imagen encima), sin mirar el nombre del archivo.
    func set(_ name: String, url: URL) {
        Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                IconsModel.decode(name: name, url: url)
            }.value
            if let loaded {
                apply([loaded])
                status = nil
            } else {
                status = "Couldn't open the image: \(url.lastPathComponent)"
            }
        }
    }

    func remove(_ name: String) {
        guard items[name] != nil else { return }
        items[name] = nil
    }

    // MARK: - Importar por nombre

    /// "icon_web.png", "Icon_Web.PNG", "icon-web.png" y "web.png" -> "web".
    static func specName(forFileName file: String) -> String? {
        var base = (file as NSString).deletingPathExtension.lowercased()
        for prefix in ["icon_", "icon-", "icon "] where base.hasPrefix(prefix) {
            base = String(base.dropFirst(prefix.count))
            break
        }
        return all.first { $0.name == base }?.name
    }

    /// Acepta carpetas y archivos sueltos. Cada archivo se asigna al slot que
    /// corresponda a su nombre; lo que no sea un icono se ignora.
    /// Los iconos se decodifican en paralelo, fuera del hilo principal.
    func importIcons(from urls: [URL]) {
        var files: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let inside = (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                files.append(contentsOf: inside)
            } else {
                files.append(url)
            }
        }

        // Un archivo por slot (si hay dos para el mismo, gana el último).
        var jobs: [String: URL] = [:]
        var ignored = 0
        for file in files {
            if let name = Self.specName(forFileName: file.lastPathComponent) {
                jobs[name] = file
            } else {
                ignored += 1
            }
        }

        guard !jobs.isEmpty else {
            status = "No icons named icon_<name>.png found in your selection."
            return
        }

        isImporting = true
        status = "Importing…"
        let work = jobs
        let ignoredCount = ignored

        Task {
            let outcome = await withTaskGroup(of: (URL, Loaded?).self,
                                              returning: ([Loaded], [String]).self) { group in
                for (name, url) in work {
                    group.addTask { (url, IconsModel.decode(name: name, url: url)) }
                }
                var ok: [Loaded] = []
                var bad: [String] = []
                for await (url, loaded) in group {
                    if let loaded { ok.append(loaded) } else { bad.append(url.lastPathComponent) }
                }
                return (ok, bad)
            }

            apply(outcome.0)
            isImporting = false

            if outcome.0.isEmpty {
                status = "No icons named icon_<name>.png found in your selection."
                    + (outcome.1.isEmpty ? "" : " Couldn't open: \(outcome.1.sorted().joined(separator: ", ")).")
                return
            }
            var msg = "Imported \(outcome.0.count) of \(Self.all.count) icons"
            if ignoredCount > 0 { msg += " · \(ignoredCount) files ignored" }
            if !outcome.1.isEmpty { msg += " · couldn't open: \(outcome.1.sorted().joined(separator: ", "))" }
            status = msg
        }
    }

    // MARK: - Exportar

    func export(to dir: URL) {
        let jobs = sources
        isExporting = true
        status = nil
        Task.detached {
            do {
                for (name, url) in jobs {
                    try PageImages.writeIcon(name: name, source: url, to: dir)
                }
                await MainActor.run {
                    self.status = "Done: \(jobs.count) icons in \(dir.lastPathComponent)"
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

// MARK: - Pantalla

struct IconsView: View {
    @ObservedObject var model: IconsModel
    @State private var dropTargeted = false

    private var accent: Color { AppSection.icons.accent }

    private let columns = [GridItem(.adaptive(minimum: 112, maximum: 150), spacing: 20, alignment: .top)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                actions
                if let status = model.status {
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ink.opacity(0.6))
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                    ForEach(IconsModel.all) { spec in
                        IconSlot(
                            spec: spec,
                            thumb: model.items[spec.name]?.thumb,
                            accent: accent,
                            onPick: {
                                if let url = Pickers.image() { model.set(spec.name, url: url) }
                            },
                            onDropFile: { model.set(spec.name, url: $0) },
                            onRemove: { model.remove(spec.name) }
                        )
                        .equatable()
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.trailing, 16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.never)
        .preferredColorScheme(.light)
        .dropDestination(for: URL.self) { urls, _ in
            model.importIcons(from: urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            dropTargeted = targeted
        }
        .overlay { if dropTargeted { dropHint } }
    }

    // MARK: Encabezado

    private var header: some View {
        SectionHeader(symbol: "square", label: "ICONS",
                      title: "App icons",
                      subtitle: "\(model.items.count) of \(IconsModel.all.count) assigned. Import a folder with icon_<name>.png files and they're assigned automatically.",
                      accent: accent)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                let urls = Pickers.iconSources()
                if !urls.isEmpty { model.importIcons(from: urls) }
            } label: {
                Label("Import", systemImage: "square.and.arrow.down.on.square")
            }
            .buttonStyle(FlatButtonStyle(prominent: true, tint: accent, darken: 0.15))
            .disabled(model.isImporting)

            Button {
                if let dir = Pickers.folder() { model.export(to: dir) }
            } label: {
                Label("Export icons", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(FlatButtonStyle(prominent: false, tint: accent, darken: 0.15))
            .disabled(model.items.isEmpty || model.isExporting)

            if model.isExporting || model.isImporting { ProgressView().controlSize(.small) }
        }
    }

    private var dropHint: some View {
        AppStyle.shape
            .fill(accent.opacity(0.08))
            .overlay(AppStyle.shape.strokeBorder(accent, style: StrokeStyle(lineWidth: 2, dash: [8, 6])))
            .overlay(
                Text("Drop the folder or icons here")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
            )
            .padding(8)
            .allowsHitTesting(false)
    }
}

// MARK: - Slot

/// Solo el icono y su nombre, sin tarjeta. Recibe únicamente lo suyo (no el modelo entero)
/// y es `Equatable`: al cambiar un icono, los otros 16 no se vuelven a dibujar.
struct IconSlot: View, Equatable {
    let spec: ThemeIcon
    let thumb: NSImage?
    let accent: Color
    let onPick: () -> Void
    let onDropFile: (URL) -> Void
    let onRemove: () -> Void

    @State private var targeted = false
    @State private var hovering = false

    static func == (lhs: IconSlot, rhs: IconSlot) -> Bool {
        lhs.spec.name == rhs.spec.name && lhs.thumb === rhs.thumb
    }

    var body: some View {
        VStack(spacing: 8) {
            tile
            Text(spec.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .help("icon_\(spec.name).png")
        .onHover { hovering = $0 }
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            handleFileDrop(providers) { onDropFile($0) }
        }
        .contextMenu {
            if thumb != nil { Button("Remove", action: onRemove) }
        }
    }

    private var borderColor: Color {
        if targeted || hovering { return accent }
        return thumb == nil ? accent.opacity(0.45) : Color.ink.opacity(0.10)
    }

    private var tile: some View {
        Button(action: onPick) {
            ZStack {
                // Superficie opaca: no obliga a mezclar con el fondo animado al hacer scroll.
                AppStyle.shape.fill(Color.white)
                if let thumb {
                    Image(nsImage: thumb)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(accent)
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(AppStyle.shape)
            .overlay(
                AppStyle.shape.strokeBorder(
                    borderColor,
                    style: StrokeStyle(lineWidth: (targeted || hovering) ? 2 : 1,
                                       dash: thumb == nil ? [5, 4] : [])
                )
            )
            .overlay(alignment: .topTrailing) {
                if thumb != nil && hovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color.white)
                            .frame(width: 20, height: 20)
                            .background(Rectangle().fill(Color.ink.opacity(0.78)))
                    }
                    .buttonStyle(.plain)
                    .padding(5)
                    .help("Remove")
                }
            }
        }
        .buttonStyle(.plain)
    }
}
