import AppKit
import Combine
import ConverterKit

@MainActor final class AppModel: ObservableObject {
    @Published var settings: AppSettings { didSet { settings.save(to: settingsStore) } }
    @Published var queue = QueueState() { didSet { pruneDuplicateNotices() } }
    @Published var dropTargeted = false
    @Published var staged: [URL] = [] { didSet { pruneDuplicateNotices() } }
    @Published var notices: [InputRejection] = []
    @Published var message = "HEIC 파일을 드롭하거나 Finder에서 복사하세요."
    @Published var clipboardMessage: String?
    @Published var cancelling = false
    private let worker = WorkerClient()
    private var timer: Timer?
    private let pasteboard: NSPasteboard
    private let settingsStore: UserDefaults
    private var gate: ClipboardGate
    private var duplicateNoticePaths: [String: String] = [:]
    /// 자동 감지로 새 파일을 추가했을 때만 패널 표시를 요청한다.
    var onClipboardFilesAdded: (() -> Void)?
    var waitingCount: Int { queue.waitingCount }
    var active: Bool { queue.activeJob != nil }

    init(startClipboard: Bool = true, pasteboard: NSPasteboard = .general, defaults: UserDefaults = .standard) {
        self.pasteboard = pasteboard; self.settingsStore = defaults
        self.settings = AppSettings.load(from: defaults)
        self.gate = ClipboardGate(changeCount: pasteboard.changeCount)
        worker.onEvent = { [weak self] event in self?.receive(event) }
        worker.onFailure = { [weak self] error in
            guard let self else { return }
            self.queue.failActive(error); self.cancelling = false; self.message = error
        }
        guard startClipboard else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollClipboard() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
    func setClipboard(_ enabled: Bool) {
        settings.clipboardEnabled = enabled
        gate.resume(changeCount: pasteboard.changeCount)
        clipboardMessage = nil
    }
    func pollClipboard() {
        var denied = false
        if #available(macOS 15.4, *) { denied = pasteboard.accessBehavior == .alwaysDeny }
        if gate.shouldRead(changeCount: pasteboard.changeCount, enabled: settings.clipboardEnabled, accessDenied: denied) {
            readClipboard(manual: false)
        }
        if gate.denied { clipboardMessage = "클립보드 접근이 거부되었습니다. 파일을 드롭하거나 직접 붙여넣으세요. 허용 후 감지를 다시 켜세요." }
    }
    func paste() { readClipboard(manual: true) }
    private func readClipboard(manual: Bool) {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if manual { gate.resume(changeCount: pasteboard.changeCount) }
        guard !urls.isEmpty else {
            if manual { message = "붙여넣을 로컬 HEIC 파일이 없습니다. Finder에서 파일을 복사하세요." }
            return
        }
        let result = InputValidator.validate(urls, excluding: queue.knownPaths.union(staged.map(\.path)))
        queue.add(result.accepted); setNotices(result.rejected)
        if !result.accepted.isEmpty {
            message = "\(result.accepted.count)개 파일을 대기 목록에 추가했습니다."
            if !manual { onClipboardFilesAdded?() }
        }
    }
    func stage(_ urls: [URL], updateNotices: Bool = true) {
        let result = InputValidator.validate(urls, excluding: queue.knownPaths.union(staged.map(\.path)))
        staged.append(contentsOf: result.accepted)
        if updateNotices { setNotices(result.rejected) }
    }
    func acceptStaged(convert: Bool) {
        let paths = staged.map(\.path)
        queue.add(staged); staged.removeAll()
        if convert { schedule(paths) }
    }
    func remove(_ path: String) {
        // 표시 중인 항목의 ID는 파일 경로가 나중에 교체되어도 바뀌지 않는다.
        let itemID = queue.knownPaths.contains(path) ? path : InputValidator.canonicalPath(URL(fileURLWithPath: path))
        queue.remove(itemID)
    }
    func clearCompleted() { queue.clearCompleted() }
    func cancelStaged() { staged.removeAll() }

    /// 중복 안내는 목록 상태에 종속된다. 지원 형식·권한 등 다른 입력 오류는 보존한다.
    private func pruneDuplicateNotices() {
        let listedPaths = queue.knownPaths.union(staged.map(\.path))
        let remaining = notices.filter { rejection in
            rejection.reason != "이미 목록에 있는 파일입니다."
                || listedPaths.contains(duplicateNoticePaths[rejection.path] ?? rejection.path)
        }
        if remaining != notices { notices = remaining }
        let remainingPaths = Set(remaining.map(\.path))
        duplicateNoticePaths = duplicateNoticePaths.filter { remainingPaths.contains($0.key) }
    }
    private func setNotices(_ rejections: [InputRejection]) {
        // 검증 시점의 동일 파일 관계를 기억해 외부 파일 교체로 안내 대상이 바뀌지 않게 한다.
        duplicateNoticePaths = [:]
        for rejection in rejections where rejection.reason == "이미 목록에 있는 파일입니다." {
            duplicateNoticePaths[rejection.path] = InputValidator.canonicalPath(URL(fileURLWithPath: rejection.path))
        }
        notices = rejections
    }
    func startWaiting() { schedule(queue.items.filter { $0.status == .waiting }.map(\.id)) }
    func retryFailures() { schedule(queue.items.filter { $0.status == .failed }.map(\.id)) }
    func retry(_ path: String) { schedule([path]) }
    private func schedule(_ paths: [String]) {
        queue.schedule(paths: paths, settings: settings)
        startNext()
    }
    private func startNext() {
        guard let job = queue.next() else { return }
        cancelling = false
        do {
            try worker.start()
            try worker.send(WorkerRequest(command: "prepare", job: job))
            message = "저장 위치와 \(job.files.count)개 파일을 확인하고 있습니다."
        } catch { worker.fail(error.localizedDescription) }
    }
    func cancel() {
        guard let job = queue.activeJob, !cancelling else { return }
        do { try worker.send(WorkerRequest(command: "cancel", job: job)); cancelling = true; message = "현재 파일 저장 후 취소합니다." }
        catch { worker.fail(error.localizedDescription) }
    }
    private func receive(_ event: WorkerEvent) {
        guard let job = queue.activeJob else { return }
        guard job.id == event.jobID else { worker.fail("worker 응답의 작업 ID가 일치하지 않습니다."); return }
        switch event.event {
        case "prepared":
            for rejection in event.rejected ?? [] { queue.update(path: rejection.source, status: .failed, detail: rejection.reason) }
            if cancelling { return }
            do { try worker.send(WorkerRequest(command: "run", job: job)) }
            catch { worker.fail(error.localizedDescription) }
        case "file_started":
            if let path = event.source { queue.update(path: path, status: .running) }
            message = "\(event.index ?? 0)/\(event.total ?? job.files.count) 변환 중"
        case "file_succeeded", "file_skipped", "file_failed":
            guard let path = event.source else { return }
            let status: FileStatus = event.event == "file_succeeded" ? .succeeded : event.event == "file_skipped" ? .skipped : .failed
            var detail = event.error.map { "\(event.errorCode ?? "conversion_error"): \($0)" }
            if status == .failed, ["output_permission", "output_unavailable"].contains(event.errorCode ?? "") {
                detail = (detail ?? "저장 실패") + " 저장 위치를 변경한 뒤 실패 파일을 재시도하세요."
            }
            if status == .succeeded { detail = event.hdrApplied == true ? "HDR 적용" : event.sdrReason }
            if status == .skipped { detail = "동일한 이름의 결과가 있어 건너뛰었습니다." }
            queue.update(path: path, status: status, detail: detail, destination: event.destination)
        case "completed", "cancelled":
            message = "\(event.event == "cancelled" ? "취소" : "완료"): 성공 \(event.succeeded ?? 0), 건너뜀 \(event.skipped ?? 0), 실패 \(event.failed ?? 0)"
            queue.finish(); cancelling = false; startNext()
        case "error":
            let error = "\(event.errorCode ?? "worker_error"): \(event.message ?? "작업을 시작하지 못했습니다.")"
            queue.failActive(error); cancelling = false; message = error + " 저장 경로 또는 옵션을 확인하고, 저장 폴더 오류라면 저장 위치를 변경하세요."
        default: break
        }
    }
    func chooseOutput() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true; panel.allowsMultipleSelection = false
        panel.prompt = "저장 위치 선택"
        if panel.runModal() == .OK, let url = panel.url { settings.outputDirectory = url.path }
    }
    func openOutput() { NSWorkspace.shared.open(URL(fileURLWithPath: settings.outputDirectory)) }
    func reveal(_ path: String) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
    func shutdown() {
        timer?.invalidate(); timer = nil; worker.stop()
        FileThumbnailStore.shared.removeAllCachedThumbnails()
    }
}
