import AppKit
import Combine
import ConverterKit
import ImageIO
import UniformTypeIdentifiers

/// 사용자 클립보드·설정을 건드리지 않고 실제 worker의 이미지 복사 경로를 검사한다.
@MainActor func clipboardConversionSmokeTest() async -> Bool {
    let name = "heic-copy-smoke-\(UUID().uuidString)"
    let folder = URL(fileURLWithPath: InputValidator.canonicalPath(FileManager.default.temporaryDirectory)).appendingPathComponent(name)
    let clipboard = NSPasteboard(name: NSPasteboard.Name(name))
    guard let defaults = UserDefaults(suiteName: name) else { return false }
    let temporaryResults = folder.appendingPathComponent("임시 결과")
    let model = AppModel(startClipboard: false, pasteboard: clipboard, defaults: defaults, clipboardRoot: temporaryResults)
    defer {
        model.shutdown(); clipboard.releaseGlobally(); defaults.removePersistentDomain(forName: name)
        try? FileManager.default.removeItem(at: folder)
    }
    func check(_ label: String, _ passed: Bool) -> Bool {
        print("이미지 복사 검증 [\(label)]: \(passed ? "성공" : "실패")")
        if !passed { print("복사 상태: \(model.message), \(model.queue.items.map { $0.status.rawValue })") }
        return passed
    }
    func waitUntilIdle() async -> Bool {
        let deadline = Date().addingTimeInterval(30)
        while model.active && Date() < deadline { try? await Task.sleep(for: .milliseconds(20)) }
        return check("작업 종료", !model.active && model.queue.jobs.isEmpty)
    }
    func add(_ urls: [URL]) { model.stage(urls); model.acceptStaged(convert: false) }
    func noTemporaryImages() -> Bool {
        let files = FileManager.default.enumerator(at: temporaryResults, includingPropertiesForKeys: nil)
        return !(files?.allObjects as? [URL] ?? []).contains { ["jpeg", "png", "jpg"].contains($0.pathExtension.lowercased()) }
    }
    do {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let first = folder.appendingPathComponent("첫 이미지.heic")
        let second = folder.appendingPathComponent("둘째 이미지.heic")
        guard let context = CGContext(data: nil, width: 24, height: 16, bitsPerComponent: 8, bytesPerRow: 96,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
        context.setFillColor(CGColor(red: 0.15, green: 0.65, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 24, height: 16))
        guard let image = context.makeImage(),
              let encoder = CGImageDestinationCreateWithURL(first as CFURL, UTType.heic.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(encoder, image, nil)
        guard CGImageDestinationFinalize(encoder) else { return false }
        let original = try Data(contentsOf: first)
        try original.write(to: second)
        let saveDirectory = folder.appendingPathComponent("사용자 저장 폴더")
        model.settings.outputDirectory = saveDirectory.path
        clipboard.clearContents(); clipboard.setString("기존 복사 내용", forType: .string)
        add([first, second]); model.startWaiting(destination: .clipboard)
        guard await waitUntilIdle(), check("JPEG 다중 이미지·파일 미저장", model.queue.items.map(\.status) == [.succeeded, .succeeded]
            && clipboard.pasteboardItems?.count == 2
            && clipboard.pasteboardItems?.allSatisfy({ item in
                item.data(forType: NSPasteboard.PasteboardType(UTType.jpeg.identifier)) != nil
                    && item.data(forType: .tiff) != nil && !item.types.contains(.fileURL)
            }) == true && !FileManager.default.fileExists(atPath: saveDirectory.path) && noTemporaryImages()) else { return false }
        let copiedData = clipboard.pasteboardItems?.first?.data(forType: .tiff)
        guard let copiedData, let copiedImage = NSBitmapImageRep(data: copiedData),
              check("복사 이미지 크기", copiedImage.pixelsWide == 24 && copiedImage.pixelsHigh == 16) else { return false }
        model.pollClipboard()
        guard check("자체 복사 재입력 없음", model.queue.items.count == 2 && model.notices.isEmpty) else { return false }
        model.removeAll()

        // 연속 복사 예약은 앱 자신의 이전 복사 세대만 이어받아 각각 완료한다.
        add([first]); model.startWaiting(destination: .clipboard)
        add([second]); model.startWaiting(destination: .clipboard)
        guard await waitUntilIdle(), check("연속 이미지 복사 예약", model.queue.items.map(\.status) == [.succeeded, .succeeded]
            && clipboard.pasteboardItems?.count == 1 && noTemporaryImages()) else { return false }
        model.removeAll()

        // 임시 파일명 충돌은 이미지 복사에서 입력을 건너뛰거나 실패시키지 않는다.
        let duplicateFolder = folder.appendingPathComponent("다른 폴더")
        try FileManager.default.createDirectory(at: duplicateFolder, withIntermediateDirectories: true)
        let duplicate = duplicateFolder.appendingPathComponent(first.lastPathComponent)
        try original.write(to: duplicate)
        model.settings.options.onConflict = "skip"
        add([first, duplicate]); model.startWaiting(destination: .clipboard)
        guard await waitUntilIdle(), check("동일 이름 이미지 모두 복사", model.queue.items.map(\.status) == [.succeeded, .succeeded]
            && clipboard.pasteboardItems?.count == 2 && noTemporaryImages()
            && model.settings.options.onConflict == "skip") else { return false }
        model.removeAll()

        let corrupt = folder.appendingPathComponent("손상.heic")
        try Data([1, 2, 3]).write(to: corrupt)
        model.settings.options.outputFormat = "png"
        add([corrupt, first]); model.startWaiting(destination: .clipboard)
        guard await waitUntilIdle(), check("PNG 부분 실패·성공 이미지 복사", model.queue.items.map(\.status) == [.failed, .succeeded]
            && clipboard.pasteboardItems?.count == 1
            && clipboard.data(forType: .png) != nil && noTemporaryImages()
            && !FileManager.default.fileExists(atPath: saveDirectory.path)) else { return false }
        model.removeAll()

        // 명시적 복사 요청 후 사용자가 새 내용을 복사했으면 늦은 결과로 덮어쓰지 않는다.
        add([first]); model.startWaiting(destination: .clipboard)
        clipboard.clearContents(); clipboard.setString("사용자가 새로 복사한 내용", forType: .string)
        guard await waitUntilIdle(), check("변환 도중 클립보드 변경 보존", model.queue.items.first?.status == .failed
            && clipboard.string(forType: .string) == "사용자가 새로 복사한 내용" && noTemporaryImages()) else { return false }
        model.selectedDestination = .files
        model.retryFailures()
        guard await waitUntilIdle(), check("재시도 복사 방식 보존", model.queue.items.first?.status == .succeeded
            && clipboard.data(forType: .png) != nil && !FileManager.default.fileExists(atPath: saveDirectory.path)
            && noTemporaryImages()) else { return false }
        model.removeAll()

        clipboard.clearContents(); clipboard.setString("취소 전 내용", forType: .string)
        add([first]); model.startWaiting(destination: .clipboard); model.cancel()
        guard await waitUntilIdle(), check("복사 취소·기존 내용 보존", model.queue.items.first?.status == .waiting
            && clipboard.string(forType: .string) == "취소 전 내용" && noTemporaryImages()) else { return false }
        model.removeAll()

        // 마지막 파일 처리 중 취소는 worker가 completed를 보내도 이미지를 게시하지 않는다.
        clipboard.clearContents(); clipboard.setString("마지막 파일 취소 전 내용", forType: .string)
        var cancellationSent = false
        let cancellationObserver = model.$queue.sink { queue in
            if !cancellationSent, queue.activeJob?.destination == .clipboard,
               queue.items.contains(where: { $0.status == .running }) {
                cancellationSent = true; model.cancel()
            }
        }
        add([first]); model.startWaiting(destination: .clipboard)
        add([second]); model.startWaiting(destination: .files)
        guard await waitUntilIdle(), check("마지막 파일 취소·후속 저장 예약", cancellationSent
            && model.queue.items.map(\.status) == [.waiting, .succeeded]
            && clipboard.string(forType: .string) == "마지막 파일 취소 전 내용" && noTemporaryImages()) else { return false }
        cancellationObserver.cancel()
        model.removeAll()

        let removed = folder.appendingPathComponent("실행 전 삭제.heic")
        try original.write(to: removed); add([removed]); try FileManager.default.removeItem(at: removed)
        model.startWaiting(destination: .clipboard)
        guard await waitUntilIdle(), check("전체 거절·기존 내용 보존", model.queue.items.first?.status == .failed
            && clipboard.string(forType: .string) == "마지막 파일 취소 전 내용" && noTemporaryImages()) else { return false }
        model.removeAll()

        // 복사와 저장 예약이 섞여도 모드와 당시 PNG 옵션·폴더를 유지한다.
        let mixedSaveDirectory = folder.appendingPathComponent("혼합 저장 폴더")
        model.settings.outputDirectory = mixedSaveDirectory.path
        add([first]); model.startWaiting(destination: .clipboard)
        add([second]); model.startWaiting(destination: .files)
        model.settings.options.outputFormat = "jpeg"
        model.settings.outputDirectory = folder.appendingPathComponent("나중 설정").path
        guard await waitUntilIdle(), check("복사·저장 예약 분리", model.queue.items.map(\.status) == [.succeeded, .succeeded]
            && model.queue.items.first?.destination == nil
            && model.queue.items.last?.destination?.hasSuffix(".png") == true
            && FileManager.default.fileExists(atPath: mixedSaveDirectory.appendingPathComponent(second.deletingPathExtension().lastPathComponent + ".png").path)
            && !FileManager.default.fileExists(atPath: mixedSaveDirectory.appendingPathComponent(first.deletingPathExtension().lastPathComponent + ".png").path)
            && noTemporaryImages()),
              check("합성 원본 보존", try Data(contentsOf: first) == original && Data(contentsOf: second) == original) else { return false }
        let dataAfterCopy = clipboard.data(forType: .png)
        model.shutdown()
        guard check("앱 종료 후 이미지 데이터 유지", dataAfterCopy != nil && clipboard.data(forType: .png) == dataAfterCopy) else { return false }

        let stopRoot = folder.appendingPathComponent("종료 정리")
        let stoppingModel = AppModel(startClipboard: false, pasteboard: clipboard, defaults: defaults, clipboardRoot: stopRoot)
        var stopRequested = false
        var stopped = false
        let stopObserver = stoppingModel.$queue.sink { queue in
            if !stopRequested, queue.items.contains(where: { $0.status == .running }) {
                stopRequested = true
                stoppingModel.shutdown { stopped = true }
            }
        }
        stoppingModel.stage([first]); stoppingModel.acceptStaged(convert: false)
        stoppingModel.startWaiting(destination: .clipboard)
        let stopDeadline = Date().addingTimeInterval(10)
        while !stopped && Date() < stopDeadline { try? await Task.sleep(for: .milliseconds(20)) }
        stopObserver.cancel()
        let leftovers = FileManager.default.enumerator(at: stopRoot, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return check("worker 종료 후 임시 결과 정리", stopped && stopRequested && leftovers.isEmpty
            && clipboard.data(forType: .png) == dataAfterCopy)
    } catch {
        fputs("이미지 복사 검증 실패: \(error.localizedDescription)\n", stderr)
        return false
    }
}
