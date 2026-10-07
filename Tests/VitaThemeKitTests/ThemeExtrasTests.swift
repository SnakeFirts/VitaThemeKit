import XCTest
@testable import VitaThemeKit

final class ThemeExtrasTests: XCTestCase {

    func testPageIndicatorsOnlyWhenEnabled() {
        XCTAssertFalse(ThemeXML.make(Theme()).contains("basePage"))
        let xml = ThemeXML.make(Theme(pageIndicators: true))
        XCTAssertTrue(xml.contains("<m_basePageFilePath>basePage.png</m_basePageFilePath>"))
        XCTAssertTrue(xml.contains("<m_curPageFilePath>curPage.png</m_curPageFilePath>"))
    }

    func testClockHiddenByAlpha() {
        let c = ThemeColor.white.withAlpha(0)
        XCTAssertEqual(c.hex, "00ffffff")
        XCTAssertEqual(c.alpha, 0)
        XCTAssertEqual(c.withAlpha(255).hex, "ffffffff")
    }

    func testDateLayoutHasThreeValuesAndIsClamped() {
        XCTAssertEqual(DateLayout.allCases.map(\.rawValue), [0, 1, 2])
        XCTAssertTrue(ThemeXML.make(Theme(dateLayout: 9)).contains("<m_dateLayout>2</m_dateLayout>"))
        XCTAssertTrue(ThemeXML.make(Theme(dateLayout: -3)).contains("<m_dateLayout>0</m_dateLayout>"))
    }

    func testWaveTableCoversZeroToThirty() {
        XCTAssertEqual(ThemeWaves.all.map(\.value), Array(0...30))
        XCTAssertEqual(Set(ThemeWaves.all.map(\.name)).count, 31)
        let xml = ThemeXML.make(Theme(pages: [ThemePage(waveType: 99)]))
        XCTAssertTrue(xml.contains("<m_waveType>30</m_waveType>"))
    }

    func testVersionFormat() {
        XCTAssertTrue(ThemeRules.isValidVersion("01.00"))
        XCTAssertFalse(ThemeRules.isValidVersion("1.0"))
        XCTAssertFalse(ThemeRules.isValidVersion("01-00"))
        XCTAssertFalse(ThemeRules.isValidVersion("ab.cd"))
    }

    func testIssuesFlagMissingProviderAndAcceptValidTheme() {
        let bad = Theme(info: ThemeInfo(title: "Tema", provider: ""))
        XCTAssertTrue(ThemeRules.issues(for: bad).contains { $0.contains("creator") })
        let ok = Theme(info: ThemeInfo(title: "Tema", provider: "Snake"))
        XCTAssertEqual(ThemeRules.issues(for: ok), [])
    }

    func testPNGHeaderParsing() {
        var d = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
                      0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52])
        d.append(contentsOf: [0, 0, 0x03, 0xC0])      // ancho 960
        d.append(contentsOf: [0, 0, 0x02, 0x00])      // alto 512
        d.append(contentsOf: [8, 3])                  // 8 bits, tipo 3 (paleta)
        let h = PNGHeader(data: d)
        XCTAssertEqual(h, PNGHeader(data: d))
        XCTAssertEqual(h?.width, 960)
        XCTAssertEqual(h?.height, 512)
        XCTAssertEqual(h?.colorType, 3)
        XCTAssertNil(PNGHeader(data: Data([1, 2, 3])))
    }

    func testReferencesFoundInXML() {
        let refs = ThemeFolderChecker.references(inXML: ThemeXML.make(Theme(pages: [ThemePage()])))
        let tags = Set(refs.map(\.tag))
        XCTAssertTrue(tags.isSuperset(of: ["m_imageFilePath", "m_thumbnailFilePath",
                                           "m_iconFilePath", "m_filePath",
                                           "m_homePreviewFilePath", "m_packageImageFilePath"]))
    }
}
