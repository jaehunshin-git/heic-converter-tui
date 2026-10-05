import XCTest
import CoreGraphics
@testable import ConverterKit

final class PanelPlacementTests: XCTestCase {
    func testPanelOpensBelowIconAndStaysCentered() {
        let anchor = CGRect(x: 880, y: 878, width: 32, height: 22)
        let visible = CGRect(x: 0, y: 40, width: 1440, height: 838)
        let frame = PanelPlacement.frame(anchor: anchor, visibleFrame: visible,
                                         size: PanelPlacement.defaultSize)
        XCTAssertEqual(frame.size, CGSize(width: 420, height: 560))
        XCTAssertEqual(frame.midX, anchor.midX)
        XCTAssertEqual(frame.maxY, anchor.minY - 8)
        XCTAssertTrue(visible.contains(frame))
    }

    func testBothMenuBarEdgesClampInsideDisplay() {
        let visible = CGRect(x: 0, y: 80, width: 1440, height: 798)
        for iconX in [CGFloat(0), 1410] {
            let anchor = CGRect(x: iconX, y: 878, width: 30, height: 22)
            let frame = PanelPlacement.frame(anchor: anchor, visibleFrame: visible,
                                             size: CGSize(width: 520, height: 650))
            XCTAssertTrue(visible.insetBy(dx: 8, dy: 8).contains(frame))
            XCTAssertEqual(frame.maxY, 870)
        }
    }

    func testSecondaryDisplayUsesItsOwnNegativeOriginAndDockBounds() {
        let visible = CGRect(x: -1920, y: -200, width: 1860, height: 1056)
        let anchor = CGRect(x: -220, y: 856, width: 34, height: 24)
        let frame = PanelPlacement.frame(anchor: anchor, visibleFrame: visible,
                                         size: CGSize(width: 520, height: 650))
        XCTAssertTrue(visible.insetBy(dx: 8, dy: 8).contains(frame))
        XCTAssertEqual(frame.maxX, visible.maxX - 8)
        XCTAssertEqual(frame.maxY, anchor.minY - 8)
    }

    func testSmallDisplayShrinksPanelInsteadOfCoveringMenuBarOrDock() {
        let visible = CGRect(x: 1500, y: 100, width: 420, height: 400)
        let anchor = CGRect(x: 1800, y: 500, width: 30, height: 24)
        let frame = PanelPlacement.frame(anchor: anchor, visibleFrame: visible,
                                         size: CGSize(width: 520, height: 650))
        XCTAssertEqual(frame.size, CGSize(width: 404, height: 384))
        XCTAssertTrue(visible.insetBy(dx: 8, dy: 8).contains(frame))
    }

    func testResizeKeepsTopAttachedAndNotchedMenuBarRemainsClear() {
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 944)
        let anchor = CGRect(x: 1150, y: 944, width: 34, height: 38)
        let compact = PanelPlacement.frame(anchor: anchor, visibleFrame: visible,
                                           size: CGSize(width: 520, height: 650))
        let expanded = PanelPlacement.frame(anchor: anchor, visibleFrame: visible,
                                            size: CGSize(width: 660, height: 800))
        XCTAssertEqual(compact.maxY, expanded.maxY)
        XCTAssertEqual(compact.midX, expanded.midX)
        XCTAssertLessThan(expanded.maxY, anchor.minY)
    }
}
