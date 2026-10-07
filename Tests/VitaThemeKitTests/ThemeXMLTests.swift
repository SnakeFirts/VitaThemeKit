import XCTest
@testable import VitaThemeKit

final class ThemeXMLTests: XCTestCase {

    func testOneBackgroundBlockPerPage() {
        let theme = Theme(pages: [ThemePage(), ThemePage(), ThemePage()])
        let xml = ThemeXML.make(theme)
        XCTAssertEqual(xml.components(separatedBy: "<BackgroundParam>").count - 1, 3)
        XCTAssertTrue(xml.contains("<m_imageFilePath>bg3.png</m_imageFilePath>"))
        XCTAssertTrue(xml.contains("<m_thumbnailFilePath>bgt3.png</m_thumbnailFilePath>"))
        XCTAssertFalse(xml.contains("bg4.png"))
    }

    func testPagesAreCappedAtTen() {
        let theme = Theme(pages: Array(repeating: ThemePage(), count: 14))
        let xml = ThemeXML.make(theme)
        XCTAssertEqual(xml.components(separatedBy: "<BackgroundParam>").count - 1, 10)
    }

    func testMusicLineOnlyWhenEnabled() {
        XCTAssertFalse(ThemeXML.make(Theme()).contains("m_bgmFilePath"))
        XCTAssertTrue(ThemeXML.make(Theme(hasMusic: true)).contains("<m_bgmFilePath>bgm.at9</m_bgmFilePath>"))
    }

    func testTitleIsEscapedAndFilledInAllLanguages() {
        let theme = Theme(info: ThemeInfo(title: "Snake & Co <1>", provider: "Snakeyes"))
        let xml = ThemeXML.make(theme)
        XCTAssertTrue(xml.contains("<m_default>Snake &amp; Co &lt;1&gt;</m_default>"))
        XCTAssertTrue(xml.contains("<m_sv>Snake &amp; Co &lt;1&gt;</m_sv>"))
        XCTAssertTrue(xml.contains("<m_default>Snakeyes</m_default>"))
    }

    func testLocalizedTitleOverridesDefault() {
        let theme = Theme(info: ThemeInfo(title: "Snake", localizedTitles: ["es": "Serpiente"]))
        let xml = ThemeXML.make(theme)
        XCTAssertTrue(xml.contains("<m_es>Serpiente</m_es>"))
        XCTAssertTrue(xml.contains("<m_fr>Snake</m_fr>"))
    }

    func testAllSeventeenIconsPresent() {
        let xml = ThemeXML.make(Theme())
        XCTAssertEqual(ThemeIcons.all.count, 17)
        XCTAssertEqual(Set(ThemeIcons.all.map(\.name)).count, 17)
        for icon in ThemeIcons.all {
            XCTAssertTrue(xml.contains("<m_iconFilePath>\(icon.file)</m_iconFilePath>"))
        }
    }

    func testColorHex() {
        XCTAssertEqual(ThemeColor.black.hex, "ff000000")
        XCTAssertEqual(ThemeColor(hex: "#FF00ff00")?.hex, "ff00ff00")
        XCTAssertNil(ThemeColor(hex: "zzz"))
    }
}
