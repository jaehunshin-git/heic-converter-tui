import XCTest
import CoreGraphics
@testable import ConverterKit

final class PanelPlacementTests: XCTestCase {
    func testFileHeightGrowsForThumbnailsAndStopsAfterThreeRows() {
        XCTAssertEqual(PanelPlacement.preferredHeight(fileCount: 0, stagedCount: 0), 520)
        XCTAssertEqual(PanelPlacement.preferredHeight(fileCount: 1, stagedCount: 0), 620)
        XCTAssertEqual(PanelPlacement.preferredHeight(fileCount: 2, stagedCount: 0), 684)
        XCTAssertEqual(PanelPlacement.preferredHeight(fileCount: 3, stagedCount: 0), 748)
        XCTAssertEqual(PanelPlacement.preferredHeight(fileCount: 100, stagedCount: 0), 748)
        XCTAssertEqual(PanelPlacement.preferredHeight(fileCount: 0, stagedCount: 5), 700)
        XCTAssertEqual(PanelPlacement.preferredHeight(fileCount: 100, stagedCount: 5), 800)
    }

    func testFileExpansionKeepsTopAndWidthAndFitsSmallScreen() {
        let anchor = CGRect(x: 880, y: 878, width: 32, height: 22)
        let visible = CGRect(x: 0, y: 40, width: 1440, height: 838)
        let empty = PanelPlacement.frame(anchor: anchor, visibleFrame: visible, size: PanelPlacement.defaultSize)
        let populated = PanelPlacement.frame(anchor: anchor, visibleFrame: visible,
            size: CGSize(width: 420, height: PanelPlacement.preferredHeight(fileCount: 3, stagedCount: 0)))
        XCTAssertEqual(empty.maxY, populated.maxY)
        XCTAssertEqual(empty.width, populated.width)
        XCTAssertGreaterThan(populated.height, empty.height)
        let small = CGRect(x: 0, y: 400, width: 1440, height: 478)
        let constrained = PanelPlacement.frame(anchor: anchor, visibleFrame: small, size: populated.size)
        XCTAssertTrue(small.contains(constrained))
        XCTAssertLessThan(constrained.height, populated.height)
    }

    func testPanelOpensBelowIconAndStaysCentered() {
        let anchor = CGRect(x: 880, y: 878, width: 32, height: 22)
        let visible = CGRect(x: 0, y: 40, width: 1440, height: 838)
        let frame = PanelPlacement.frame(anchor: anchor, visibleFrame: visible,
                                         size: PanelPlacement.defaultSize)
        XCTAssertEqual(frame.size, CGSize(width: 420, height: 520))
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
