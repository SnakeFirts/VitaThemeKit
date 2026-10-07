import SwiftUI
import VitaThemeKit

/// Pantalla de bloqueo: reloj (visibilidad, color y posición) con vista previa fiel a la consola.
struct LockScreenView: View {
    @ObservedObject var project: ThemeProject
    @ObservedObject private var lockpaper: LockpaperModel
    @State private var dropTargeted = false
    @State private var dragStart: CGPoint?
    @State private var zoomStart: Double?

    private let cardColumns = [GridItem(.adaptive(minimum: 300), spacing: 18)]

    private var accent: Color { AppSection.lockscreen.accent }

    init(project: ThemeProject) {
        _project = ObservedObject(wrappedValue: project)
        _lockpaper = ObservedObject(wrappedValue: project.lockpaper)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                preview
                if lockpaper.hasImage {
                    LockpaperZoomBar(model: lockpaper, tint: accent)
                        .frame(maxWidth: .infinity)
                }
                LazyVGrid(columns: cardColumns, alignment: .leading, spacing: 18) {
                    clockCard
                    paperCard
                }
                positionCard
            }
            .padding(.vertical, 16)
            .padding(.trailing, 16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.light)
    }

    // MARK: Encabezado

    private var header: some View {
        SectionHeader(symbol: "circle", label: "LOCKSCREEN",
                      title: "Clock, notification and background",
                      subtitle: "The notification moves on its own depending on the clock position.",
                      accent: accent)
    }

    // MARK: Vista previa

    private var previewShape: RoundedRectangle {
        // Radio moderado: con uno grande se recortaría el icono de Wi-Fi de la barra de estado.
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    private var preview: some View {
        let borderColor: Color = dropTargeted ? accent : Color.white.opacity(0.9)
        let stroke = StrokeStyle(lineWidth: dropTargeted ? 2 : 1,
                                 dash: dropTargeted ? [7, 6] : [])
        return Color.clear
            .aspectRatio(960.0 / 544.0, contentMode: .fit)
            .overlay { scaledScene }
            .clipShape(previewShape)
            .overlay(previewShape.strokeBorder(borderColor, style: stroke))
            .overlay(alignment: .bottomTrailing) {
                imageControls.padding(28)
            }
            // La sombra va en una forma aparte: así no se recalcula con la imagen al arrastrar.
            .background(previewShape.fill(Color.black)
                .shadow(color: accent.opacity(0.25), radius: 24, y: 14))
            .animation(.easeOut(duration: 0.15), value: dropTargeted)
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                handleFileDrop(providers) { url in
                    Task { @MainActor in lockpaper.setImage(from: url) }
                }
            }
    }

    /// Botones sobre la pantalla: sustituyen a "Elegir imagen…" / "Cambiar…" / "Quitar".
    private var imageControls: some View {
        HStack(spacing: 8) {
            if lockpaper.hasImage {
                PreviewIconButton(symbol: "trash", help: "Remove image",
                                  tint: Color.psRed) {
                    lockpaper.clear()
                }
            }
            PreviewIconButton(symbol: lockpaper.hasImage ? "arrow.triangle.2.circlepath" : "plus",
                              help: lockpaper.hasImage ? "Change image" : "Add background image",
                              tint: lockpaper.hasImage ? Color.white : accent,
                              light: !lockpaper.hasImage) {
                if let url = Pickers.image() { lockpaper.setImage(from: url) }
            }
        }
    }

    /// La escena se dibuja en 960×544 (pantalla real) y se escala al ancho disponible.
    private var scaledScene: some View {
        GeometryReader { geo in
            let s = geo.size.width / 960
            scene
                .frame(width: 960, height: 544)
                .scaleEffect(s, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(drag(width: geo.size.width),
                         including: lockpaper.hasImage ? .all : .none)
                .simultaneousGesture(magnify,
                                     including: lockpaper.hasImage ? .all : .none)
        }
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStart == nil { dragStart = lockpaper.center }
                lockpaper.pan(from: dragStart ?? CGPoint(x: 0.5, y: 0.5),
                              translation: value.translation,
                              displayedWidth: width)
            }
            .onEnded { _ in dragStart = nil }
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if zoomStart == nil { zoomStart = lockpaper.zoom }
                lockpaper.setZoom((zoomStart ?? 1) * Double(value))
            }
            .onEnded { _ in zoomStart = nil }
    }

    private var scene: some View {
        ZStack(alignment: .topLeading) {
            background
            glassFrame
            statusBar
        }
        .frame(width: 960, height: 544, alignment: .topLeading)
        .clipped()
    }

    // Fondo

    @ViewBuilder
    private var background: some View {
        if lockpaper.hasImage {
            LockpaperImage(model: lockpaper, size: CGSize(width: 960, height: 544))
        } else {
            defaultBackground
        }
    }

    private var defaultBackground: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.16), Color(white: 0.05)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0)],
                           center: .topTrailing, startRadius: 0, endRadius: 520)
            psWatermark
        }
        .frame(width: 960, height: 544)
    }

    private var psWatermark: some View {
        HStack(spacing: 22) {
            Image(systemName: "triangle")
            Image(systemName: "circle")
            Image(systemName: "xmark")
            Image(systemName: "square")
        }
        .font(.system(size: 120, weight: .ultraLight))
        .foregroundStyle(Color.white.opacity(0.09))
        .frame(width: 960, height: 544, alignment: .bottomTrailing)
        .offset(x: 30, y: 40)
    }

    // Barra de estado (compartida con Barra y avisos)

    private var statusBar: some View {
        VitaStatusBar(colors: project.colors, showsHome: false, trailingInset: 45)
    }

    // Marco de cristal (x 32, y 65, 896×446 en la pantalla real)

    private var glassFrame: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return ZStack {
            shape.fill(Color.white.opacity(0.04))
            shape.strokeBorder(Color.white.opacity(0.28), lineWidth: 1.5)
            notification
            if project.showClock { clock }
            peelCorner.clipShape(shape)
        }
        .frame(width: 896, height: 446)
        .offset(x: 32, y: 65)
    }
    
    // Layout
    
    private var layout: DateLayout {
        DateLayout(rawValue: project.dateLayout) ?? .bottomLeft
    }

    // Notificación (baja cuando el reloj va arriba a la izquierda)

    private var notification: some View {
        let c = project.colors
        let atBottom = layout == .topLeft
        let place: Alignment = atBottom ? .bottomLeading : .topLeading
        return VStack(alignment: .leading, spacing: 4) {
            Text("Notification").font(.system(size: 20, weight: .semibold))
            Text("Sample message").font(.system(size: 16))
        }
        .foregroundStyle(c.notifyFont.color)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(c.notifyBackground.color))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.notifyBorder.color))
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: place)
    }

    // Reloj

    private var clockAlignment: Alignment {
        switch layout {
        case .bottomLeft:  return .bottomLeading
        case .topLeft:     return .topLeading
        case .bottomRight: return .bottomTrailing
        }
    }

    private var clockHorizontal: HorizontalAlignment {
        layout == .bottomRight ? .trailing : .leading
    }

    private var clock: some View {
        TimelineView(.everyMinute) { tl in
            let t = ClockText(tl.date)
            VStack(alignment: clockHorizontal, spacing: -6) {
                Text(t.date)
                    .font(.system(size: 34, weight: .light))
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(t.time).font(.system(size: 124, weight: .light))
                    Text(t.ampm).font(.system(size: 44, weight: .semibold))
                }
            }
            .foregroundStyle(project.clockColor.color)
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: clockAlignment)
        }
    }

    // Esquina doblada (para desbloquear)

    private var peelCorner: some View {
        let blue = LinearGradient(
            colors: [Color(red: 0.02, green: 0.12, blue: 0.55),
                     Color(red: 0.05, green: 0.25, blue: 0.85)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        let flap = LinearGradient(
            colors: [Color.white, Color(white: 0.78)],
            startPoint: .topTrailing, endPoint: .bottomLeading)
        return ZStack {
            PeelBlue().fill(blue)
            PeelFlap()
                .fill(flap)
                .shadow(color: Color.black.opacity(0.35), radius: 3, x: -1, y: 2)
        }
        .frame(width: 102, height: 96)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    // MARK: Controles

    private var clockBinding: Binding<Color> {
        Binding(get: { project.clockColor.color },
                set: { project.clockColor = ThemeColor(color: $0) })
    }

    private var clockCard: some View {
        PanelCard("Clock", symbol: "triangle", tint: Color.psGreen) {
            Toggle("Show clock", isOn: $project.showClock)
                .toggleStyle(.switch)
                .tint(accent)
            ColorPicker("Clock color", selection: clockBinding, supportsOpacity: false)
                .disabled(!project.showClock)
        }
    }

    private var paperCard: some View {
        PanelCard("Background image", symbol: "xmark", tint: Color.psBlue) {
            Text("Exported as lockpaper.png (960 × 544). Add it with the + button on the screen, drag to move it and pinch to zoom.")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.ink.opacity(0.45))

            if let url = lockpaper.sourceURL {
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if lockpaper.upscaleFactor > 1.05 {
                    Label(String(format: "Upscaled ×%.2f: it may look less sharp.",
                                 lockpaper.upscaleFactor),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.orange)
                }
            }

            Button { exportLockpaper() } label: {
                Label("Export lockpaper.png", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ExportButtonStyle(accent: accent))
            .disabled(!lockpaper.hasImage)

            if let status = lockpaper.status {
                Text(status)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.ink.opacity(0.5))
            }
        }
    }

    private func exportLockpaper() {
        guard let dir = Pickers.folder() else { return }
        do {
            let url = try lockpaper.export(to: dir)
            lockpaper.status = "Saved: \(url.lastPathComponent)"
        } catch {
            lockpaper.status = "Could not export: \(error.localizedDescription)"
        }
    }

    private var positionCard: some View {
        PanelCard("Clock position", symbol: "square", tint: Color.psPink) {
            HStack(spacing: 12) {
                ForEach(DateLayout.allCases, id: \.rawValue) { l in
                    LayoutOption(layout: l, selected: project.dateLayout == l.rawValue, accent: accent) {
                        project.dateLayout = l.rawValue
                    }
                }
            }
            .disabled(!project.showClock)
            .opacity(project.showClock ? 1 : 0.4)
        }
    }
}

// MARK: - Botón de icono sobre la pantalla

private struct PreviewIconButton: View {
    let symbol: String
    let help: String
    var tint: Color = Color.white
    var light: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) { face }
            .buttonStyle(.plain)
            .help(help)
    }

    @ViewBuilder
    private var face: some View {
        let icon = Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)

        if light {
            let shape = RoundedRectangle(cornerRadius: AppStyle.radius + 2, style: .continuous)
            icon
                .background(shape.fill(Color.white.opacity(0.92)))
                .overlay(shape.strokeBorder(Color.white, lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        } else {
            icon.overlayGlass()
        }
    }
}

// MARK: - Opción de posición (mini pantalla)

private struct LayoutOption: View {
    let layout: DateLayout
    let selected: Bool
    let accent: Color
    let action: () -> Void

    @State private var hovering = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }

    private var markAlignment: Alignment {
        switch layout {
        case .bottomLeft:  return .bottomLeading
        case .topLeft:     return .topLeading
        case .bottomRight: return .bottomTrailing
        }
    }

    private var markHorizontal: HorizontalAlignment {
        layout == .bottomRight ? .trailing : .leading
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                miniScreen
                Text(layout.title)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Color.ink : Color.ink.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var miniScreen: some View {
        let ring: Color = selected ? accent : Color.white.opacity(0.8)
        return shape
            .fill(Color(white: 0.13))
            .frame(height: 64)
            .overlay(alignment: markAlignment) { clockMark }
            .overlay(shape.strokeBorder(ring, lineWidth: selected ? 2.5 : 1.5))
            .shadow(color: accent.opacity(selected ? 0.3 : 0), radius: 8, y: 3)
            .scaleEffect(hovering ? 1.03 : 1)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .animation(.easeOut(duration: 0.15), value: selected)
    }

    private var clockMark: some View {
        VStack(alignment: markHorizontal, spacing: 3) {
            Capsule().fill(Color.white.opacity(0.6)).frame(width: 22, height: 3)
            Capsule().fill(Color.white).frame(width: 34, height: 9)
        }
        .padding(9)
    }
}

// MARK: - Esquina doblada

private struct PeelBlue: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 102
        let sy = rect.height / 96
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var p = Path()
        // Llega hasta la esquina: el redondeo lo da el recorte del marco de cristal.
        p.move(to: pt(0, 0))
        p.addLine(to: pt(102, 0))
        p.addLine(to: pt(102, 92))
        p.closeSubpath()
        return p
    }
}

private struct PeelFlap: Shape {
    /// Mismo radio que el marco de cristal (14): es su propia esquina, doblada.
    var radius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 102
        let sy = rect.height / 96
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        let top = pt(0, 0)            // donde el doblez toca el borde de arriba
        let right = pt(102, 92)       // donde el doblez toca el borde derecho
        let corner = pt(10.5, 101.5)  // la esquina del marco reflejada sobre el doblez

        var p = Path()
        p.move(to: top)
        p.addLine(to: right)
        p.addArc(tangent1End: corner, tangent2End: top, radius: radius * min(sx, sy))
        p.closeSubpath()
        return p
    }
}
