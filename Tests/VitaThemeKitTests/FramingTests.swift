import XCTest
import CoreGraphics
@testable import VitaThemeKit

final class FramingTests: XCTestCase {
    let target = CGSize(width: 960, height: 512)

    func testSameAspectUsesWholeImage() {
        let r = FramingMath.coverCrop(source: CGSize(width: 1920, height: 1024),
                                      target: target, framing: .default)
        XCTAssertEqual(r, CGRect(x: 0, y: 0, width: 1920, height: 1024))
    }

    func testTallerImageCropsTopAndBottomNotStretch() {
        // 1000x1000 -> el marco es mas ancho: se recorta en vertical.
        let r = FramingMath.coverCrop(source: CGSize(width: 1000, height: 1000),
                                      target: target, framing: .default)
        XCTAssertEqual(r.width, 1000, accuracy: 0.001)
        XCTAssertEqual(r.height, 1000 * 512 / 960, accuracy: 0.001)
        // La proporcion del recorte coincide con la del marco: nada se estira.
        XCTAssertEqual(r.width / r.height, target.width / target.height, accuracy: 0.0001)
    }

    func testZoomShrinksCrop() {
        var f = Framing.default
        f.zoom = 2
        let r = FramingMath.coverCrop(source: CGSize(width: 1920, height: 1024),
                                      target: target, framing: f)
        XCTAssertEqual(r.width, 960, accuracy: 0.001)
        XCTAssertEqual(r.height, 512, accuracy: 0.001)
    }

    func testFocusIsClampedInsideImage() {
        var f = Framing.default
        f.zoom = 2
        f.focus = CGPoint(x: 0, y: 0)
        let r = FramingMath.coverCrop(source: CGSize(width: 1920, height: 1024),
                                      target: target, framing: f)
        XCTAssertEqual(r.minX, 0)
        XCTAssertEqual(r.minY, 0)
        f.focus = CGPoint(x: 1, y: 1)
        let r2 = FramingMath.coverCrop(source: CGSize(width: 1920, height: 1024),
                                       target: target, framing: f)
        XCTAssertEqual(r2.maxX, 1920, accuracy: 0.001)
        XCTAssertEqual(r2.maxY, 1024, accuracy: 0.001)
    }

    func testClampZoomStaysInRange() {
        XCTAssertEqual(Framing.clampZoom(0.2), 1)
        XCTAssertEqual(Framing.clampZoom(99), 8)
        XCTAssertEqual(Framing.clampZoom(2.5), 2.5)
    }

    func testPannedFocusMovesAgainstTheDragAndIsClamped() {
        let source = CGSize(width: 1920, height: 1024)
        let target = CGSize(width: 960, height: 512)
        let center = CGPoint(x: 0.5, y: 0.5)
        let shown = CGSize(width: 960, height: 512)
        let framing = Framing(zoom: 2)

        // Arrastrar a la izquierda muestra la parte derecha de la imagen.
        let moved = FramingMath.pannedFocus(from: center, translation: CGSize(width: -100, height: 0),
                                            displayed: shown, source: source, target: target, framing: framing)
        XCTAssertGreaterThan(moved.x, 0.5)
        XCTAssertEqual(moved.y, 0.5, accuracy: 0.0001)

        let far = FramingMath.pannedFocus(from: center, translation: CGSize(width: -1_000_000, height: 0),
                                          displayed: shown, source: source, target: target, framing: framing)
        XCTAssertEqual(far.x, 1)
    }

    func testContainFitsInsideAndIsCentered() {
        let r = FramingMath.containRect(source: CGSize(width: 1000, height: 1000),
                                        target: target, framing: Framing(mode: .contain))
        XCTAssertEqual(r.height, 512, accuracy: 0.001)
        XCTAssertEqual(r.width, 512, accuracy: 0.001)
        XCTAssertEqual(r.midX, 480, accuracy: 0.001)
    }
}
