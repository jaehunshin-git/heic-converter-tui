import AppKit
import SwiftUI
import Combine
import ConverterKit
import ImageIO
import UniformTypeIdentifiers

final class DropPanel: NSPanel {
    var onPaste: (() -> Void)?
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "v" {
            onPaste?(); return true
        }
        return super.performKeyEquivalent(with: event)
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel(startClipboard: !CommandLine.arguments.contains("--smoke-test"))
    private var statusItem: NSStatusItem!
    private var panel: DropPanel!
    private var countSubscription: AnyCancellable?
    private var isPositioningPanel = false
    private var panelRevealTimer: Timer?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.badge.arrow.down", accessibilityDescription: "HEIC Converter")
            button.imagePosition = .imageLeading
            button.target = self; button.action = #selector(togglePanel)
            button.toolTip = "HEIC Converter · 클릭하여 패널 열기 또는 숨기기"
        }
        panel = DropPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 650),
                          styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        panel.title = "HEIC Converter"
        panel.onPaste = { [weak self] in self?.model.paste() }
        panel.identifier = NSUserInterfaceItemIdentifier("HEICConverter.DropPanel")
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.minSize = NSSize(width: 480, height: 600)
        panel.delegate = self
        let contentView = NSHostingView(rootView: PanelView(model: model, onClose: { [weak self] in
            self?.hidePanel()
        }))
        // 스크롤 콘텐츠의 intrinsic 높이가 창 크기를 덮어쓰지 않도록 한다.
        contentView.sizingOptions = []
        panel.contentView = contentView
        panel.setContentSize(NSSize(width: 520, height: 650))
        model.onClipboardFilesAdded = { [weak self] in self?.showPanelForClipboard() }
        observeAnchorChanges()
        countSubscription = model.$queue.sink { [weak self] queue in
            self?.statusItem.button?.title = " \(queue.waitingCount)"
            self?.reanchorVisiblePanel()
        }
        // WindowServer가 상태 막대 항목을 배치할 수 있도록 launch 콜백 다음 순서에 표시한다.
        DispatchQueue.main.async { [self] in
            showInitialPanelWhenReady(until: Date().addingTimeInterval(5))
        }
    }

    private func showInitialPanelWhenReady(until deadline: Date) {
        if anchorGeometry() != nil {
            if !panel.isVisible { togglePanel() }
            if CommandLine.arguments.contains("--smoke-test") {
                waitForPanelSmokeReadiness(until: deadline)
            }
        } else if Date() < deadline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                showInitialPanelWhenReady(until: deadline)
            }
        } else {
            print("메뉴 아이콘 배치 준비 시간 초과")
            if CommandLine.arguments.contains("--smoke-test") { runPanelSmokeTest() }
        }
    }

    private func waitForPanelSmokeReadiness(until deadline: Date) {
        if panel.isVisible, anchorGeometry() != nil {
            positionPanel()
            runPanelSmokeTest()
        } else if Date() < deadline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                waitForPanelSmokeReadiness(until: deadline)
            }
        } else {
            print("패널 준비 시간 초과: 표시=\(panel.isVisible), 아이콘=\(statusItem.button != nil), 아이콘 창=\(statusItem.button?.window != nil), 화면 수=\(NSScreen.screens.count)")
            runPanelSmokeTest()
        }
    }

    private func runPanelSmokeTest() {
        var passed = true
        func check(_ label: String, _ condition: Bool) {
            print("패널 검증 [\(label)]: \(condition ? "성공" : "실패")")
            if !condition { passed = false }
        }
        check("최초 표시", panel.isVisible)
        check("포커스 상실 시 유지 설정", !panel.hidesOnDeactivate)
        check("플로팅 레벨", panel.level == .floating)
        check("최초 배치와 크기", panelPlacementSmokeTest())
        check("입력 모델", modelInputSmokeTest())
        togglePanel(); check("메뉴 클릭 숨김", !panel.isVisible)
        togglePanel(); check("메뉴 클릭 다시 표시", panel.isVisible)
        check("다시 표시한 배치와 크기", panelPlacementSmokeTest())
        NSApp.deactivate()
        check("비활성화 후 표시 유지", panel.isVisible)
        _ = windowShouldClose(panel); check("닫기 후 숨김", !panel.isVisible)
        let wasActive = NSApp.isActive
        let previousKeyWindow = NSApp.keyWindow
        showPanelForClipboard(animated: false)
        check("클립보드 자동 표시", panel.isVisible && panel.alphaValue == 1)
        check("자동 표시 시 포커스 유지", NSApp.isActive == wasActive && NSApp.keyWindow === previousKeyWindow && !panel.isKeyWindow)
        check("자동 표시 배치", panelPlacementSmokeTest())
        let visibleFrame = panel.frame
        showPanelForClipboard(animated: true)
        check("이미 열린 패널 유지", panel.isVisible && panel.frame == visibleFrame && panelRevealTimer == nil)
        hidePanel()
        showPanelForClipboard(animated: true)
        check("자동 표시 애니메이션 시작", panel.isVisible && panelRevealTimer != nil && panel.alphaValue == 0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        check("자동 표시 애니메이션 완료", panel.isVisible && panelRevealTimer == nil && panel.alphaValue == 1 && panelPlacementSmokeTest())
        check("애니메이션 후 포커스 유지", NSApp.isActive == wasActive && NSApp.keyWindow === previousKeyWindow && !panel.isKeyWindow)
        hidePanel()
        showPanelForClipboard(animated: true)
        hidePanel()
        check("등장 도중 닫기", !panel.isVisible && panelRevealTimer == nil && panel.alphaValue == 1)
        togglePanel(); check("닫기 후 다시 표시", panel.isVisible)
        check("직접 열기와 CmdV 처리", panel.canBecomeKey && pasteShortcutSmokeTest())
        model.shutdown()
        print(passed ? "메뉴 막대 아래 패널 배치·표시·숨김·포커스 유지 확인 완료" : "패널 검증 실패")
        exit(passed ? 0 : 1)
    }

    @objc func togglePanel() {
        if panel.isVisible { hidePanel() }
        else {
            guard anchorGeometry() != nil else { return }
            positionPanel()
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    /// 새 클립보드 파일은 보여 주되 사용 중인 앱의 키보드 포커스는 유지한다.
    private func showPanelForClipboard(animated: Bool? = nil) {
        guard !panel.isVisible, anchorGeometry() != nil else { return }
        positionPanel()
        let target = panel.frame
        let shouldAnimate = animated ?? !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard shouldAnimate else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            return
        }
        // 이동량을 메뉴 막대와의 간격 안으로 제한해 화면 상단을 침범하지 않는다.
        let distance = min(6, PanelPlacement.anchorGap)
        panel.setFrame(target.offsetBy(dx: 0, dy: distance), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        let start = Date()
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                let progress = min(1, Date().timeIntervalSince(start) / 0.22)
                let eased = 1 - pow(1 - progress, 3)
                self.panel.alphaValue = eased
                self.panel.setFrame(target.offsetBy(dx: 0, dy: distance * (1 - eased)), display: true)
                if progress == 1 {
                    timer.invalidate(); self.panelRevealTimer = nil
                    self.positionPanel()
                }
            }
        }
        panelRevealTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func hidePanel() {
        panelRevealTimer?.invalidate(); panelRevealTimer = nil
        panel.orderOut(nil)
        panel.alphaValue = 1
        positionPanel()
    }

    private func observeAnchorChanges() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(reanchorVisiblePanel),
                           name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if let button = statusItem.button {
            button.postsFrameChangedNotifications = true
            center.addObserver(self, selector: #selector(reanchorVisiblePanel),
                               name: NSView.frameDidChangeNotification, object: button)
            if let window = button.window {
                for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification,
                             NSWindow.didChangeScreenNotification] {
                    center.addObserver(self, selector: #selector(reanchorVisiblePanel), name: name, object: window)
                }
            }
        }
    }

    private func anchorGeometry() -> (anchor: NSRect, visibleFrame: NSRect)? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard anchor.width > 0, anchor.height > 0 else { return nil }
        let center = NSPoint(x: anchor.midX, y: anchor.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) else { return nil }
        // 생성 직후의 상태 막대 창은 (0, -11) 같은 임시 좌표를 가진다.
        // 실제 화면 상단 메뉴 막대에 도착하기 전에는 창 크기와 위치를 계산하지 않는다.
        let menuBarHeight = max(NSStatusBar.system.thickness, anchor.height, screen.safeAreaInsets.top)
        guard center.y >= screen.frame.maxY - menuBarHeight - 2 else { return nil }
        return (anchor, screen.visibleFrame)
    }

    @objc private func reanchorVisiblePanel() {
        if panel?.isVisible == true, panelRevealTimer == nil { positionPanel() }
    }

    private func positionPanel() {
        guard !isPositioningPanel, let geometry = anchorGeometry() else { return }
        isPositioningPanel = true
        defer { isPositioningPanel = false }
        let available = PanelPlacement.availableFrame(anchor: geometry.anchor, visibleFrame: geometry.visibleFrame)
        panel.minSize = NSSize(width: min(480, available.width), height: min(600, available.height))
        panel.maxSize = available.size
        let size = NSSize(width: max(panel.frame.width, panel.minSize.width),
                          height: max(panel.frame.height, panel.minSize.height))
        let frame = PanelPlacement.frame(anchor: geometry.anchor, visibleFrame: geometry.visibleFrame, size: size)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
    }

    func windowDidResize(_ notification: Notification) { reanchorVisiblePanel() }

    private func panelPlacementSmokeTest() -> Bool {
        guard let geometry = anchorGeometry() else {
            print("메뉴 아이콘 화면 좌표 확인 실패: 아이콘=\(statusItem.button != nil), 아이콘 창=\(statusItem.button?.window != nil), 화면 수=\(NSScreen.screens.count), 패널=\(panel.frame)")
            return false
        }
        let frame = panel.frame
        let available = PanelPlacement.availableFrame(anchor: geometry.anchor, visibleFrame: geometry.visibleFrame)
        let expected = PanelPlacement.frame(anchor: geometry.anchor, visibleFrame: geometry.visibleFrame, size: frame.size)
        let passed = geometry.visibleFrame.contains(frame) && frame.maxY <= geometry.anchor.minY
            && frame.width >= min(480, available.width) && frame.height >= min(600, available.height)
            && abs(frame.minX - expected.minX) < 1 && abs(frame.maxY - expected.maxY) < 1
        print("메뉴 아이콘 화면 좌표: \(geometry.anchor), 패널 화면 좌표: \(frame), 배치 검증: \(passed)")
        return passed
    }

    private func pasteShortcutSmokeTest() -> Bool {
        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                          timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                                          characters: "v", charactersIgnoringModifiers: "v", isARepeat: false,
                                          keyCode: 9) else { return false }
        let originalHandler = panel.onPaste
        defer { panel.onPaste = originalHandler }
        var pasteCount = 0
        panel.onPaste = { pasteCount += 1 }
        return panel.performKeyEquivalent(with: event) && pasteCount == 1
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { hidePanel(); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
        panelRevealTimer?.invalidate(); panelRevealTimer = nil
        NotificationCenter.default.removeObserver(self)
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }
}

/// 이름이 지정된 임시 pasteboard와 별도 설정 저장소만 사용한다.
@MainActor func modelInputSmokeTest() -> Bool {
    let name = "heic-smoke-\(UUID().uuidString)"
    let clipboard = NSPasteboard(name: NSPasteboard.Name(name))
    guard let defaults = UserDefaults(suiteName: name) else { return false }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    defer {
        clipboard.releaseGlobally(); defaults.removePersistentDomain(forName: name)
        try? FileManager.default.removeItem(at: folder)
    }
    do {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let first = folder.appendingPathComponent("첫 파일.heic")
        let second = folder.appendingPathComponent("두 번째.HEIC")
        let third = folder.appendingPathComponent("새 파일.heic")
        let unsupported = folder.appendingPathComponent("지원 안 함.jpg")
        try Data([1]).write(to: first); try Data([2]).write(to: second)
        try Data([3]).write(to: third); try Data([4]).write(to: unsupported)
        clipboard.writeObjects([first as NSURL])
        let model = AppModel(startClipboard: false, pasteboard: clipboard, defaults: defaults)
        var automaticPresentationCount = 0
        model.onClipboardFilesAdded = { automaticPresentationCount += 1 }
        defer { model.shutdown() }
        model.pollClipboard()
        guard model.queue.items.isEmpty, automaticPresentationCount == 0 else { return false } // 시작 이전의 복사를 무시한다.
        model.stage([first, second])
        guard model.staged.count == 2, model.queue.items.isEmpty else { return false }
        model.staged.removeAll() // 드롭 후 취소한 파일은 다시 입력할 수 있다.
        model.stage([first, second]); model.acceptStaged(convert: false)
        guard model.queue.items.count == 2, !model.active, automaticPresentationCount == 0 else { return false }
        model.paste()
        guard model.queue.items.count == 2, automaticPresentationCount == 0 else { return false }
        model.queue.remove(InputValidator.canonicalPath(first))
        model.paste()
        guard model.queue.items.count == 2, automaticPresentationCount == 0 else { return false }
        model.setClipboard(false)
        model.queue.remove(InputValidator.canonicalPath(second))
        clipboard.clearContents(); clipboard.writeObjects([second as NSURL])
        model.pollClipboard()
        guard model.queue.items.count == 1, automaticPresentationCount == 0 else { return false }
        model.setClipboard(true); model.pollClipboard()
        guard model.queue.items.count == 1, automaticPresentationCount == 0 else { return false } // 재개 시 기존 복사를 무시한다.
        clipboard.clearContents(); clipboard.writeObjects([second as NSURL])
        model.pollClipboard()
        guard model.queue.items.count == 2, !model.active, automaticPresentationCount == 1 else { return false }
        clipboard.clearContents(); clipboard.writeObjects([second as NSURL, unsupported as NSURL])
        model.pollClipboard()
        guard model.queue.items.count == 2, automaticPresentationCount == 1 else { return false }
        model.stage([third])
        clipboard.clearContents(); clipboard.writeObjects([third as NSURL])
        model.pollClipboard()
        guard model.queue.items.count == 2, automaticPresentationCount == 1 else { return false }
        model.staged.removeAll()
        clipboard.clearContents(); clipboard.writeObjects([third as NSURL, unsupported as NSURL])
        model.pollClipboard()
        guard model.queue.items.count == 3, !model.active, automaticPresentationCount == 2 else { return false }
        model.settings.outputDirectory = folder.path
        model.setClipboard(false)
        guard AppSettings.load(from: defaults).outputDirectory == folder.path,
              !AppSettings.load(from: defaults).clipboardEnabled else { return false }
        print("드롭·붙여넣기·중복·거절·감지 재개·자동 표시 이벤트·설정 기억 확인 완료")
        return true
    } catch { fputs("입력 모델 검증 실패: \(error.localizedDescription)\n", stderr); return false }
}

/// 합성 HEIC만 사용하여 설치된 번들의 worker와 프로토콜을 실제 변환까지 확인한다.
func smokeTest() -> Int32 {
    guard fileThumbnailSmokeTest() else { return 1 }
    guard let resources = Bundle.main.resourceURL else { return 1 }
    let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("heic-smoke-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) } catch { return 1 }
    let source = folder.appendingPathComponent("한글 합성 사진.heic")
    guard let context = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
          let image = context.makeImage(),
          let encoder = CGImageDestinationCreateWithURL(source as CFURL, UTType.heic.identifier as CFString, 1, nil) else { return 1 }
    CGImageDestinationAddImage(encoder, image, nil)
    guard CGImageDestinationFinalize(encoder) else { return 1 }
    var settings = AppSettings()
    settings.outputDirectory = folder.appendingPathComponent("결과 폴더").path
    let job = ConversionJob(files: [InputValidator.canonicalPath(source)], settings: settings)
    let process = Process()
    process.executableURL = resources.appendingPathComponent("worker/heic-worker")
    process.environment = ["PATH": "/usr/bin:/bin", "HOME": folder.path, "PYTHONUTF8": "1"]
    let input = Pipe(), output = Pipe(), errors = Pipe()
    process.standardInput = input; process.standardOutput = output; process.standardError = errors
    let state = SmokeState(job: job, input: input.fileHandleForWriting)
    output.fileHandleForReading.readabilityHandler = { handle in state.receive(handle.availableData) }
    errors.fileHandleForReading.readabilityHandler = { handle in _ = handle.availableData }
    do {
        try process.run()
        try input.fileHandleForWriting.write(contentsOf: WorkerRequest(command: "prepare", job: job).line())
        _ = state.done.wait(timeout: .now() + 30)
    } catch { fputs("내장 worker 실행 실패: \(error.localizedDescription)\n", stderr) }
    output.fileHandleForReading.readabilityHandler = nil
    errors.fileHandleForReading.readabilityHandler = nil
    try? input.fileHandleForWriting.close()
    if process.isRunning { process.terminate(); process.waitUntilExit() }
    let passed = state.succeeded
    if !passed { fputs("worker smoke 검증 실패: \(state.failure)\n", stderr) }
    if passed { print("내장 worker 합성 HEIC 변환 및 프로토콜 확인 완료") }
    return passed ? 0 : 1
}

final class SmokeState: @unchecked Sendable {
    let done = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var buffer = JSONLineBuffer()
    private var prepared = false
    private var converted = false
    private var passed = false
    private(set) var failure = "응답 없음 또는 시간 초과"
    private let job: ConversionJob
    private let input: FileHandle
    init(job: ConversionJob, input: FileHandle) { self.job = job; self.input = input }
    var succeeded: Bool { lock.lock(); defer { lock.unlock() }; return passed }
    func receive(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard !data.isEmpty else { done.signal(); return }
        do {
            for event in try buffer.append(data) {
                guard event.jobID == job.id else { failure = "작업 ID 불일치"; done.signal(); return }
                switch event.event {
                case "prepared":
                    guard event.files == job.files, event.total == 1, event.rejected?.isEmpty != false else { failure = "준비 결과 불일치: 기대 \(job.files), 실제 \(String(describing: event.files)), \(String(describing: event.rejected))"; done.signal(); return }
                    prepared = true
                    try input.write(contentsOf: WorkerRequest(command: "run", job: job).line())
                case "file_succeeded":
                    guard let destination = event.destination,
                          CGImageSourceCreateWithURL(URL(fileURLWithPath: destination) as CFURL, nil) != nil else { done.signal(); return }
                    converted = true
                case "completed":
                    passed = prepared && converted && event.succeeded == 1 && event.failed == 0
                    done.signal()
                case "error", "file_failed", "cancelled": failure = event.message ?? event.error ?? event.event; done.signal()
                default: break
                }
            }
        } catch { failure = error.localizedDescription; done.signal() }
    }
}

if CommandLine.arguments.contains("--smoke-test") {
    let result = smokeTest()
    if result != 0 { exit(result) }
}
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
