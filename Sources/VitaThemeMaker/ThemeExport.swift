import SwiftUI
import AppKit
import CoreGraphics
import VitaThemeKit

// MARK: - Qué falta y cómo se lanza

@MainActor
extension ThemeProject {

    /// Lo que todavía falta para poder exportar el tema completo. Lista vacía = listo.
    /// El XML siempre menciona los 17 iconos y las dos imágenes de la bolita,
    /// así que sin ellos la carpeta quedaría incompleta.
    func exportMissing(icons: IconsModel) -> [String] {
        var out: [String] = []
        if !lockpaper.hasImage {
            out.append("The lock screen image is missing.")
        }
        let missingIcons = IconsModel.all.filter { icons.sources[$0.name] == nil }
        if !missingIcons.isEmpty {
            out.append("\(missingIcons.count) icons are missing: "
                       + missingIcons.map(\.title).joined(separator: ", ") + ".")
        }
        if notices.source(hasNew: false) == nil {
            out.append("The image for the bubble without notice is missing (notice.png).")
        }
        if notices.source(hasNew: true) == nil {
            out.append("The image for the bubble with notice is missing (notices.png).")
        }
        // Nombre, creador, versión, páginas y waves.
        out += ThemeRules.issues(for: theme)
        return out
    }

    /// Crea `<parent>/<Nombre del tema>/` con todos los archivos y `<parent>/<Nombre del tema>.zip`.
    func exportTheme(icons: IconsModel, to parent: URL) {
        guard !isExportingTheme else { return }
        guard exportMissing(icons: icons).isEmpty,
              let lockImage = lockpaper.cgImage,
              let lockCrop = lockpaper.cropRect,
              let noneSource = notices.source(hasNew: false),
              let noneFraming = notices.framing(hasNew: false),
              let newSource = notices.source(hasNew: true),
              let newFraming = notices.framing(hasNew: true)
        else {
            themeExportStatus = "Some content is still missing; check the icons above."
            return
        }

        let job = ThemeExportJob(
            theme: theme,
            folderName: Self.safeFolderName(name),
            parent: parent,
            pages: pages.map { (source: $0.sourceURL, framing: $0.framing) },
            icons: IconsModel.all.compactMap { spec in
                icons.sources[spec.name].map { (name: spec.name, source: $0) }
            },
            noticeNone: (source: noneSource, framing: noneFraming),
            noticeNew: (source: newSource, framing: newFraming),
            lockImage: lockImage,
            lockCrop: lockCrop
        )

        isExportingTheme = true
        themeExportStatus = nil
        themeExportProblems = []
        lastExportedZip = nil

        Task.detached(priority: .userInitiated) {
            do {
                let result = try ThemeExporter.run(job)
                await MainActor.run {
                    self.lastExportedZip = result.zip
                    self.themeExportProblems = result.problems
                    let mb = String(format: "%.1f", Double(result.zipBytes) / 1_048_576)
                    self.themeExportStatus = result.problems.isEmpty
                        ? "Done: \(result.zip.lastPathComponent) (\(mb) MB). Upload it to the validator."
                        : "Exported, but \(result.problems.count) item(s) need review (\(mb) MB)."
                    self.isExportingTheme = false
                }
            } catch {
                await MainActor.run {
                    self.themeExportStatus = "Error: \(error.localizedDescription)"
                    self.isExportingTheme = false
                }
            }
        }
    }

    /// Nombre del tema convertido en un nombre de carpeta válido.
    private static func safeFolderName(_ name: String) -> String {
        let cleaned = name
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let noDot = String(cleaned.drop(while: { $0 == "." }))
        return noDot.isEmpty ? "Theme" : noDot
    }
}

// MARK: - Trabajo en segundo plano

/// Copia de todo lo que hace falta, para no tocar el proyecto desde otro hilo.
private struct ThemeExportJob: @unchecked Sendable {
    var theme: Theme
    var folderName: String
    var parent: URL
    var pages: [(source: URL, framing: Framing)]
    var icons: [(name: String, source: URL)]
    var noticeNone: (source: URL, framing: Framing)
    var noticeNew: (source: URL, framing: Framing)
    var lockImage: CGImage
    var lockCrop: CGRect
}

private enum ThemeExportError: LocalizedError {
    case zipFailed(String)

    var errorDescription: String? {
        switch self {
        case .zipFailed(let detail): return "Could not create the ZIP. \(detail)"
        }
    }
}

private enum ThemeExporter {

    struct Output {
        let folder: URL
        let zip: URL
        let zipBytes: Int
        let problems: [String]
    }

    /// El validador acepta ZIP de menos de 30 MB.
    static let maxZipBytes = 30 * 1_048_576

    static func run(_ job: ThemeExportJob) throws -> Output {
        let fm = FileManager.default
        let folder = targetFolder(parent: job.parent, name: job.folderName)
        let zipURL = folder.deletingLastPathComponent()
            .appendingPathComponent(folder.lastPathComponent + ".zip")

        // Si ya había una exportación anterior de este tema, se reemplaza completa
        // (así no quedan bg7.png viejos si ahora hay menos páginas).
        try? fm.removeItem(at: folder)
        try? fm.removeItem(at: zipURL)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        // Fondos: bgN.png y bgtN.png
        try PageImages.writePages(job.pages, to: folder)

        // Pantalla de bloqueo
        try PageImages.writeLockpaper(image: job.lockImage, crop: job.lockCrop, to: folder)

        // Iconos
        for icon in job.icons {
            try PageImages.writeIcon(name: icon.name, source: icon.source, to: folder)
        }

        // Bolita de la barra
        try PageImages.writeNotice(hasNew: false, source: job.noticeNone.source,
                                   framing: job.noticeNone.framing, to: folder)
        try PageImages.writeNotice(hasNew: true, source: job.noticeNew.source,
                                   framing: job.noticeNew.framing, to: folder)

        // Vistas previas: salen de la primera página y de la pantalla de bloqueo.
        if let first = job.pages.first {
            try PageImages.writePreviewThumbnail(source: first.source, framing: first.framing, to: folder)
            try PageImages.writePreviewPage(source: first.source, framing: first.framing, to: folder)
        }
        try PageImages.writePreviewLockscreen(image: job.lockImage, crop: job.lockCrop, to: folder)

        // theme.xml
        try ThemeXML.write(job.theme, to: folder)

        // ZIP con los archivos en la raíz (sin carpeta contenedora ni archivos ocultos).
        try makeZip(of: folder, at: zipURL)
        let zipBytes = ((try? fm.attributesOfItem(atPath: zipURL.path))?[.size] as? NSNumber)?.intValue ?? 0

        var problems = ThemeRules.issues(for: job.theme)
        problems += ThemeFolderChecker.check(directory: folder)
        if zipBytes > maxZipBytes {
            problems.append("The ZIP is larger than 30 MB; the validator would not accept it.")
        }
        return Output(folder: folder, zip: zipURL, zipBytes: zipBytes, problems: problems)
    }

    /// `<parent>/<name>`; si ya existe una carpeta con ese nombre que no parece
    /// una exportación anterior (sin theme.xml), usa "<name> 2", "<name> 3"...
    private static func targetFolder(parent: URL, name: String) -> URL {
        let fm = FileManager.default
        var candidate = parent.appendingPathComponent(name, isDirectory: true)
        var n = 2
        while fm.fileExists(atPath: candidate.path),
              !fm.fileExists(atPath: candidate.appendingPathComponent("theme.xml").path) {
            candidate = parent.appendingPathComponent("\(name) \(n)", isDirectory: true)
            n += 1
        }
        return candidate
    }

    private static func makeZip(of folder: URL, at zipURL: URL) throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { !$0.hasPrefix(".") }
            .sorted()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = folder
        // -X: sin atributos extra de macOS; -q: sin mensajes.
        process.arguments = ["-X", "-q", zipURL.path] + names
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let detail = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw ThemeExportError.zipFailed(detail)
        }
    }
}
