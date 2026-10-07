import SwiftUI
import AppKit
import VitaThemeKit

/// Barra superior de la consola y aviso de la bolita.
/// Confirmado en ThemeBUILDER: "Bar Color" -> <m_barColor> y "Text Color" -> <m_indicatorColor>.
/// Probado en una Vita: <m_noticeFontColor> es el número del aviso y <m_noticeGlowColor>
/// el brillo, ambos al llegar una notificación.
struct ConsoleBarView: View {
    @ObservedObject var project: ThemeProject
    @ObservedObject private var notices: NoticeModel
    @State private var hasNotice = true

    private var accent: Color { AppSection.consoleBar.accent }

    init(project: ThemeProject) {
        _project = ObservedObject(wrappedValue: project)
        _notices = ObservedObject(wrappedValue: project.notices)
    }

    /// La página seleccionada en Fondos, o la primera. Si no hay ninguna, gris.
    private var backgroundImage: NSImage? {
        guard let page = project.selectedPage ?? project.pages.first else { return nil }
        return project.preview(for: page)
    }

    // Dos columnas: la pantalla y la imagen de la bolita a la izquierda, los controles a la
    // derecha. Así todo cabe sin scroll, incluso con la ventana al tamaño mínimo.
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    ConsolePreview(colors: project.colors,
                                   background: backgroundImage,
                                   showNotice: hasNotice,
                                   noticeImage: notices.thumb(hasNew: hasNotice))
                    bubbleImageCard
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 14) {
                    NoticeToggle(hasNotice: $hasNotice, accent: accent)
                    if project.pages.isEmpty {
                        Text("Add a background in Backgrounds to see it here.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.ink.opacity(0.5))
                    }
                    barCard
                    noticeCard
                }
                .frame(width: 280)
            }
        }
        .padding(.vertical, 16)
        .padding(.trailing, 20)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.light)
    }

    // MARK: Encabezado

    private var header: some View {
        SectionHeader(symbol: "xmark", label: "CONSOLE BAR",
                      title: "Bar & notices",
                      subtitle: "Bar color, text color and the notice bubble.",
                      accent: accent)
    }

    // MARK: Tarjetas

    private var barCard: some View {
        PanelCard("Bar", symbol: "triangle", tint: Color.psGreen) {
            ColorPicker("Bar color", selection: binding(\.bar), supportsOpacity: false)
            ColorPicker("Text color", selection: binding(\.indicator), supportsOpacity: false)
            Text("Covers the time, battery percentage and icons.")
                .font(.system(size: 11))
                .foregroundStyle(Color.ink.opacity(0.5))
            Button("Reset") {
                let d = ThemeColors()
                project.colors.bar = d.bar
                project.colors.indicator = d.indicator
            }
            .buttonStyle(PanelButtonStyle())
        }
    }

    private var noticeCard: some View {
        PanelCard("Bubble notice", symbol: "circle", tint: Color.psRed) {
            ColorPicker("Notice number", selection: binding(\.noticeFont), supportsOpacity: false)
            ColorPicker("Notice glow", selection: binding(\.noticeGlow), supportsOpacity: false)
            Text("These show when a notification arrives. The notifications panel doesn't change color.")
                .font(.system(size: 11))
                .foregroundStyle(Color.ink.opacity(0.5))
            Button("Reset") {
                let d = ThemeColors()
                project.colors.noticeFont = d.noticeFont
                project.colors.noticeGlow = d.noticeGlow
            }
            .buttonStyle(PanelButtonStyle())
        }
    }

    private var bubbleImageCard: some View {
        PanelCard("Bubble image", symbol: "square", tint: Color.psPink) {
            HStack(alignment: .top, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    NoticeSlot(title: "No notice", file: "notice.png",
                               hasNew: false, model: notices, accent: accent)
                    NoticeSlot(title: "New notice", file: "notices.png",
                               hasNew: true, model: notices, accent: accent)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("The console only shows the circle at the top right. Use each image's crop icon to adjust its framing.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ink.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                    if let status = notices.status {
                        Text(status)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.ink.opacity(0.7))
                    }
                    Button {
                        if let dir = Pickers.folder() { notices.export(to: dir) }
                    } label: {
                        Label("Export images", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PanelButtonStyle(tint: accent, filled: true))
                    .disabled(!notices.hasAny)
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<ThemeColors, ThemeColor>) -> Binding<Color> {
        Binding(
            get: { project.colors[keyPath: keyPath].color },
            set: { project.colors[keyPath: keyPath] = ThemeColor(color: $0) }
        )
    }
}

// MARK: - Slot de imagen de la bolita

private struct NoticeSlot: View {
    let title: String
    let file: String
    let hasNew: Bool
    @ObservedObject var model: NoticeModel
    let accent: Color
    @State private var targeted = false
    @State private var editing = false

    // Misma proporción que la imagen real (120×110).
    private let tileSize = CGSize(width: 96, height: 88)

    var body: some View {
        VStack(spacing: 6) {
            Button {
                if let url = Pickers.image() { model.set(hasNew: hasNew, url: url) }
            } label: {
                tile
            }
            .buttonStyle(.plain)
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
                handleFileDrop(providers) { model.set(hasNew: hasNew, url: $0) }
            }
            .overlay(alignment: .bottomTrailing) {
                if model.source(hasNew: hasNew) != nil { cropButton }
            }
            .contextMenu {
                if model.source(hasNew: hasNew) != nil {
                    Button("Adjust framing") { editing = true }
                    Button("Remove") { model.remove(hasNew: hasNew) }
                }
            }

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text(file)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color.ink.opacity(0.45))
        }
        .frame(width: tileSize.width)
        .sheet(isPresented: $editing) {
            NoticeFramingEditor(model: model, hasNew: hasNew)
        }
    }

    private var cropButton: some View {
        Button { editing = true } label: {
            Image(systemName: "crop")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.ink.opacity(0.78)))
        }
        .buttonStyle(.plain)
        .help("Adjust framing")
        .padding(5)
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        let border: Color = targeted ? accent : Color.ink.opacity(0.14)
        let stroke = StrokeStyle(lineWidth: targeted ? 2 : 1, dash: targeted ? [5, 4] : [])
        return ZStack {
            shape.fill(Color.ink.opacity(0.06))
            if let thumb = model.thumb(hasNew: hasNew) {
                Image(nsImage: thumb)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(accent)
            }
        }
        .frame(width: tileSize.width, height: tileSize.height)
        .overlay {
            if model.thumb(hasNew: hasNew) != nil {
                BubbleVisor()
                    .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(border, style: stroke))
    }
}

// MARK: - Con aviso / Sin aviso

private struct NoticeToggle: View {
    @Binding var hasNotice: Bool
    let accent: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        HStack(spacing: 0) {
            option("No notice", value: false)
            option("New notice", value: true)
        }
        .padding(2)
        .background(shape.fill(Color.white.opacity(0.9)))
        .overlay(shape.strokeBorder(Color.ink.opacity(0.14), lineWidth: 1))
    }

    private func option(_ title: String, value: Bool) -> some View {
        let selected = hasNotice == value
        return Button {
            hasNotice = value
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(selected ? Color.white : Color.ink.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(selected ? accent : Color.clear))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: selected)
    }
}
