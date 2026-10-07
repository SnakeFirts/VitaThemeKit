import Foundation

/// Reglas del validador de Sony (sacadas de Sony-ThemeTool) para revisar un
/// tema antes de instalarlo. No depende de CoreGraphics.
public enum ThemeRules {

    public static let maxXMLBytes = 32_768
    public static let maxTextBytes = 127
    public static let maxFileNameLength = 32

    /// "NN.NN": dos dígitos, punto, dos dígitos (por ejemplo "01.00").
    public static func isValidVersion(_ v: String) -> Bool {
        let c = Array(v)
        guard c.count == 5, c[2] == "." else { return false }
        return [0, 1, 3, 4].allSatisfy { c[$0].isASCII && c[$0].isNumber }
    }

    /// Problemas del tema en sí (datos y XML). Lista vacía = todo bien.
    public static func issues(for theme: Theme) -> [String] {
        var out: [String] = []
        func bytes(_ s: String) -> Int { s.utf8.count }
        func blank(_ s: String) -> Bool { s.trimmingCharacters(in: .whitespaces).isEmpty }

        if blank(theme.info.title) {
            out.append("The theme name is missing.")
        } else if bytes(theme.info.title) > maxTextBytes {
            out.append("The theme name exceeds \(maxTextBytes) bytes (\(bytes(theme.info.title))).")
        }
        if blank(theme.info.provider) {
            out.append("The creator is missing: Sony's validator requires it.")
        } else if bytes(theme.info.provider) > maxTextBytes {
            out.append("The creator exceeds \(maxTextBytes) bytes (\(bytes(theme.info.provider))).")
        }
        for (lang, text) in theme.info.localizedTitles.sorted(by: { $0.key < $1.key })
        where bytes(text) > maxTextBytes {
            out.append("The title in '\(lang)' exceeds \(maxTextBytes) bytes (\(bytes(text))).")
        }
        if !isValidVersion(theme.info.contentVersion) {
            out.append("The version '\(theme.info.contentVersion)' must use the NN.NN format (for example 01.00).")
        }
        if theme.pages.isEmpty {
            out.append("Add at least one background page.")
        }
        for (i, p) in theme.pages.enumerated() where !ThemeWaves.range.contains(p.waveType) {
            out.append("Page \(i + 1) has a wave out of range (\(p.waveType)); it must be from 0 to 30.")
        }
        if !DateLayout.allCases.map(\.rawValue).contains(theme.dateLayout) {
            out.append("The clock position (\(theme.dateLayout)) must be 0, 1 or 2.")
        }
        let size = ThemeXML.make(theme).utf8.count
        if size > maxXMLBytes {
            out.append("theme.xml is \(size) bytes and the maximum is \(maxXMLBytes).")
        }
        return out
    }
}

/// Lo que se puede leer de la cabecera de un PNG sin decodificarlo.
public struct PNGHeader: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let bitDepth: Int
    /// 3 = paleta (indexado). Sony exige 3 en todas las imágenes del tema.
    public let colorType: Int

    public init?(data: Data) {
        let b = [UInt8](data.prefix(26))
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard b.count >= 26, Array(b[0..<8]) == signature,
              Array(b[12..<16]) == Array("IHDR".utf8) else { return nil }
        func u32(_ o: Int) -> Int {
            Int(b[o]) << 24 | Int(b[o + 1]) << 16 | Int(b[o + 2]) << 8 | Int(b[o + 3])
        }
        width = u32(16)
        height = u32(20)
        bitDepth = Int(b[24])
        colorType = Int(b[25])
    }
}

/// Revisa una carpeta de tema ya exportada contra los límites de Sony.
public enum ThemeFolderChecker {

    struct Spec {
        let width: Int
        let height: Int
        let maxBytes: Int
    }

    /// Límites por etiqueta del XML (Sony-ThemeTool, CheckProperties).
    static let specs: [String: Spec] = [
        "m_imageFilePath":          Spec(width: 960, height: 512, maxBytes: 614_400),
        "m_filePath":               Spec(width: 960, height: 512, maxBytes: 614_400),
        "m_thumbnailFilePath":      Spec(width: 360, height: 192, maxBytes: .max),
        "m_iconFilePath":           Spec(width: 128, height: 128, maxBytes: 32_768),
        "m_noNoticeFilePath":       Spec(width: 120, height: 110, maxBytes: 12_288),
        "m_newNoticeFilePath":      Spec(width: 120, height: 110, maxBytes: 12_288),
        "m_basePageFilePath":       Spec(width: 22, height: 22, maxBytes: 4_096),
        "m_curPageFilePath":        Spec(width: 22, height: 22, maxBytes: 4_096),
        "m_homePreviewFilePath":    Spec(width: 480, height: 272, maxBytes: 133_120),
        "m_startPreviewFilePath":   Spec(width: 480, height: 272, maxBytes: 133_120),
        "m_packageImageFilePath":   Spec(width: 226, height: 128, maxBytes: 49_152)
    ]

    /// Etiquetas -> (archivo) tal como aparecen en el XML.
    static func references(inXML xml: String) -> [(tag: String, file: String)] {
        guard let re = try? NSRegularExpression(
            pattern: "<(m_[A-Za-z0-9]*[Ff]ilePath)>([^<]+)</\\1>") else { return [] }
        let ns = xml as NSString
        return re.matches(in: xml, range: NSRange(location: 0, length: ns.length)).map {
            (ns.substring(with: $0.range(at: 1)),
             ns.substring(with: $0.range(at: 2)).trimmingCharacters(in: .whitespaces))
        }
    }

    /// Lee `theme.xml` de la carpeta y revisa cada archivo que menciona.
    /// Lista vacía = nada que corregir.
    public static func check(directory: URL) -> [String] {
        let xmlURL = directory.appendingPathComponent("theme.xml")
        guard let data = try? Data(contentsOf: xmlURL),
              let xml = String(data: data, encoding: .utf8) else {
            return ["Could not find theme.xml in \(directory.path)."]
        }
        var out: [String] = []
        if data.count > ThemeRules.maxXMLBytes {
            out.append("theme.xml is \(data.count) bytes; the maximum is \(ThemeRules.maxXMLBytes).")
        }
        var seen = Set<String>()
        for (tag, file) in references(inXML: xml) {
            if file.count > ThemeRules.maxFileNameLength {
                out.append("\(file): the name exceeds \(ThemeRules.maxFileNameLength) characters.")
            }
            let url = directory.appendingPathComponent(file)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = (attrs[.size] as? NSNumber)?.intValue else {
                out.append("\(file): the file is missing.")
                continue
            }
            if tag == "m_bgmFilePath" {
                if size > 5_242_880 { out.append("\(file): larger than 5 MiB.") }
                continue
            }
            guard let spec = specs[tag], seen.insert("\(tag)|\(file)").inserted else { continue }
            guard let head = try? Data(contentsOf: url, options: .mappedIfSafe),
                  let png = PNGHeader(data: head) else {
                out.append("\(file): not a valid PNG.")
                continue
            }
            if png.width != spec.width || png.height != spec.height {
                out.append("\(file): is \(png.width)x\(png.height) but must be \(spec.width)x\(spec.height).")
            }
            if size > spec.maxBytes {
                out.append("\(file): is \(size) bytes and the maximum is \(spec.maxBytes).")
            }
            // El validador de Sony exige PNG indexado (paleta) en todo, salvo las miniaturas bgt.
            if tag != "m_thumbnailFilePath" && png.colorType != 3 {
                out.append("\(file): not an 8-bit indexed PNG (256-color palette)")
            }
        }
        return out
    }
}
