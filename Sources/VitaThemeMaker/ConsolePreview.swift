import SwiftUI
import AppKit
import VitaThemeKit

/// Barra superior y bolita de avisos con las medidas de una Vita real.
/// Todas las coordenadas son de la pantalla de 960×544 y salen de medir capturas de la consola.
struct ConsolePreview: View {
    let colors: ThemeColors
    var background: NSImage? = nil
    var showNotice: Bool = false
    var noticeImage: NSImage? = nil

    private enum Metrics {
        static let barHeight: CGFloat = 32
        static let bubbleCenter = CGPoint(x: 936.2, y: 14.6)
        static let bubbleDiameter: CGFloat = 89
        /// Esquina superior izquierda de la imagen 120×110 de la bolita.
        static let imageOrigin = CGPoint(x: 849, y: -8)
        static let imageSize = CGSize(width: 120, height: 110)
    }

    var body: some View {
        content
    }

    private var content: some View {
        Color.clear
            .aspectRatio(960.0 / 544.0, contentMode: .fit)
            .overlay { scaledScene }
            .clipped()
            .overlay(Rectangle().strokeBorder(Color.white.opacity(0.9), lineWidth: 2))
            .shadow(color: Color.blueDeep.opacity(0.22), radius: 30, y: 16)
    }

    private var scaledScene: some View {
        GeometryReader { geo in
            let s = geo.size.width / 960
            scene
                .frame(width: 960, height: 544)
                .scaleEffect(s, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    private var scene: some View {
        ZStack {
            backdrop
            VitaStatusBar(colors: colors)
                .position(x: 480, y: Metrics.barHeight / 2)
            noticeBubble
        }
        .frame(width: 960, height: 544)
    }

    // MARK: Fondo

    @ViewBuilder
    private var backdrop: some View {
        if let background {
            ZStack {
                Color.black
                // Los fondos miden 960×512 y empiezan justo debajo de la barra (32 px).
                Image(nsImage: background)
                    .resizable()
                    .frame(width: 960, height: 512)
                    .position(x: 480, y: 32 + 256)
            }
        } else {
            LinearGradient(
                colors: [Color(white: 0.55), Color(white: 0.78), Color(white: 0.62)],
                startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: Bolita de avisos

    private var noticeBubble: some View {
        ZStack {
            if showNotice {
                // Brillo: halo de ~12 px pegado al borde del círculo
                Circle()
                    .fill(colors.noticeGlow.color)
                    .frame(width: Metrics.bubbleDiameter + 26, height: Metrics.bubbleDiameter + 26)
                    .blur(radius: 8)
                    .position(Metrics.bubbleCenter)
            }

            bubbleFace

            if showNotice {
                Text("1")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(colors.noticeFont.color)
                    .position(x: 928, y: 31.5)
            }
        }
        .frame(width: 960, height: 544)
    }

    @ViewBuilder
    private var bubbleFace: some View {
        let d = Metrics.bubbleDiameter
        let c = Metrics.bubbleCenter
        if let noticeImage {
            // La consola dibuja la imagen a tamaño real y solo deja ver lo que cae dentro del círculo.
            Image(nsImage: noticeImage)
                .resizable()
                .interpolation(.high)
                .frame(width: Metrics.imageSize.width, height: Metrics.imageSize.height)
                .position(x: Metrics.imageOrigin.x + Metrics.imageSize.width / 2,
                          y: Metrics.imageOrigin.y + Metrics.imageSize.height / 2)
                .mask {
                    Circle()
                        .frame(width: d, height: d)
                        .position(c)
                }
        } else {
            // Bolita azul por defecto (degradado medido en la consola)
            Circle()
                .fill(LinearGradient(stops: [
                    .init(color: Color(red: 0.373, green: 0.478, blue: 0.667), location: 0.00),
                    .init(color: Color(red: 0.349, green: 0.455, blue: 0.655), location: 0.34),
                    .init(color: Color(red: 0.259, green: 0.396, blue: 0.612), location: 0.52),
                    .init(color: Color(red: 0.204, green: 0.349, blue: 0.616), location: 0.65),
                    .init(color: Color(red: 0.212, green: 0.373, blue: 0.624), location: 0.74),
                    .init(color: Color(red: 0.294, green: 0.475, blue: 0.710), location: 0.83),
                    .init(color: Color(red: 0.369, green: 0.553, blue: 0.773), location: 0.92),
                    .init(color: Color(red: 0.408, green: 0.612, blue: 0.816), location: 1.00)
                ], startPoint: .top, endPoint: .bottom))
                .frame(width: d, height: d)
                .position(c)
        }
    }
}
