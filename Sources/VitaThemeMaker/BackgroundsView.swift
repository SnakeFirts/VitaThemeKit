import SwiftUI
import VitaThemeKit

struct BackgroundsView: View {
    @ObservedObject var project: ThemeProject
    @State private var dropTargeted = false
    /// Páginas quitadas (con su posición) para poder deshacer con ⌘Z.
    @State private var removed: [(page: PageDraft, index: Int)] = []
    @State private var undoMessage: String?

    private var accent: Color { AppSection.backgrounds.accent }

    private var pageRatio: CGFloat {
        ThemeProject.pageSize.width / ThemeProject.pageSize.height
    }

    /// El lienzo grande conserva sus esquinas redondeadas; lo demás es más recto.
    private var canvasShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    private var hasImage: Bool {
        guard let id = project.selection else { return false }
        return project.page(id) != nil
    }

    var body: some View {
        Group {
            if hasImage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        canvasArea
                        toolbar
                        messages
                    }
                    .padding(.vertical, 16)
                    .padding(.trailing, 16)
                }
                .scrollIndicators(.never)
            } else {
                // Sin imagen: la zona para soltar ocupa todo el alto y no hay barra de herramientas.
                VStack(alignment: .leading, spacing: 14) {
                    canvasArea
                    messages
                }
                .padding(.vertical, 16)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(undoShortcut)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var messages: some View {
        if let message = undoMessage {
            HStack(spacing: 10) {
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.ink.opacity(0.6))
                Button("Undo") { undoRemove() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
        if let status = project.status {
            Text(status)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.ink.opacity(0.5))
        }
    }

    // MARK: Lienzo

    private var canvasBorderColor: Color {
        if dropTargeted { return accent }
        return hasImage ? Color.white.opacity(0.55) : Color.ink.opacity(0.10)
    }

    private var canvasStroke: StrokeStyle {
        let dashed = !hasImage || dropTargeted
        let dash: [CGFloat] = dashed ? [7, 6] : []
        let width: CGFloat = dropTargeted ? 2 : 1
        return StrokeStyle(lineWidth: width, dash: dash)
    }

    private var canvasArea: some View {
        Group {
            if hasImage {
                Color.clear.aspectRatio(pageRatio, contentMode: .fit)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay { canvasContent }
        .overlay { chrome }
        .clipShape(canvasShape)
        .overlay(
            canvasShape.strokeBorder(
                canvasBorderColor,
                style: canvasStroke
            )
        )
        .background(
            canvasShape
                .fill(Color.white.opacity(hasImage ? 1 : 0.45))
                .shadow(
                    color: accent.opacity(0.22),
                    radius: 28,
                    y: 14
                )
        )
        .animation(.easeOut(duration: 0.15), value: dropTargeted)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            handleFileDrop(providers) {
                project.addPage(from: $0)
            }
        }
    }
    
    @ViewBuilder
    private var canvasContent: some View {
        if let id = project.selection, project.page(id) != nil {
            FramingCanvas(project: project, pageID: id)
        } else {
            emptyState
        }
    }

    // Todo lo que flota sobre la imagen: avisos (solo icono), zoom y tira de páginas.

    @ViewBuilder
    private var chrome: some View {
        if hasImage, let page = project.selectedPage, let index = project.index(of: page.id) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        InfoChip(symbol: "info.circle",
                                 tint: Color.white,
                                 message: "Drag to move · Pinch to zoom · Double-click to reset")
                        scaleBadge(page)
                        Spacer()
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        OverlayIconButton(symbol: "arrow.left", help: "Move page back") {
                            project.move(page.id, by: -1)
                        }
                        .disabled(index == 0)
                        ZoomBar(project: project, page: page)
                        OverlayIconButton(symbol: "arrow.right", help: "Move page forward") {
                            project.move(page.id, by: 1)
                        }
                        .disabled(index == project.pages.count - 1)
                    }
                }
                // El margen inferior evita que la tira llegue hasta la barra de zoom.
                PageStrip(project: project)
                    .padding(.bottom, 56)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func scaleBadge(_ page: PageDraft) -> some View {
        let factor = project.scaleFactor(for: page)
        if factor > 1.05 {
            InfoChip(symbol: "exclamationmark.triangle.fill",
                     tint: Color.orange,
                     message: String(format: "Enlarged ×%.2f · will look less sharp", factor))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                AppStyle.shape.fill(accent.opacity(0.14))
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(accent)
            }
            .frame(width: 64, height: 64)

            VStack(spacing: 4) {
                Text("Drop an image here")
                    .font(AppStyle.title(22))
                    .foregroundStyle(Color.ink)
                Text("or add one from your Mac · up to \(Theme.maxPages) pages")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.ink.opacity(0.5))
            }

            HStack(spacing: 10) {
                Button("Add image…") {
                    if let url = Pickers.image() { project.addPage(from: url) }
                }
                .buttonStyle(FlatButtonStyle(tint: accent, darken: 0.15))

                Button("Import panorama…") {
                    if let url = Pickers.image() { project.addPanorama(from: url) }
                }
                .buttonStyle(FlatButtonStyle(prominent: false, tint: accent, darken: 0.15))
            }
        }
    }

    // MARK: Barra de herramientas (solo iconos; el clic despliega las opciones)

    private var toolbar: some View {
        HStack(spacing: 10) {
            if let page = project.selectedPage,
               let index = project.index(of: page.id) {

                PanelCard(
                    "Page tools",
                    symbol: "slider.horizontal.3",
                    tint: accent
                ) {
                    HStack(spacing: 14) {
                        ToolButton(
                            symbol: "photo.on.rectangle",
                            tooltip: "Page \(index + 1) of \(project.pages.count) info",
                            accent: accent
                        ) {
                            pageContent(page: page, index: index)
                        }

                        ToolButton(
                            symbol: "textformat",
                            tooltip: "Menu text",
                            accent: accent
                        ) {
                            textContent(page: page)
                        }

                        ToolButton(
                            symbol: "water.waves",
                            tooltip: "Wave (wave color)",
                            accent: accent
                        ) {
                            waveContent(page: page)
                        }

                        SquareIconButton(
                            symbol: "trash",
                            tooltip: "Remove page (⌫)",
                            tint: Color.psRed
                        ) {
                            removeSelected()
                        }
                        .keyboardShortcut(.delete, modifiers: [])
                    }
                }
            }

            Spacer()

            exportButton
        }
    }

    private var exportButton: some View {
        Button {
            if let dir = Pickers.folder() { project.exportBackgrounds(to: dir) }
        } label: {
            HStack(spacing: 8) {
                if project.isExporting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "square.and.arrow.down")
                }
                Text("Export backgrounds")
            }
        }
        .buttonStyle(ExportButtonStyle(accent: accent))
        .disabled(project.pages.isEmpty || project.isExporting)
    }

    // MARK: Contenido de cada opción

    private func popoverTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(Color.ink.opacity(0.45))
    }

    private func pageContent(page: PageDraft, index: Int) -> some View {
        let w = Int(page.originalSize.width)
        let h = Int(page.originalSize.height)
        return VStack(alignment: .leading, spacing: 14) {
            popoverTitle("Page \(index + 1) of \(project.pages.count)")
            VStack(alignment: .leading, spacing: 4) {
                Text(page.sourceURL.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(w) × \(h) px")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.ink.opacity(0.45))
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.ink)
    }

    private func textContent(page: PageDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            popoverTitle("Menu text")
            ColorPicker("Font color", selection: fontColor(page))
            Toggle("Shadow", isOn: binding(page, \.style.fontShadow))
                .toggleStyle(.switch)
                .tint(accent)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.ink)
    }

    private func waveContent(page: PageDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            popoverTitle("Wave (wave color)")
            WavePicker(selection: binding(page, \.style.waveType))
            Text("On the console's picker the boxes appear in a different order; here the number is the actual XML value.")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.ink.opacity(0.45))
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.ink)
    }

    // MARK: Quitar y deshacer

    private func removeSelected() {
        guard let id = project.selection,
              let index = project.index(of: id),
              let page = project.page(id) else { return }
        removed.append((page: page, index: index))
        project.remove(id)
        undoMessage = "Page \(index + 1) removed"
    }

    private func undoRemove() {
        guard let last = removed.popLast() else { return }
        guard project.canAddPage else {
            removed.append(last)
            return
        }
        project.pages.insert(last.page, at: min(last.index, project.pages.count))
        project.selection = last.page.id
        undoMessage = removed.isEmpty ? nil : "Page \(removed.last!.index + 1) removed"
    }

    /// ⌘Z, sin botón visible.
    private var undoShortcut: some View {
        Button("Undo page removal") { undoRemove() }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(removed.isEmpty)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    // MARK: Bindings

    private func binding<T>(_ page: PageDraft, _ keyPath: WritableKeyPath<PageDraft, T>) -> Binding<T> {
        Binding(
            get: { project.page(page.id)?[keyPath: keyPath] ?? page[keyPath: keyPath] },
            set: { value in project.update(page.id) { $0[keyPath: keyPath] = value } }
        )
    }

    private func fontColor(_ page: PageDraft) -> Binding<Color> {
        Binding(
            get: { (project.page(page.id)?.style.fontColor ?? page.style.fontColor).color },
            set: { value in project.update(page.id) { $0.style.fontColor = ThemeColor(color: value) } }
        )
    }
}

// MARK: - Botón de herramienta con desplegable

private struct ToolButton<Content: View>: View {
    let symbol: String
    let tooltip: String
    let accent: Color
    var width: CGFloat = 300
    @ViewBuilder var content: () -> Content

    @State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
            ZStack {
                AppStyle.shape.fill(open ? accent : Color.white.opacity(0.85))
                AppStyle.shape.strokeBorder(open ? Color.clear : Color.ink.opacity(0.10), lineWidth: 1)
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(open ? Color.white : accent)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            content()
                .padding(16)
                .frame(width: width)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Botón de icono cuadrado (claro, para la barra de herramientas)

private struct SquareIconButton: View {
    let symbol: String
    let tooltip: String
    let tint: Color
    let action: () -> Void

    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            ZStack {
                AppStyle.shape.fill(Color.white.opacity(0.85))
                AppStyle.shape.strokeBorder(Color.ink.opacity(0.10), lineWidth: 1)
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

// MARK: - Botón de icono plano sobre la imagen (oscuro)

private struct OverlayIconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 42, height: 42)
                .overlayGlass()
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Aviso de solo icono sobre la imagen

/// Icono plano; al pulsarlo (o dejar el cursor encima) muestra el mensaje.
private struct InfoChip: View {
    let symbol: String
    let tint: Color
    let message: String

    @State private var open = false
    @State private var hovering = false

    var body: some View {
        Button { open.toggle() } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .overlayGlass(radius: 17)
                .scaleEffect(hovering ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .help(message)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(width: 240, alignment: .leading)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Barra de zoom flotante (plana)

struct ZoomBar: View {
    @ObservedObject var project: ThemeProject
    let page: PageDraft

    private var zoom: Double { page.zoom }

    private func setZoom(_ value: Double) {
        project.update(page.id) { $0.zoom = Framing.clampZoom(value) }
    }

    private var zoomBinding: Binding<Double> {
        Binding(get: { zoom }, set: { setZoom($0) })
    }

    var body: some View {
        HStack(spacing: 10) {
            step("minus", shortcut: "-") { setZoom(zoom - 0.5) }
                .disabled(zoom <= Framing.zoomRange.lowerBound)

            Slider(value: zoomBinding, in: Framing.zoomRange)
                .tint(Color.white)
                .controlSize(.small)
                .frame(width: 150)

            step("plus", shortcut: "+") { setZoom(zoom + 0.5) }
                .disabled(zoom >= Framing.zoomRange.upperBound)

            Text(String(format: "%.1f×", zoom))
                .monospacedDigit()
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 42)

            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 1, height: 18)

            Button { project.resetFraming(page.id) } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("0", modifiers: .command)
            .help("Reset framing")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlayGlass()
    }

    private func step(_ icon: String, shortcut: KeyEquivalent,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut, modifiers: .command)
    }
}

// MARK: - Guías de tercios

private struct ThirdsGuide: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in 1...2 {
            let f = CGFloat(i) / 3
            let x = rect.minX + rect.width * f
            let y = rect.minY + rect.height * f
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }
}

// MARK: - Tira de páginas (vertical, sobre el borde derecho del lienzo)

struct PageStrip: View {
    @ObservedObject var project: ThemeProject
    
    @State private var addHover = false

    private let thumbSize = CGSize(width: 96, height: 51)
    private let gap: CGFloat = 8
    private let inset: CGFloat = 8

    private var accent: Color { AppSection.backgrounds.accent }

    /// Alto de todo el contenido: así la tira solo ocupa lo que necesita.
    private var contentHeight: CGFloat {
        let items = CGFloat(project.pages.count + 1)   // páginas + botón de añadir
        return inset * 2 + items * thumbSize.height + (items - 1) * gap
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: gap) {
                ForEach(Array(project.pages.enumerated()), id: \.element.id) { index, page in
                    PageThumb(page: page, index: index,
                              selected: project.selection == page.id,
                              accent: accent, size: thumbSize) {
                        project.selection = page.id
                    }
                    .equatable()
                }
                addButton
            }
            .padding(inset)
        }
        .scrollIndicators(.never)
        .frame(width: thumbSize.width + inset * 2)
        .frame(maxHeight: contentHeight)
        .overlayGlass(radius: 12)
    }
    
    // MARK: Botones de Añadir

    private var addButton: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        return Menu {
            Button("Add image…") {
                if let url = Pickers.image() { project.addPage(from: url) }
            }
            Button("Import panorama…") {
                if let url = Pickers.image() { project.addPanorama(from: url) }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                Text("\(project.pages.count)/\(Theme.maxPages)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .frame(width: thumbSize.width, height: thumbSize.height)
            .background(shape.fill(accent.opacity(addHover ? 0.30 : 0.18)))
            .overlay(
                shape.strokeBorder(accent.opacity(addHover ? 1 : 0.8),
                                   style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
            )
            .contentShape(shape)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: thumbSize.width, height: thumbSize.height)
        .onHover { addHover = $0 }
        .animation(.easeOut(duration: 0.12), value: addHover)
        .disabled(!project.canAddPage)
        .opacity(project.canAddPage ? 1 : 0.4)
    }
}

// MARK: - Lienzo con arrastre y pellizco

/// Rellena todo el espacio que le da el padre (que ya tiene la proporción de la consola).
struct FramingCanvas: View {
    @ObservedObject var project: ThemeProject
    let pageID: UUID

    @State private var dragStart: CGPoint?
    @State private var zoomStart: Double?
    @State private var interacting = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let page = project.page(pageID) {
                    PageImageView(page: page, size: geo.size)
                        .contentShape(Rectangle())
                        .gesture(drag(size: geo.size))
                        .simultaneousGesture(magnify)
                        .simultaneousGesture(doubleTap)
                    guides
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var guides: some View {
        ThirdsGuide()
            .stroke(Color.white.opacity(0.65), lineWidth: 1)
            .shadow(color: Color.black.opacity(0.3), radius: 1)
            .opacity(interacting ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: interacting)
            .allowsHitTesting(false)
    }

    private func drag(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStart == nil { dragStart = project.actualCenter(pageID) }
                interacting = true
                project.pan(pageID,
                            from: dragStart ?? CGPoint(x: 0.5, y: 0.5),
                            translation: value.translation,
                            displayed: size)
            }
            .onEnded { _ in
                dragStart = nil
                interacting = false
            }
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if zoomStart == nil {
                    zoomStart = project.page(pageID)?.zoom
                }
                guard let start = zoomStart else { return }
                interacting = true
                project.update(pageID) { $0.zoom = Framing.clampZoom(start * Double(value)) }
            }
            .onEnded { _ in
                zoomStart = nil
                interacting = false
            }
    }

    private var doubleTap: some Gesture {
        TapGesture(count: 2).onEnded { project.resetFraming(pageID) }
    }
}
