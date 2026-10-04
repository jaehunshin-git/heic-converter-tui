import AppKit
import Combine
import ConverterKit

@MainActor final class AppModel: ObservableObject {
    @Published var settings = AppSettings.load() { didSet { settings.save() } }
    @Published var queue = QueueState()
    @Published var dropTargeted = false
    @Published var staged: [URL] = []
    @Published var notices: [InputRejection] = []
    @Published var message = "HEIC 파일을 드롭하거나 Finder에서 복사하세요."
    @Published var clipboardMessage: String?
    @Published var cancelling = false
    private let worker = WorkerClient()
    private var timer: Timer?
    private var gate = ClipboardGate(changeCount: NSPasteboard.general.changeCount)
    var waitingCount: Int { queue.waitingCount }
    var active: Bool { queue.activeJob != nil }

    init(startClipboard: Bool = true) {
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
        gate.resume(changeCount: NSPasteboard.general.changeCount)
        clipboardMessage = nil
    }
    private func pollClipboard() {
        let pasteboard = NSPasteboard.general
        var denied = false
        if #available(macOS 15.4, *) { denied = pasteboard.accessBehavior == .alwaysDeny }
        if gate.shouldRead(changeCount: pasteboard.changeCount, enabled: settings.clipboardEnabled, accessDenied: denied) {
            readClipboard(manual: false)
        }
        if gate.denied { clipboardMessage = "클립보드 접근이 거부되었습니다. 파일을 드롭하거나 직접 붙여넣으세요. 허용 후 감지를 다시 켜세요." }
    }
    func paste() { readClipboard(manual: true) }
    private func readClipboard(manual: Bool) {
        let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if manual { gate.resume(changeCount: NSPasteboard.general.changeCount) }
        guard !urls.isEmpty else {
            if manual { message = "붙여넣을 로컬 HEIC 파일이 없습니다. Finder에서 파일을 복사하세요." }
            return
        }
        let result = InputValidator.validate(urls, excluding: queue.knownPaths.union(staged.map(\.path)))
        queue.add(result.accepted); notices = result.rejected
        if !result.accepted.isEmpty { message = "\(result.accepted.count)개 파일을 대기 목록에 추가했습니다." }
    }
    func stage(_ urls: [URL]) {
        let result = InputValidator.validate(urls, excluding: queue.knownPaths.union(staged.map(\.path)))
        staged.append(contentsOf: result.accepted); notices = result.rejected
    }
    func acceptStaged(convert: Bool) {
        let paths = staged.map(\.path)
        queue.add(staged); staged.removeAll()
        if convert { schedule(paths) }
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
        } catch { queue.failActive(error.localizedDescription); message = error.localizedDescription }
    }
    func cancel() {
        guard let job = queue.activeJob, !cancelling else { return }
        do { try worker.send(WorkerRequest(command: "cancel", job: job)); cancelling = true; message = "현재 파일 저장 후 취소합니다." }
        catch { queue.failActive(error.localizedDescription); message = error.localizedDescription }
    }
    private func receive(_ event: WorkerEvent) {
        guard let job = queue.activeJob else { return }
        guard job.id == event.jobID else { worker.fail("worker 응답의 작업 ID가 일치하지 않습니다."); return }
        switch event.event {
        case "prepared":
            for rejection in event.rejected ?? [] { queue.update(path: rejection.source, status: .failed, detail: rejection.reason) }
            if cancelling { return }
            do { try worker.send(WorkerRequest(command: "run", job: job)) }
            catch { queue.failActive(error.localizedDescription); message = error.localizedDescription }
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
    func shutdown() { timer?.invalidate(); timer = nil; worker.stop() }
}
