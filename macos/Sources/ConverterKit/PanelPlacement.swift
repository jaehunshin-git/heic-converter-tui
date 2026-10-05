import Foundation
import CoreGraphics

/// AppKit 화면 좌표(아래쪽 원점)에서 메뉴 막대 아이콘 아래의 패널 영역을 계산한다.
public enum PanelPlacement {
    public static let defaultSize = CGSize(width: 420, height: 600)
    public static let minimumSize = CGSize(width: 380, height: 560)
    public static let edgeMargin: CGFloat = 8
    public static let anchorGap: CGFloat = 8

    public static func frame(anchor: CGRect, visibleFrame: CGRect, size: CGSize) -> CGRect {
        let bounds = availableFrame(anchor: anchor, visibleFrame: visibleFrame)
        let width = min(max(1, size.width), bounds.width)
        let height = min(max(1, size.height), bounds.height)
        let x = min(max(anchor.midX - width / 2, bounds.minX), bounds.maxX - width)
        return CGRect(x: x, y: bounds.maxY - height, width: width, height: height)
    }

    public static func availableFrame(anchor: CGRect, visibleFrame: CGRect) -> CGRect {
        // 작은 화면에서도 inset이 음수 크기를 만들지 않도록 제한한다.
        let horizontalMargin = min(edgeMargin, max(0, (visibleFrame.width - 1) / 2))
        let verticalMargin = min(edgeMargin, max(0, (visibleFrame.height - 1) / 2))
        let left = visibleFrame.minX + horizontalMargin
        let bottom = visibleFrame.minY + verticalMargin
        let top = max(bottom + 1, min(anchor.minY - anchorGap, visibleFrame.maxY - verticalMargin))
        return CGRect(x: left, y: bottom,
                      width: max(1, visibleFrame.width - horizontalMargin * 2), height: top - bottom)
    }
}
