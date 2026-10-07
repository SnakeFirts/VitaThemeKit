import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Paneles de macOS para elegir imágenes y carpetas.
enum Pickers {
    @MainActor static func image() -> URL? {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.image]
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        return p.runModal() == .OK ? p.url : nil
    }

    @MainActor static func folder() -> URL? {
        let p = NSOpenPanel()
        p.canChooseFiles = false
        p.canChooseDirectories = true
        p.canCreateDirectories = true
        p.prompt = "Export here"
        return p.runModal() == .OK ? p.url : nil
    }

    /// Carpetas y/o varios archivos de una vez.
    @MainActor static func iconSources() -> [URL] {
        let p = NSOpenPanel()
        p.canChooseFiles = true
        p.canChooseDirectories = true
        p.allowsMultipleSelection = true
        p.allowedContentTypes = [.image]
        p.prompt = "Import"
        p.message = "Choose a folder, or several icons (icon_web.png, icon_mail.png...)"
        return p.runModal() == .OK ? p.urls : []
    }
}

/// Lee la URL de un archivo soltado sobre una vista.
func handleFileDrop(_ providers: [NSItemProvider], _ done: @escaping (URL) -> Void) -> Bool {
    guard let provider = providers.first else { return false }
    _ = provider.loadObject(ofClass: URL.self) { url, _ in
        if let url { DispatchQueue.main.async { done(url) } }
    }
    return true
}
