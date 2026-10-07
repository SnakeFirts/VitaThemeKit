import SwiftUI
import AppKit
import VitaThemeKit

// MARK: - Zona visible de la bolita

/// Parte de la imagen 120×110 que la consola llega a mostrar:
/// el círculo (⌀89) recortado por el borde derecho y el superior de la pantalla.
/// Sin Path.intersection (es de macOS 14): se dibuja como polígono y se recorta cada vértice.
struct BubbleVisibleArea: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 120
        let cx: CGFloat = 87.2
        let cy: CGFloat = 22.6
        let r: CGFloat = 44.5
        let maxX: CGFloat = 111   // borde derecho de la pantalla (x = 960)
        let minY: CGFloat = 8     // borde superior de la pantalla (y = 0)

        var p = Path()
        let steps = 90
        for i in 0..<steps {
            let a = Double(i) / Double(steps) * 2 * Double.pi
            let x = min(cx + r * CGFloat(cos(a)), maxX)
            let y = max(cy + r * CGFloat(sin(a)), minY)
            let pt = CGPoint(x: x * s, y: y * s)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Lo contrario: todo lo que NO se ve. Usar con FillStyle(eoFill: true).
struct BubbleVisor: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(rect)
        p.addPath(BubbleVisibleArea().path(in: rect))
        return p
    }
}

// MARK: - Editor

struct NoticeFramingEditor: View {
    @ObservedObject var model: NoticeModel
    let hasNew: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var dragStart: CGPoint?

    private let canvasSize = CGSize(width: 360, height: 330)   // 3× de 120×110

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(hasNew ? "With notice · notices.png" : "No notice · notice.png")
                    .font(AppStyle.title(20))
                    .foregroundStyle(Color.ink)
                Text("Drag the image to move it. The darkened area is not visible on the console.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ink.opacity(0.5))
            }

            canvas
            zoomRow

            HStack {
                Button("Reset") { model.resetFraming(hasNew: hasNew) }
                    .buttonStyle(PanelButtonStyle())
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(PanelButtonStyle(tint: AppSection.consoleBar.accent, filled: true))
            }
        }
        .padding(24)
        .frame(width: canvasSize.width + 48)
        .preferredColorScheme(.light)
    }

    private var canvas: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        return ZStack {
            Color.black
            if let img = model.editorImage(hasNew: hasNew, width: canvasSize.width) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
            }
            BubbleVisor()
                .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)
            BubbleVisibleArea()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .allowsHitTesting(false)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.ink.opacity(0.14), lineWidth: 1))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStart == nil { dragStart = model.actualCenter(hasNew: hasNew) }
                    model.pan(hasNew: hasNew,
                              from: dragStart ?? CGPoint(x: 0.5, y: 0.5),
                              translation: value.translation,
                              displayed: canvasSize)
                }
                .onEnded { _ in dragStart = nil }
        )
    }

    private var zoomRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "minus.magnifyingglass")
                .foregroundStyle(Color.ink.opacity(0.5))
            Slider(value: zoomBinding, in: Framing.zoomRange)
                .tint(AppSection.consoleBar.accent)
            Image(systemName: "plus.magnifyingglass")
                .foregroundStyle(Color.ink.opacity(0.5))
            Text(String(format: "%.1f×", zoomBinding.wrappedValue))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.ink)
    }

    private var zoomBinding: Binding<Double> {
        Binding(
            get: { model.framing(hasNew: hasNew)?.zoom ?? 1 },
            set: { model.setZoom($0, hasNew: hasNew) }
        )
    }
}
