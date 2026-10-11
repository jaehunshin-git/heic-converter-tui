import AppKit
import SwiftUI

/// 왼쪽 위를 원점으로 사용하는 공통 벡터 기하.
enum PhotoClipboardIconGeometry {
    static let menuBarSize = CGSize(width: 16.2, height: 18)
    static let accessibilityDescription = "사진 클립보드 — HEIC Converter"

    /// 기본 18×20pt에서 1.4pt이며, 작은 크기에서도 최소 1.3pt를 유지한다.
    static func lineWidth(in size: CGSize) -> CGFloat {
        max(1.3, 1.4 * min(size.width / 18, size.height / 20))
    }

    /// 외곽과 집게를 이어 그려 중첩 선 없이 하나의 클립보드로 읽히게 한다.
    /// 산과 해도 같은 경로에 포함하며, 별도의 사진 테두리는 두지 않는다.
    static func centerline(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 6, y: 3.5))
        path.addLine(to: CGPoint(x: 4, y: 3.5))
        path.addQuadCurve(to: CGPoint(x: 2, y: 5.5), control: CGPoint(x: 2, y: 3.5))
        path.addLine(to: CGPoint(x: 2, y: 16.75))
        path.addQuadCurve(to: CGPoint(x: 4, y: 18.75), control: CGPoint(x: 2, y: 18.75))
        path.addLine(to: CGPoint(x: 14, y: 18.75))
        path.addQuadCurve(to: CGPoint(x: 16, y: 16.75), control: CGPoint(x: 16, y: 18.75))
        path.addLine(to: CGPoint(x: 16, y: 5.5))
        path.addQuadCurve(to: CGPoint(x: 14, y: 3.5), control: CGPoint(x: 16, y: 3.5))
        path.addLine(to: CGPoint(x: 12, y: 3.5))
        path.addLine(to: CGPoint(x: 12, y: 2.25))
        path.addQuadCurve(to: CGPoint(x: 11, y: 1.25), control: CGPoint(x: 12, y: 1.25))
        path.addLine(to: CGPoint(x: 7, y: 1.25))
        path.addQuadCurve(to: CGPoint(x: 6, y: 2.25), control: CGPoint(x: 6, y: 1.25))
        path.closeSubpath()

        path.move(to: CGPoint(x: 6, y: 3.5))
        path.addLine(to: CGPoint(x: 6, y: 4.25))
        path.addQuadCurve(to: CGPoint(x: 7, y: 5.25), control: CGPoint(x: 6, y: 5.25))
        path.addLine(to: CGPoint(x: 11, y: 5.25))
        path.addQuadCurve(to: CGPoint(x: 12, y: 4.25), control: CGPoint(x: 12, y: 5.25))
        path.addLine(to: CGPoint(x: 12, y: 3.5))

        path.move(to: CGPoint(x: 5, y: 15))
        path.addLine(to: CGPoint(x: 8, y: 10.75))
        path.addLine(to: CGPoint(x: 10.75, y: 14))
        path.addLine(to: CGPoint(x: 12.5, y: 12))
        path.addLine(to: CGPoint(x: 13.5, y: 15))
        // 16pt·1x에서도 해의 빈 중심이 선에 묻히지 않도록 지름을 확보한다.
        path.addEllipse(in: CGRect(x: 10.4, y: 7, width: 3, height: 3))

        let scale = max(0, min(rect.width / 18, rect.height / 20))
        var transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                         tx: rect.midX - 9 * scale,
                                         ty: rect.midY - 10 * scale)
        return path.copy(using: &transform)!
    }

    /// 실제 출력 크기에서 선을 면으로 변환하여 SwiftUI와 AppKit이 공유한다.
    static func silhouette(in rect: CGRect) -> CGPath {
        guard rect.width > 0, rect.height > 0 else { return CGMutablePath() }
        return centerline(in: rect).copy(strokingWithWidth: lineWidth(in: rect.size),
                                        lineCap: .round, lineJoin: .round, miterLimit: 2)
    }

    /// 벡터 그리기 핸들러는 화면 배율마다 다시 그려져 1x·2x에서 선명하다.
    static func makeTemplateImage(size: CGSize = menuBarSize, isPaused: Bool = false) -> NSImage {
        let image = NSImage(size: size, flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.setFillColor(NSColor.black.withAlphaComponent(isPaused ? 0.55 : 1).cgColor)
            context.addPath(silhouette(in: rect))
            context.fillPath()
            if isPaused {
                let scale = min(rect.width / 18, rect.height / 20)
                context.saveGState()
                context.translateBy(x: rect.midX - 9 * scale, y: rect.midY - 10 * scale)
                context.scaleBy(x: scale, y: scale)
                // 옅은 클립보드와 진한 일시정지 기호로 색상에만 의존하지 않고 상태를 알린다.
                context.setBlendMode(.clear)
                context.fillEllipse(in: CGRect(x: 9.5, y: 11.5, width: 8, height: 8))
                context.setBlendMode(.normal)
                context.setFillColor(NSColor.black.cgColor)
                context.fill(CGRect(x: 11, y: 13, width: 1.7, height: 5))
                context.fill(CGRect(x: 14, y: 13, width: 1.7, height: 5))
                context.restoreGState()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = isPaused ? "HEIC Converter — 자동 변환 일시정지됨" : accessibilityDescription
        return image
    }
}

/// `.fill(.primary)` 등으로 패널의 색상을 직접 지정할 수 있는 공통 도형.
struct PhotoClipboardIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(PhotoClipboardIconGeometry.silhouette(in: rect))
    }
}

/// 패널 헤더에서 `.frame(width: 22, height: 24)`로 사용한다.
struct PhotoClipboardIcon: View {
    var body: some View {
        PhotoClipboardIconShape()
            .fill(.primary)
            .accessibilityLabel(PhotoClipboardIconGeometry.accessibilityDescription)
            .accessibilityAddTraits(.isImage)
    }
}
