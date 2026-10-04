import AppKit
import SwiftUI
import Combine
import ConverterKit
import ImageIO
import UniformTypeIdentifiers

final class DropPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel(startClipboard: !CommandLine.arguments.contains("--smoke-test"))
    private var statusItem: NSStatusItem!
    private var panel: DropPanel!
    private var countSubscription: AnyCancellable?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.badge.arrow.down", accessibilityDescription: "HEIC Converter")
            button.imagePosition = .imageLeading
            button.target = self; button.action = #selector(togglePanel)
            button.toolTip = "HEIC Converter · 클릭하여 패널 열기 또는 숨기기"
        }
        panel = DropPanel(contentRect: NSRect(x: 0, y: 0, width: 570, height: 760),
                          styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
        panel.title = "HEIC Converter"
        panel.identifier = NSUserInterfaceItemIdentifier("HEICConverter.DropPanel")
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 570, height: 710)
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: PanelView(model: model))
        panel.center()
        countSubscription = model.$queue.sink { [weak self] queue in self?.statusItem.button?.title = " \(queue.waitingCount)" }
        togglePanel()
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                var passed = panel.isVisible && !panel.hidesOnDeactivate && panel.level == .floating
                togglePanel(); passed = passed && !panel.isVisible
                togglePanel(); passed = passed && panel.isVisible
                NSApp.deactivate()
                passed = passed && panel.isVisible
                _ = windowShouldClose(panel); passed = passed && !panel.isVisible
                togglePanel(); passed = passed && panel.isVisible
                model.shutdown()
                print(passed ? "패널 표시·숨김·포커스 유지 확인 완료" : "패널 검증 실패")
                exit(passed ? 0 : 1)
            }
        }
    }
    @objc func togglePanel() {
        if panel.isVisible { panel.orderOut(nil) }
        else { NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil) }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }
}

/// 합성 HEIC만 사용하여 설치된 번들의 worker와 프로토콜을 실제 변환까지 확인한다.
func smokeTest() -> Int32 {
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
    let job = ConversionJob(files: [source.path], settings: settings)
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
    private let job: ConversionJob
    private let input: FileHandle
    init(job: ConversionJob, input: FileHandle) { self.job = job; self.input = input }
    var succeeded: Bool { lock.lock(); defer { lock.unlock() }; return passed }
    func receive(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        guard !data.isEmpty else { done.signal(); return }
        do {
            for event in try buffer.append(data) {
                guard event.jobID == job.id else { done.signal(); return }
                switch event.event {
                case "prepared":
                    guard event.files == job.files, event.total == 1, event.rejected?.isEmpty != false else { done.signal(); return }
                    prepared = true
                    try input.write(contentsOf: WorkerRequest(command: "run", job: job).line())
                case "file_succeeded":
                    guard let destination = event.destination,
                          CGImageSourceCreateWithURL(URL(fileURLWithPath: destination) as CFURL, nil) != nil else { done.signal(); return }
                    converted = true
                case "completed":
                    passed = prepared && converted && event.succeeded == 1 && event.failed == 0
                    done.signal()
                case "error", "file_failed", "cancelled": done.signal()
                default: break
                }
            }
        } catch { done.signal() }
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
