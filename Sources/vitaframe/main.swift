import Foundation
import CoreGraphics
import VitaThemeKit

let usage = """
Uso:
  vitaframe <imagen> <salida> [pagina] [zoom] [focusX] [focusY]
      Genera una sola página (bgN.png y bgtN.png).
  vitaframe panorama <imagen> <salida> [paginas|auto] [zoom] [focusX] [focusY] [--horizontal|--vertical]
      Reparte una imagen larga entre varias páginas (bg1, bg2, ...).
      Sin opción de dirección se elige sola: imagen ancha = horizontal,
      imagen alta = vertical (bg1 arriba).
  vitaframe icon <imagen> <salida> <nombre> [zoom] [focusX] [focusY]
      Genera icon_<nombre>.png de 128x128.
  vitaframe previewThumbnail|previewPage|previewLockscreen <imagen> <salida> [zoom] [focusX] [focusY]
      Genera preview_thumbnail.png (226x128), preview_page.png o preview_lockscreen.png (480x272).
  vitaframe check <carpeta-del-tema>
      Revisa theme.xml y sus archivos contra los límites de Sony
      (tamaños, peso, PNG indexado, nombres de hasta 32 caracteres).
"""

func fail() -> Never {
    print(usage)
    exit(1)
}

func number(_ list: [String], _ index: Int, _ fallback: Double) -> Double {
    index < list.count ? (Double(list[index]) ?? fallback) : fallback
}

/// Encuadre a partir de `[zoom, focusX, focusY]`, que empiezan en la posición `index`.
func framing(_ list: [String], at index: Int) -> Framing {
    Framing(zoom: number(list, index, 1),
            focus: CGPoint(x: number(list, index + 1, 0.5), y: number(list, index + 2, 0.5)))
}

/// Comandos que escriben un solo archivo: `<imagen> <salida> [zoom] [focusX] [focusY]`.
let singleFileCommands: [String: (URL, Framing, URL) throws -> URL] = [
    "previewThumbnail": { try PageImages.writePreviewThumbnail(source: $0, framing: $1, to: $2) },
    "previewPage": { try PageImages.writePreviewPage(source: $0, framing: $1, to: $2) },
    "previewLockscreen": { try PageImages.writePreviewLockscreen(source: $0, framing: $1, to: $2) }
]

var args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else { fail() }

// Opciones de dirección (se quitan de los argumentos posicionales).
var axis: PanoramaAxis?
if args.contains("--horizontal") { axis = .horizontal }
if args.contains("--vertical") { axis = .vertical }
args.removeAll { $0 == "--horizontal" || $0 == "--vertical" }

do {
    let command = args[0]

    if command == "check" {
        let problems = ThemeFolderChecker.check(directory: URL(fileURLWithPath: args[1]))
        if problems.isEmpty {
            print("Sin problemas: el tema cumple los límites que conozco de Sony.")
        } else {
            print("Se encontraron \(problems.count) problema(s):")
            problems.forEach { print(" -", $0) }
            exit(2)
        }

    } else if command == "panorama" {
        args.removeFirst()
        guard args.count >= 2 else { fail() }
        let pages = args.count > 2 ? Int(args[2]) : nil   // "auto" -> nil
        let result = try PageImages.writePanorama(source: URL(fileURLWithPath: args[0]),
                                                  pages: pages, axis: axis,
                                                  framing: framing(args, at: 3),
                                                  to: URL(fileURLWithPath: args[1]))
        print("Imagen original: \(Int(result.sourceSize.width))x\(Int(result.sourceSize.height))")
        print("Dirección:", result.plan.axis == .vertical ? "vertical (bg1 arriba)" : "horizontal (bg1 a la izquierda)")
        print("Páginas generadas: \(result.plan.pageCount)")
        if result.plan.scaleFactor > 1.05 {
            print(String(format: "Aviso: la imagen se amplía x%.2f; puede verse menos nítida.",
                         result.plan.scaleFactor))
        }
        result.files.forEach { print("Escrito:", $0.path) }

    } else if command == "icon" {
        args.removeFirst()
        guard args.count >= 3 else { fail() }
        let file = try PageImages.writeIcon(name: args[2], source: URL(fileURLWithPath: args[0]),
                                            framing: framing(args, at: 3),
                                            to: URL(fileURLWithPath: args[1]))
        print("Escrito:", file.path)

    } else if let write = singleFileCommands[command] {
        args.removeFirst()
        guard args.count >= 2 else { fail() }
        let file = try write(URL(fileURLWithPath: args[0]), framing(args, at: 2),
                             URL(fileURLWithPath: args[1]))
        print("Escrito:", file.path)

    } else {
        // Página única: <imagen> <salida> [pagina] [zoom] [focusX] [focusY]
        let page = args.count > 2 ? Int(args[2]) ?? 1 : 1
        let files = try PageImages.writePage(number: page, source: URL(fileURLWithPath: args[0]),
                                             framing: framing(args, at: 3),
                                             to: URL(fileURLWithPath: args[1]))
        files.forEach { print("Escrito:", $0.path) }
    }
} catch {
    print("Error:", error)
    exit(1)
}
