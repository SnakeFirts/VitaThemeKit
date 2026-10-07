import Foundation

/// Color en formato AARRGGBB, como lo espera el XML (por ejemplo "ff000000").
public struct ThemeColor: Sendable, Equatable {
    public var argb: UInt32

    public init(argb: UInt32) { self.argb = argb }

    /// Acepta "ff000000" o "#ff000000". Si no es válido devuelve nil.
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 8, let v = UInt32(s, radix: 16) else { return nil }
        self.argb = v
    }

    public var hex: String { String(format: "%08x", argb) }

    public static let black = ThemeColor(argb: 0xff000000)
    public static let white = ThemeColor(argb: 0xffffffff)
}

extension ThemeColor {
    /// Transparencia del color (0...255). 0 = invisible.
    public var alpha: UInt8 { UInt8((argb >> 24) & 0xff) }

    /// Mismo color con otra transparencia (0...255).
    public func withAlpha(_ alpha: UInt8) -> ThemeColor {
        ThemeColor(argb: (UInt32(alpha) << 24) | (argb & 0x00ffffff))
    }
}

/// Posición del reloj en la pantalla de bloqueo (<m_dateLayout>).
/// Verificado en el código de Sony-ThemeTool (DateLayoutEnum) y en
/// ThemeBUILDER: solo existen tres valores, 0, 1 y 2.
public enum DateLayout: Int, CaseIterable, Sendable {
    case bottomLeft = 0
    case topLeft = 1
    case bottomRight = 2

    public var title: String {
        switch self {
        case .bottomLeft:  return "Bottom left"
        case .topLeft:     return "Top left"
        case .bottomRight: return "Bottom right"
        }
    }
}

/// Una de las 31 "waves" (ondas de color del fondo) que acepta <m_waveType>.
/// El valor sigue la numeración de ThemeBUILDER/Sony (assets/waves.png),
/// que NO coincide con el orden en que el selector de la consola muestra las casillas.
public struct ThemeWave: Sendable, Equatable, Identifiable {
    /// Valor que se escribe en el XML (0...30).
    public let value: Int
    /// Nombre interno de la consola.
    public let name: String
    /// Nombre con el que la herramienta de Sony la muestra en su lista.
    public let label: String
    public var id: Int { value }
}

public enum ThemeWaves {
    public static let range = 0...30

    /// Tabla sacada de BackgroundParam.cs de Sony-ThemeTool.
    public static let all: [ThemeWave] = [
        ThemeWave(value: 0, name: "DEFAULT", label: "BLUE01"),
        ThemeWave(value: 1, name: "INITBOOT", label: "WHITE01"),
        ThemeWave(value: 2, name: "RUBY", label: "RED01"),
        ThemeWave(value: 3, name: "PURPLE_01", label: "RED02"),
        ThemeWave(value: 4, name: "ORANGE", label: "BLUE07"),
        ThemeWave(value: 5, name: "PURPLE_02", label: "PURPLE01"),
        ThemeWave(value: 6, name: "A5", label: "BLUE02"),
        ThemeWave(value: 7, name: "DALIA", label: "BLUE03"),
        ThemeWave(value: 8, name: "GRAY_FLAT", label: "BLUE04"),
        ThemeWave(value: 9, name: "RUBY2", label: "RED03"),
        ThemeWave(value: 10, name: "A1", label: "YELLOW01"),
        ThemeWave(value: 11, name: "BLACK", label: "BLACK01"),
        ThemeWave(value: 12, name: "BLUE_FLAT", label: "BLUE05"),
        ThemeWave(value: 13, name: "BLUETB_0513_01", label: "BLUE06"),
        ThemeWave(value: 14, name: "BLUEWHITE_05", label: "YELLOW02"),
        ThemeWave(value: 15, name: "CASIS", label: "PINK01"),
        ThemeWave(value: 16, name: "GREEN_0512_01", label: "GREEN03"),
        ThemeWave(value: 17, name: "KOIAO_0512_01", label: "BLUE08"),
        ThemeWave(value: 18, name: "MAINTOSH", label: "PURPLE02"),
        ThemeWave(value: 19, name: "MARRYGOLD", label: "BROWN01"),
        ThemeWave(value: 20, name: "PEACH_0512_001", label: "BROWN02"),
        ThemeWave(value: 21, name: "PURPLE_03", label: "PURPLE03"),
        ThemeWave(value: 22, name: "PURPLERED", label: "RED04"),
        ThemeWave(value: 23, name: "YELLOW_0512_01", label: "GREY02"),
        ThemeWave(value: 24, name: "REDTB_0513_01", label: "PURPLE04"),
        ThemeWave(value: 25, name: "LIMEGREEN_0513_02", label: "GREEN04"),
        ThemeWave(value: 26, name: "TURQUOISE_0513_01", label: "BLUE09"),
        ThemeWave(value: 27, name: "COLOR_VARI_2G_01", label: "GREEN01"),
        ThemeWave(value: 28, name: "COLOR_VARI_2G_02", label: "GREEN02"),
        ThemeWave(value: 29, name: "COLOR_VARI_2G_03", label: "BLUE10"),
        ThemeWave(value: 30, name: "COLOR_VARI_2G_04", label: "GREY01")
    ]
}

/// Datos de una página de fondo. Los archivos se llaman bg<N>.png y bgt<N>.png
/// según su posición en `Theme.pages` (la primera es la 1).
public struct ThemePage: Sendable, Equatable {
    public var waveType: Int
    public var fontColor: ThemeColor
    public var fontShadow: Bool

    public init(waveType: Int = 5,
                fontColor: ThemeColor = .white,
                fontShadow: Bool = true) {
        self.waveType = waveType
        self.fontColor = fontColor
        self.fontShadow = fontShadow
    }
}

/// Datos para publicar el tema.
public struct ThemeInfo: Sendable, Equatable {
    public var title: String
    /// Título por idioma (códigos del XML: da, de, es, ...). Si falta uno, se usa `title`.
    public var localizedTitles: [String: String]
    public var provider: String
    public var contentVersion: String

    public init(title: String = "",
                localizedTitles: [String: String] = [:],
                provider: String = "",
                contentVersion: String = "01.00") {
        self.title = title
        self.localizedTitles = localizedTitles
        self.provider = provider
        self.contentVersion = contentVersion
    }
}

public struct ThemeColors: Sendable, Equatable {
    public var bar = ThemeColor.black
    public var indicator = ThemeColor.white
    public var noticeFont = ThemeColor.white
    public var noticeGlow = ThemeColor.white
    public var date = ThemeColor(argb: 0x00ffffff)
    public var notifyBackground = ThemeColor(argb: 0x1fffffff)
    public var notifyBorder = ThemeColor(argb: 0xffcccccc)
    public var notifyFont = ThemeColor(argb: 0xffff0000)

    public init() {}
}

public struct Theme: Sendable, Equatable {
    /// La consola admite como máximo 10 páginas.
    public static let maxPages = 10

    public var info: ThemeInfo
    public var colors: ThemeColors
    public var pages: [ThemePage]
    public var dateLayout: Int
    /// Si es true se escribe <m_bgmFilePath>bgm.at9</m_bgmFilePath>.
    public var hasMusic: Bool
    /// Si es true se escriben basePage.png y curPage.png (los puntos que marcan la página).
    public var pageIndicators: Bool

    public init(info: ThemeInfo = ThemeInfo(),
                colors: ThemeColors = ThemeColors(),
                pages: [ThemePage] = [ThemePage()],
                dateLayout: Int = 0,
                hasMusic: Bool = false,
                pageIndicators: Bool = false) {
        self.info = info
        self.colors = colors
        self.pages = pages
        self.dateLayout = dateLayout
        self.hasMusic = hasMusic
        self.pageIndicators = pageIndicators
    }
}

/// Uno de los 17 iconos del menú.
public struct ThemeIcon: Sendable, Identifiable {
    /// Etiqueta del XML (por ejemplo "m_browser").
    public let tag: String
    /// Nombre corto: el archivo es `icon_<name>.png`.
    public let name: String
    /// Nombre que se muestra en la app.
    public let title: String

    public var file: String { "icon_\(name).png" }
    public var id: String { name }
}

public enum ThemeIcons {
    public static let all: [ThemeIcon] = [
        ThemeIcon(tag: "m_browser",    name: "web",       title: "Browser"),
        ThemeIcon(tag: "m_calendar",   name: "calendar",  title: "Calendar"),
        ThemeIcon(tag: "m_camera",     name: "photos",    title: "Photos"),
        ThemeIcon(tag: "m_email",      name: "mail",      title: "Email"),
        ThemeIcon(tag: "m_friend",     name: "friends",   title: "Friends"),
        ThemeIcon(tag: "m_hostCollabo", name: "cma",      title: "Content Manager"),
        ThemeIcon(tag: "m_message",    name: "messages",  title: "Messages"),
        ThemeIcon(tag: "m_music",      name: "music",     title: "Music"),
        ThemeIcon(tag: "m_near",       name: "near",      title: "Near"),
        ThemeIcon(tag: "m_parental",   name: "parental",  title: "Parental Controls"),
        ThemeIcon(tag: "m_party",      name: "party",     title: "Party"),
        ThemeIcon(tag: "m_ps3Link",    name: "ps3link",   title: "PS3 Remote Link"),
        ThemeIcon(tag: "m_ps4Link",    name: "ps4link",   title: "PS4 Link"),
        ThemeIcon(tag: "m_power",      name: "power",     title: "Power"),
        ThemeIcon(tag: "m_settings",   name: "settings",  title: "Settings"),
        ThemeIcon(tag: "m_trophy",     name: "trophies",  title: "Trophies"),
        ThemeIcon(tag: "m_video",      name: "videos",    title: "Videos")
    ]
}
