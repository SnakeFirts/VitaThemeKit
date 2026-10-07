import Foundation

public enum ThemeXML {

    /// Idiomas que lleva el bloque <m_param> del título (igual que tu plantilla).
    public static let languages = ["da", "de", "es", "fi", "fr", "it",
                                   "nl", "no", "pl", "pt", "ru", "sv"]

    /// Escapa los caracteres especiales del XML.
    static func escape(_ s: String) -> String {
        var out = ""
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default: out.append(ch)
            }
        }
        return out
    }

    /// Genera el contenido del XML del tema.
    /// Escribe un <BackgroundParam> por cada página que existe (1 a 10).
    public static func make(_ theme: Theme) -> String {
        let pages = Array(theme.pages.prefix(Theme.maxPages))
        let c = theme.colors
        var x = ""

        x += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        x += "<theme format-ver=\"01.00\" package=\"0\">\n"

        x += "<InfomationBarProperty>\n"
        x += "<m_barColor>\(c.bar.hex)</m_barColor>\n"
        x += "<m_indicatorColor>\(c.indicator.hex)</m_indicatorColor>\n"
        x += "<m_noticeFontColor>\(c.noticeFont.hex)</m_noticeFontColor>\n"
        x += "<m_noticeGlowColor>\(c.noticeGlow.hex)</m_noticeGlowColor>\n"
        x += "<m_noNoticeFilePath>notice.png</m_noNoticeFilePath>\n"
        x += "<m_newNoticeFilePath>notices.png</m_newNoticeFilePath>\n"
        x += "</InfomationBarProperty>\n"

        x += "<HomeProperty>\n<m_bgParam>\n"
        for (i, page) in pages.enumerated() {
            let n = i + 1
            x += "<BackgroundParam>\n"
            x += "<m_thumbnailFilePath>bgt\(n).png</m_thumbnailFilePath>\n"
            x += "<m_imageFilePath>bg\(n).png</m_imageFilePath>\n"
            let wave = min(max(page.waveType, ThemeWaves.range.lowerBound), ThemeWaves.range.upperBound)
            x += "<m_waveType>\(wave)</m_waveType>\n"
            x += "<m_fontColor>\(page.fontColor.hex)</m_fontColor>\n"
            x += "<m_fontShadow>\(page.fontShadow ? 1 : 0)</m_fontShadow>\n"
            x += "</BackgroundParam>\n"
        }
        x += "</m_bgParam>\n"

        if theme.pageIndicators {
            x += "<m_basePageFilePath>basePage.png</m_basePageFilePath>\n"
            x += "<m_curPageFilePath>curPage.png</m_curPageFilePath>\n"
        }

        if theme.hasMusic {
            x += "<m_bgmFilePath>bgm.at9</m_bgmFilePath>\n"
        }

        for icon in ThemeIcons.all {
            x += "<\(icon.tag)>\n<m_iconFilePath>\(icon.file)</m_iconFilePath>\n</\(icon.tag)>\n"
        }
        x += "</HomeProperty>\n"

        let title = escape(theme.info.title)
        x += "<InfomationProperty>\n"
        x += "<m_contentVer>\(escape(theme.info.contentVersion))</m_contentVer>\n"
        x += "<m_homePreviewFilePath>preview_page.png</m_homePreviewFilePath>\n"
        x += "<m_packageImageFilePath>preview_thumbnail.png</m_packageImageFilePath>\n"
        x += "<m_provider>\n<m_default>\(escape(theme.info.provider))</m_default>\n<m_param></m_param>\n</m_provider>\n"
        x += "<m_startPreviewFilePath>preview_lockscreen.png</m_startPreviewFilePath>\n"
        x += "<m_title>\n<m_default>\(title)</m_default>\n<m_param>\n"
        for lang in languages {
            let t = theme.info.localizedTitles[lang].map(escape) ?? title
            x += "<m_\(lang)>\(t)</m_\(lang)>\n"
        }
        x += "</m_param>\n</m_title>\n"
        x += "</InfomationProperty>\n"

        x += "<StartScreenProperty>\n"
        x += "<m_dateColor>\(c.date.hex)</m_dateColor>\n"
        let layout = min(max(theme.dateLayout, 0), DateLayout.allCases.count - 1)
        x += "<m_dateLayout>\(layout)</m_dateLayout>\n"
        x += "<m_filePath>lockpaper.png</m_filePath>\n"
        x += "<m_notifyBgColor>\(c.notifyBackground.hex)</m_notifyBgColor>\n"
        x += "<m_notifyBorderColor>\(c.notifyBorder.hex)</m_notifyBorderColor>\n"
        x += "<m_notifyFontColor>\(c.notifyFont.hex)</m_notifyFontColor>\n"
        x += "</StartScreenProperty>\n"
        x += "</theme>\n"
        return x
    }

    /// Escribe `theme.xml` en la carpeta indicada.
    @discardableResult
    public static func write(_ theme: Theme, to directory: URL,
                             fileName: String = "theme.xml") throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        try make(theme).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
