import XCTest
import CoreGraphics
@testable import VitaThemeKit

final class PanoramaTests: XCTestCase {

    func testAutoAxis() {
        XCTAssertEqual(FramingMath.autoAxis(source: CGSize(width: 9600, height: 512)), .horizontal)
        XCTAssertEqual(FramingMath.autoAxis(source: CGSize(width: 1089, height: 2048)), .vertical)
    }

    func testAutoPageCountHorizontal() {
        XCTAssertEqual(FramingMath.autoPageCount(source: CGSize(width: 9600, height: 512)), 10)
        XCTAssertEqual(FramingMath.autoPageCount(source: CGSize(width: 5760, height: 512)), 6)
        XCTAssertEqual(FramingMath.autoPageCount(source: CGSize(width: 3840, height: 512)), 4)
        XCTAssertEqual(FramingMath.autoPageCount(source: CGSize(width: 1920, height: 1024)), 1)
        XCTAssertEqual(FramingMath.autoPageCount(source: CGSize(width: 20000, height: 512)), 10) // tope
    }

    func testAutoPageCountVertical() {
        // 1089x2048: 2048 / (1089/1.875) = 3.53 -> 4 páginas.
        XCTAssertEqual(FramingMath.autoPageCount(source: CGSize(width: 1089, height: 2048)), 4)
        XCTAssertEqual(FramingMath.autoPageCount(source: CGSize(width: 960, height: 5120)), 10)
    }

    func testHorizontalExactMultiple() {
        let plan = FramingMath.panoramaPlan(source: CGSize(width: 1920, height: 512))
        XCTAssertEqual(plan.axis, .horizontal)
        XCTAssertEqual(plan.pageCount, 2)
        XCTAssertEqual(plan.pageCrops[0], CGRect(x: 0, y: 0, width: 960, height: 512))
        XCTAssertEqual(plan.pageCrops[1], CGRect(x: 960, y: 0, width: 960, height: 512))
        XCTAssertEqual(plan.scaleFactor, 1, accuracy: 0.0001)
    }

    func testVerticalExactMultiple() {
        let plan = FramingMath.panoramaPlan(source: CGSize(width: 960, height: 1024))
        XCTAssertEqual(plan.axis, .vertical)
        XCTAssertEqual(plan.pageCount, 2)
        XCTAssertEqual(plan.pageCrops[0], CGRect(x: 0, y: 0, width: 960, height: 512))
        XCTAssertEqual(plan.pageCrops[1], CGRect(x: 0, y: 512, width: 960, height: 512))
    }

    func testUserImageVertical() {
        // La imagen real del proyecto: 1089x2048 -> 4 páginas, sin ampliar.
        let plan = FramingMath.panoramaPlan(source: CGSize(width: 1089, height: 2048))
        XCTAssertEqual(plan.axis, .vertical)
        XCTAssertEqual(plan.pageCount, 4)
        XCTAssertEqual(plan.scaleFactor, 1, accuracy: 0.0001)
        for c in plan.pageCrops {
            XCTAssertEqual(c.width, 960)
            XCTAssertEqual(c.height, 512)
        }
    }

    func testCropsAreContiguousAndInsideSource() {
        for source in [CGSize(width: 6001, height: 777), CGSize(width: 777, height: 6001)] {
            let plan = FramingMath.panoramaPlan(source: source)
            for (a, b) in zip(plan.pageCrops, plan.pageCrops.dropFirst()) {
                switch plan.axis {
                case .horizontal: XCTAssertEqual(a.maxX, b.minX)
                case .vertical:   XCTAssertEqual(a.maxY, b.minY)
                }
            }
            for c in plan.pageCrops {
                XCTAssertGreaterThanOrEqual(c.minX, 0)
                XCTAssertGreaterThanOrEqual(c.minY, 0)
                XCTAssertLessThanOrEqual(c.maxX, source.width)
                XCTAssertLessThanOrEqual(c.maxY, source.height)
            }
        }
    }

    func testExplicitPageCountAndAxisOverrideAuto() {
        let a = FramingMath.panoramaPlan(source: CGSize(width: 9600, height: 512), pages: 3)
        XCTAssertEqual(a.pageCount, 3)
        let b = FramingMath.panoramaPlan(source: CGSize(width: 1089, height: 2048), pages: 3, axis: .vertical)
        XCTAssertEqual(b.pageCount, 3)
        XCTAssertEqual(b.pageCrops.count, 3)
    }
}
