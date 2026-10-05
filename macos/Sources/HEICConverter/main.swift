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
    private var inputSubscription: AnyCancellable?
    private var inputLayoutScheduled = false
    private var userPreferredHeight = PanelPlacement.defaultSize.height
    private var lastPositionedHeight = PanelPlacement.defaultSize.height
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
        panel = DropPanel(contentRect: NSRect(origin: .zero, size: PanelPlacement.defaultSize),
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
        panel.minSize = PanelPlacement.minimumSize
        panel.delegate = self
        let contentView = NSHostingView(rootView: PanelView(model: model, onClose: { [weak self] in
            self?.hidePanel()
        }))
        // 스크롤 콘텐츠의 intrinsic 높이가 창 크기를 덮어쓰지 않도록 한다.
        contentView.sizingOptions = []
        panel.contentView = contentView
        panel.setContentSize(PanelPlacement.defaultSize)
        model.onClipboardFilesAdded = { [weak self] in self?.showPanelForClipboard() }
        observeAnchorChanges()
        countSubscription = model.$queue.sink { [weak self] queue in
            self?.statusItem.button?.title = " \(queue.waitingCount)"
            self?.reanchorVisiblePanel()
        }
        inputSubscription = model.$queue.map { $0.items.map(\.id) }.removeDuplicates()
            .combineLatest(model.$staged.map { $0.map(\.path) }.removeDuplicates())
            .sink { [weak self] _ in self?.scheduleInputLayout() }
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
            if CommandLine.arguments.contains("--smoke-test") { Task { await runPanelSmokeTest() } }
        }
    }

    private func waitForPanelSmokeReadiness(until deadline: Date) {
        if panel.isVisible, anchorGeometry() != nil {
            positionPanel()
            Task { await runPanelSmokeTest() }
        } else if Date() < deadline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                waitForPanelSmokeReadiness(until: deadline)
            }
        } else {
            print("패널 준비 시간 초과: 표시=\(panel.isVisible), 아이콘=\(statusItem.button != nil), 아이콘 창=\(statusItem.button?.window != nil), 화면 수=\(NSScreen.screens.count)")
            Task { await runPanelSmokeTest() }
        }
    }

    private func runPanelSmokeTest() async {
        var passed = true
        func check(_ label: String, _ condition: Bool) {
            print("패널 검증 [\(label)]: \(condition ? "성공" : "실패")")
            if !condition { passed = false }
        }
        check("최초 표시", panel.isVisible)
        check("포커스 상실 시 유지 설정", !panel.hidesOnDeactivate)
        check("플로팅 레벨", panel.level == .floating)
        check("최초 배치와 크기", panelPlacementSmokeTest())
        if let geometry = anchorGeometry() {
            let expected = PanelPlacement.frame(anchor: geometry.anchor, visibleFrame: geometry.visibleFrame,
                                                size: PanelPlacement.defaultSize)
            check("간결한 기본 크기", panel.frame.size == expected.size)
        }
        check("입력 모델", modelInputSmokeTest())
        check("파일 추가 높이와 수동 크기 보존", await inputPanelSizingSmokeTest())
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
        try? await Task.sleep(for: .milliseconds(350))
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

    private func scheduleInputLayout() {
        guard !inputLayoutScheduled else { return }
        inputLayoutScheduled = true
        // @Published는 willSet에서 발행한다. 드롭→대기 목록 이동까지 합쳐서 계산한다.
        let timer = Timer(timeInterval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.inputLayoutScheduled = false
                if self.panelRevealTimer == nil { self.positionPanel() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func positionPanel() {
        guard !isPositioningPanel, let geometry = anchorGeometry() else { return }
        isPositioningPanel = true
        defer { isPositioningPanel = false }
        let available = PanelPlacement.availableFrame(anchor: geometry.anchor, visibleFrame: geometry.visibleFrame)
        panel.minSize = NSSize(width: min(PanelPlacement.minimumSize.width, available.width),
                               height: min(PanelPlacement.minimumSize.height, available.height))
        panel.maxSize = available.size
        let size = NSSize(width: max(panel.frame.width, panel.minSize.width),
                          height: max(userPreferredHeight, PanelPlacement.preferredHeight(
                            fileCount: model.queue.items.count, stagedCount: model.staged.count)))
        let frame = PanelPlacement.frame(anchor: geometry.anchor, visibleFrame: geometry.visibleFrame, size: size)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        lastPositionedHeight = panel.frame.height
    }

    func windowDidResize(_ notification: Notification) {
        guard !isPositioningPanel, panelRevealTimer == nil else { return }
        if abs(panel.frame.height - lastPositionedHeight) > 0.5 {
            userPreferredHeight = panel.frame.height
        }
        reanchorVisiblePanel()
    }

    private func panelPlacementSmokeTest() -> Bool {
        guard let geometry = anchorGeometry() else {
            print("메뉴 아이콘 화면 좌표 확인 실패: 아이콘=\(statusItem.button != nil), 아이콘 창=\(statusItem.button?.window != nil), 화면 수=\(NSScreen.screens.count), 패널=\(panel.frame)")
            return false
        }
        let frame = panel.frame
        let available = PanelPlacement.availableFrame(anchor: geometry.anchor, visibleFrame: geometry.visibleFrame)
        let expected = PanelPlacement.frame(anchor: geometry.anchor, visibleFrame: geometry.visibleFrame, size: frame.size)
        let passed = geometry.visibleFrame.contains(frame) && frame.maxY <= geometry.anchor.minY
            && frame.width >= min(PanelPlacement.minimumSize.width, available.width)
            && frame.height >= min(PanelPlacement.minimumSize.height, available.height)
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

    private func inputPanelSizingSmokeTest() async -> Bool {
        let originalQueue = model.queue
        let originalStaged = model.staged
        let originalHeight = userPreferredHeight
        let originalWidth = panel.frame.width
        defer {
            model.queue = originalQueue; model.staged = originalStaged
            userPreferredHeight = originalHeight
            panel.setContentSize(NSSize(width: originalWidth, height: originalHeight))
            positionPanel()
        }
        func settle(_ duration: TimeInterval = 0.08) async {
            // 중첩 RunLoop 대신 실행권을 반환해 실제 AppKit 이벤트 루프가 갱신하도록 한다.
            try? await Task.sleep(for: .seconds(duration))
        }
        func expectedHeight() -> CGFloat {
            guard let geometry = anchorGeometry() else { return 0 }
            return min(PanelPlacement.availableFrame(anchor: geometry.anchor, visibleFrame: geometry.visibleFrame).height,
                       max(userPreferredHeight, PanelPlacement.preferredHeight(fileCount: model.queue.items.count,
                                                                               stagedCount: model.staged.count)))
        }
        func checkHeight(_ label: String) -> Bool {
            let result = panel.frame.height == expectedHeight()
            print("높이 검증 [\(label)]: 실제 \(panel.frame.height), 기대 \(expectedHeight()), 수동 \(userPreferredHeight)")
            return result
        }
        let top = panel.frame.maxY
        let urls = (1...4).map { URL(fileURLWithPath: "/tmp/heic-panel-size-\($0).heic") }
        model.queue.add([urls[0]]); await settle()
        guard checkHeight("첫 파일"), panel.frame.maxY == top,
              panel.frame.width == originalWidth else { return false }
        model.queue.add(Array(urls.dropFirst())); await settle()
        guard checkHeight("여러 파일"), panelPlacementSmokeTest() else { return false }
        panel.setContentSize(NSSize(width: originalWidth + 20, height: panel.frame.height)); await settle()
        guard userPreferredHeight == originalHeight else { return false }
        panel.setContentSize(NSSize(width: originalWidth, height: panel.frame.height)); await settle()
        let height = panel.frame.height
        model.queue.update(path: urls[0].path, status: .running); await settle()
        guard panel.frame.height == height else { return false }
        model.queue = QueueState(); await settle()
        guard checkHeight("목록 비움") else { return false }
        model.staged = urls; await settle()
        guard checkHeight("드롭 선택") else { return false }
        model.queue.add(urls); model.staged = []; await settle()
        guard checkHeight("대기 이동") else { return false }
        model.queue = QueueState(); await settle()
        panel.setContentSize(NSSize(width: originalWidth + 20, height: 730)); await settle()
        let manualHeight = panel.frame.height
        print("수동 크기 검증: \(panel.frame)")
        model.queue.add([urls[0]]); await settle()
        guard panel.frame.height == manualHeight, panel.frame.width == originalWidth + 20 else { return false }
        hidePanel()
        model.queue.add(Array(urls.dropFirst()))
        showPanelForClipboard(animated: true)
        model.queue.add([URL(fileURLWithPath: "/tmp/heic-panel-size-5.heic")])
        await settle(0.35)
        return panel.frame.height == expectedHeight() && panelPlacementSmokeTest()
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
        guard duplicateNoticeSmokeTest(first: first, second: second, unsupported: unsupported,
                                       clipboard: clipboard, defaults: defaults) else { return false }
        guard bulkRemovalSmokeTest(first: first, second: second, third: third, unsupported: unsupported,
                                   clipboard: clipboard, defaults: defaults) else { return false }
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
        // 화면에서 사용하는 중첩 값 변경도 저장되며 새 모델이 마지막 설정을 복구해야 한다.
        for (format, quality, compression, metadata, conflict) in [
            ("png", QualityPreset.medium, PNGCompressionPreset.small, "strip", "skip"),
            ("jpeg", QualityPreset.raw, PNGCompressionPreset.none, "preserve", "overwrite"),
        ] {
            let output = folder.appendingPathComponent("설정 복구 \(format)").path
            model.settings.options.outputFormat = format
            model.settings.options.qualityPreset = quality
            model.settings.options.pngCompressionPreset = compression
            model.settings.options.metadata = metadata
            model.settings.options.onConflict = conflict
            model.settings.outputDirectory = output
            let restored = AppModel(startClipboard: false, pasteboard: clipboard, defaults: defaults)
            let recovered = restored.settings
            restored.shutdown()
            guard recovered.options.outputFormat == format,
                  recovered.options.jpegQuality == quality.jpegQuality,
                  recovered.options.pngCompression == compression.compressionLevel,
                  recovered.options.metadata == metadata,
                  recovered.options.onConflict == conflict,
                  recovered.outputDirectory == output,
                  !recovered.clipboardEnabled else { return false }
        }
        print("드롭·붙여넣기·중복·거절·감지 재개·자동 표시 이벤트·설정 기억 확인 완료")
        return true
    } catch { fputs("입력 모델 검증 실패: \(error.localizedDescription)\n", stderr); return false }
}

/// 일괄 제거는 목록과 중복 안내만 변경하고 예약 작업·원본·결과 파일을 보존한다.
@MainActor private func bulkRemovalSmokeTest(first: URL, second: URL, third: URL, unsupported: URL,
                                            clipboard: NSPasteboard, defaults: UserDefaults) -> Bool {
    let model = AppModel(startClipboard: false, pasteboard: clipboard, defaults: defaults)
    defer { model.shutdown() }
    let ids = [first, second, third].map(InputValidator.canonicalPath)
    let duplicateReason = "이미 목록에 있는 파일입니다."
    func duplicatePaths() -> Set<String> {
        Set(model.notices.filter { $0.reason == duplicateReason }.map(\.path))
    }
    model.stage([first, second, third]); model.acceptStaged(convert: false)
    model.queue.schedule(paths: [ids[0]], settings: model.settings)
    guard let activeJob = model.queue.next() else { return false }
    model.queue.update(path: ids[0], status: .running)
    model.queue.schedule(paths: [ids[1]], settings: model.settings)
    guard let scheduledJob = model.queue.jobs.first else { return false }
    model.queue.update(path: ids[2], status: .failed)
    model.stage([first, second, third, unsupported])
    guard duplicatePaths() == Set([first, second, third].map(\.path)) else { return false }
    model.removeSelected(Set(ids))
    guard model.queue.knownPaths == Set(ids.prefix(2)),
          duplicatePaths() == Set([first.path, second.path]),
          model.queue.activeJob?.id == activeJob.id,
          model.queue.jobs.map(\.id) == [scheduledJob.id] else { return false }
    do {
        let folder = third.deletingLastPathComponent()
        let completed = folder.appendingPathComponent("일괄 제거 완료.heic")
        let result = folder.appendingPathComponent("일괄 제거 결과.jpeg")
        try Data([7]).write(to: completed); try Data([8]).write(to: result)
        model.stage([completed], updateNotices: false); model.acceptStaged(convert: false)
        model.queue.update(path: InputValidator.canonicalPath(completed), status: .succeeded, destination: result.path)
        model.removeAll()
        guard model.queue.knownPaths == Set(ids.prefix(2)),
              duplicatePaths() == Set([first.path, second.path]),
              model.queue.activeJob?.id == activeJob.id,
              model.queue.jobs.map(\.id) == [scheduledJob.id] else { return false }
        model.queue.finish(); model.removeAll()
        guard model.queue.knownPaths == [ids[1]], duplicatePaths() == [second.path],
              model.queue.next()?.id == scheduledJob.id else { return false }
        model.queue.update(path: ids[1], status: .failed); model.queue.finish(); model.removeAll()
        guard model.queue.items.isEmpty, duplicatePaths().isEmpty,
              model.notices == [InputRejection(path: unsupported.path, reason: "확장자가 .heic인 파일만 지원합니다.")],
              try Data(contentsOf: first) == Data([1]),
              try Data(contentsOf: second) == Data([2]),
              try Data(contentsOf: third) == Data([3]),
              try Data(contentsOf: completed) == Data([7]),
              try Data(contentsOf: result) == Data([8]) else { return false }
    } catch { return false }
    print("선택·전체 목록 제거·예약 작업 보존·중복 안내 정리·원본과 결과 파일 보존 확인 완료")
    return true
}

/// 목록에서 사라진 파일의 중복 안내만 정리하고 다른 입력 오류는 유지한다.
@MainActor private func duplicateNoticeSmokeTest(first: URL, second: URL, unsupported: URL,
                                                clipboard: NSPasteboard, defaults: UserDefaults) -> Bool {
    let model = AppModel(startClipboard: false, pasteboard: clipboard, defaults: defaults)
    defer { model.shutdown() }
    let duplicateReason = "이미 목록에 있는 파일입니다."
    let formatReason = "확장자가 .heic인 파일만 지원합니다."
    func hasDuplicate(_ file: URL) -> Bool {
        model.notices.contains { $0.path == file.path && $0.reason == duplicateReason }
    }
    func hasFormatError() -> Bool {
        model.notices.contains { $0.path == unsupported.path && $0.reason == formatReason }
    }
    model.stage([first]); model.acceptStaged(convert: false)
    model.stage([first, unsupported])
    guard hasDuplicate(first), hasFormatError() else { return false }
    // 상위 폴더의 심볼릭 링크를 포함하는 원래 경로도 canonical 목록에서 제거한다.
    model.remove(first.path)
    guard model.queue.items.isEmpty, !hasDuplicate(first), hasFormatError() else { return false }

    model.stage([second])
    model.stage([second, unsupported])
    guard hasDuplicate(second), hasFormatError() else { return false }
    model.cancelStaged()
    guard model.staged.isEmpty, !hasDuplicate(second), hasFormatError() else { return false }

    model.stage([first]); model.acceptStaged(convert: false)
    model.stage([first, unsupported])
    let path = InputValidator.canonicalPath(first)
    model.queue.schedule(paths: [path], settings: model.settings)
    model.remove(path)
    guard model.queue.items.count == 1, model.queue.items[0].status.locked,
          hasDuplicate(first), hasFormatError() else { return false }
    model.queue.update(path: path, status: .succeeded)
    model.clearCompleted()
    guard model.queue.items.isEmpty, !hasDuplicate(first), hasFormatError() else { return false }

    // 선택 파일의 안내는 같은 파일이 대기 목록에 남아 있으면 여전히 유효하다.
    model.stage([first]); model.acceptStaged(convert: false)
    model.stage([first, second, unsupported])
    model.cancelStaged()
    guard hasDuplicate(first), hasFormatError(), model.queue.items.count == 1 else { return false }
    model.remove(path)
    guard !hasDuplicate(first), hasFormatError() else { return false }
    // 느린 이전 드롭은 파일을 추가하되 최신 드롭의 오류 안내를 덮지 않는다.
    model.stage([unsupported])
    model.stage([second], updateNotices: false)
    guard model.staged.count == 1, hasFormatError() else { return false }
    model.cancelStaged()
    do {
        let folder = first.deletingLastPathComponent()
        let source = folder.appendingPathComponent("교체 전 파일.heic")
        let target = folder.appendingPathComponent("링크 대상 파일.heic")
        try Data([5]).write(to: source); try Data([6]).write(to: target)
        let sourceID = InputValidator.canonicalPath(source)
        let targetID = InputValidator.canonicalPath(target)
        model.stage([source, target]); model.acceptStaged(convert: false)
        model.stage([source, unsupported])
        guard hasDuplicate(source), hasFormatError() else { return false }
        try FileManager.default.removeItem(at: source)
        try FileManager.default.createSymbolicLink(at: source, withDestinationURL: target)
        model.remove(sourceID)
        guard model.queue.knownPaths == [targetID], !hasDuplicate(source), hasFormatError() else { return false }
        model.remove(targetID)
    } catch { return false }
    print("중복 안내 목록 제거·선택 취소·완료 정리·잠금·다른 입력 오류 보존 확인 완료")
    return true
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
