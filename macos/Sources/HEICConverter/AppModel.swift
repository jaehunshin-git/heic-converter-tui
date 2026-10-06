import AppKit
import Combine
import ConverterKit
import UniformTypeIdentifiers

@MainActor final class AppModel: ObservableObject {
    @Published var settings: AppSettings { didSet { settings.save(to: settingsStore) } }
    @Published var queue = QueueState() { didSet { pruneDuplicateNotices() } }
    @Published var dropTargeted = false
    @Published var staged: [URL] = [] { didSet { pruneDuplicateNotices() } }
    @Published var notices: [InputRejection] = []
    @Published var message = "HEIC 파일을 드롭하거나 클릭해 선택하세요."
    @Published var clipboardMessage: String?
    @Published var cancelling = false
    @Published var selectedDestination: ConversionDestination = .files
    @Published private(set) var terminating = false
    private let worker = WorkerClient()
    private let clipboardResults: ClipboardResultStore
    private var clipboardChangeCounts: [String: Int] = [:]
    private var convertedClipboardFiles: [String: URL] = [:]
    private var cancellationJobIDs: [String] = []
    private var timer: Timer?
    private let pasteboard: NSPasteboard
    private let settingsStore: UserDefaults
    private var gate: ClipboardGate
    private var duplicateNoticePaths: [String: String] = [:]
    private var awaitingPreparation = false
    private var preparationRejectedCount = 0
    /// 자동 감지로 새 파일을 추가했을 때만 패널 표시를 요청한다.
    var onClipboardFilesAdded: (() -> Void)?
    var waitingCount: Int { queue.waitingCount }
    var active: Bool { queue.activeJob != nil }

    init(startClipboard: Bool = true, pasteboard: NSPasteboard = .general, defaults: UserDefaults = .standard,
         clipboardRoot: URL? = nil) {
        self.pasteboard = pasteboard; self.settingsStore = defaults
        self.clipboardResults = ClipboardResultStore(pasteboard: pasteboard, root: clipboardRoot)
        self.settings = AppSettings.load(from: defaults)
        self.gate = ClipboardGate(changeCount: pasteboard.changeCount)
        worker.onEvent = { [weak self] event in self?.receive(event) }
        worker.onFailure = { [weak self] error in
            guard let self else { return }
            if let job = self.queue.activeJob, job.destination == .clipboard {
                self.worker.stop(afterExit: { [clipboardResults = self.clipboardResults] in
                    clipboardResults.discard(jobID: job.id)
                })
            }
            self.convertedClipboardFiles.removeAll(); self.clipboardChangeCounts.removeAll()
            self.awaitingPreparation = false; self.preparationRejectedCount = 0
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
    /// 파일 선택도 드롭과 같은 확인 단계를 거치며 취소 시 목록을 변경하지 않는다.
    func chooseFiles() -> Bool? {
        let panel = NSOpenPanel()
        panel.title = "HEIC 파일 선택"
        panel.message = "변환할 HEIC 파일을 선택하세요. 여러 파일을 선택할 수 있습니다."
        panel.prompt = "선택"
        panel.allowedContentTypes = [.heic]
        panel.allowsOtherFileTypes = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = false
        guard panel.runModal() == .OK else { return nil }
        let previousCount = staged.count
        stage(panel.urls)
        return staged.count > previousCount
    }
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
        if convert { schedule(paths, destination: selectedDestination) }
    }
    func remove(_ path: String) {
        // 표시 중인 항목의 ID는 파일 경로가 나중에 교체되어도 바뀌지 않는다.
        let itemID = queue.knownPaths.contains(path) ? path : InputValidator.canonicalPath(URL(fileURLWithPath: path))
        queue.remove(itemID)
    }
    // 선택 상태가 가진 고정 ID를 그대로 사용한다. 파일 경로를 다시 해석하지 않는다.
    func removeSelected(_ ids: Set<String>) { queue.removeSelected(ids) }
    func removeAll() { queue.removeAll() }
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
    func startWaiting() { startWaiting(destination: selectedDestination) }
    func startWaiting(destination: ConversionDestination, includingStaged: Bool = false) {
        selectedDestination = destination
        if includingStaged { acceptStaged(convert: false) }
        schedule(queue.items.filter { $0.status == .waiting }.map(\.id), destination: destination)
    }
    func retryFailures() {
        // 재시도는 실패 항목이 요청했던 저장·복사 방식을 유지한다.
        for destination in [ConversionDestination.files, .clipboard] {
            schedule(queue.items.filter { $0.status == .failed && $0.conversionDestination == destination }.map(\.id),
                     destination: destination)
        }
    }
    func retry(_ path: String) {
        guard let item = queue.items.first(where: { $0.id == path }) else { return }
        schedule([path], destination: item.conversionDestination)
    }
    private func schedule(_ paths: [String], destination: ConversionDestination) {
        let previousJobs = Set(queue.jobs.map(\.id))
        queue.schedule(paths: paths, settings: settings, destination: destination)
        for job in queue.jobs where !previousJobs.contains(job.id) && job.destination == .clipboard {
            clipboardChangeCounts[job.id] = pasteboard.changeCount
        }
        startNext()
    }
    private func startNext() {
        guard !terminating else { return }
        guard let job = queue.next() else { return }
        cancelling = false
        awaitingPreparation = true; preparationRejectedCount = 0
        convertedClipboardFiles.removeAll()
        var outputDirectory: String?
        if job.destination == .clipboard {
            do { outputDirectory = try clipboardResults.prepareDirectory(jobID: job.id).path }
            catch {
                clipboardChangeCounts.removeValue(forKey: job.id)
                queue.failCurrentJob(error.localizedDescription)
                awaitingPreparation = false; message = error.localizedDescription
                startNext(); return
            }
        }
        do {
            try worker.start()
            var request = WorkerRequest(command: "prepare", job: job, outputDirectory: outputDirectory)
            // 이미지 복사는 파일 이름과 무관하다. 임시 결과끼리 겹쳐도 모두 변환한다.
            if job.destination == .clipboard { request.options?.onConflict = "rename" }
            try worker.send(request)
            message = job.destination == .clipboard ? "복사할 \(job.files.count)개 파일을 확인하고 있습니다."
                : "저장 위치와 \(job.files.count)개 파일을 확인하고 있습니다."
        } catch { worker.fail(error.localizedDescription) }
    }
    func cancel() {
        guard let job = queue.activeJob, !cancelling else { return }
        do {
            // 준비 실패 후의 unknown_job 응답이 다음 예약에 섞이지 않도록 prepared까지 기다린다.
            if !awaitingPreparation {
                try worker.send(WorkerRequest(command: "cancel", job: job))
                rememberCancellation(job.id)
            }
            cancelling = true; message = "현재 파일 저장 후 취소합니다."
        }
        catch { worker.fail(error.localizedDescription) }
    }
    private func receive(_ event: WorkerEvent) {
        // 마지막 파일 완료와 취소 전송이 교차하면 이전 작업의 unknown_job이 뒤늦게 올 수 있다.
        if event.event == "error", event.errorCode == "unknown_job",
           event.jobID != queue.activeJob?.id, cancellationJobIDs.contains(event.jobID) {
            cancellationJobIDs.removeAll { $0 == event.jobID }; return
        }
        guard let job = queue.activeJob else { return }
        guard job.id == event.jobID else { worker.fail("worker 응답의 작업 ID가 일치하지 않습니다."); return }
        switch event.event {
        case "prepared":
            awaitingPreparation = false
            // worker의 최종 집계는 수락한 입력만 세므로 준비 단계의 거절도 표시 집계에 포함한다.
            preparationRejectedCount = Set((event.rejected ?? []).map(\.source)).count
            for rejection in event.rejected ?? [] { queue.update(path: rejection.source, status: .failed, detail: rejection.reason) }
            do {
                try worker.send(WorkerRequest(command: cancelling ? "cancel" : "run", job: job))
                if cancelling { rememberCancellation(job.id) }
            }
            catch { worker.fail(error.localizedDescription) }
        case "file_started":
            if let path = event.source { queue.update(path: path, status: .running) }
            message = "\(event.index ?? 0)/\(event.total ?? job.files.count) 변환 중"
        case "file_succeeded", "file_skipped", "file_failed":
            guard let path = event.source else { return }
            let status: FileStatus = event.event == "file_succeeded" ? .succeeded : event.event == "file_skipped" ? .skipped : .failed
            var detail = event.error.map { "\(event.errorCode ?? "conversion_error"): \($0)" }
            if status == .failed, ["output_permission", "output_unavailable"].contains(event.errorCode ?? "") {
                detail = (detail ?? "저장 실패") + (job.destination == .files
                    ? " 저장 위치를 변경한 뒤 실패 파일을 재시도하세요."
                    : " 임시 변환 위치에 접근할 수 없습니다. 재시도하거나 앱을 다시 실행하세요.")
            }
            if status == .succeeded { detail = event.hdrApplied == true ? "HDR 적용" : event.sdrReason }
            if status == .skipped { detail = "동일한 이름의 결과가 있어 건너뛰었습니다." }
            if job.destination == .clipboard, status == .succeeded, let destination = event.destination {
                convertedClipboardFiles[path] = URL(fileURLWithPath: destination)
                // 클립보드 게시가 끝날 때까지 잠금을 유지하고 임시 결과 열기는 제공하지 않는다.
                queue.update(path: path, status: .running, detail: "변환 완료 · 복사 대기")
            } else {
                queue.update(path: path, status: status, detail: detail, destination: event.destination)
            }
        case "completed", "cancelled":
            if job.destination == .clipboard { finishClipboardJob(job, event: event) }
            else {
                message = "\(event.event == "cancelled" ? "취소" : "완료"): 성공 \(event.succeeded ?? 0), 건너뜀 \(event.skipped ?? 0), 실패 \((event.failed ?? 0) + preparationRejectedCount)"
            }
            preparationRejectedCount = 0; awaitingPreparation = false
            queue.finish(); cancelling = false; startNext()
        case "error":
            let error = "\(event.errorCode ?? "worker_error"): \(event.message ?? "작업을 시작하지 못했습니다.")"
            // prepare 검증 실패 또는 worker가 정리한 단일 실행 오류는 세션 장애가 아니다.
            let jobError = (awaitingPreparation && event.errorCode == "invalid_request")
                || event.errorCode == "worker_failed"
            guard jobError else { worker.fail(error); return }
            if job.destination == .clipboard {
                clipboardResults.discard(jobID: job.id)
                clipboardChangeCounts.removeValue(forKey: job.id); convertedClipboardFiles.removeAll()
            }
            queue.failCurrentJob(error); cancelling = false
            preparationRejectedCount = 0; awaitingPreparation = false
            message = error + (job.destination == .files
                ? " 저장 경로 또는 옵션을 확인하고, 저장 폴더 오류라면 저장 위치를 변경하세요."
                : " 변환 옵션 또는 임시 변환 위치를 확인한 뒤 재시도하세요.")
            startNext()
        default: break
        }
    }
    private func rememberCancellation(_ id: String) {
        cancellationJobIDs.append(id)
        if cancellationJobIDs.count > 32 { cancellationJobIDs.removeFirst() }
    }
    private func finishClipboardJob(_ job: ConversionJob, event: WorkerEvent) {
        defer {
            clipboardChangeCounts.removeValue(forKey: job.id)
            convertedClipboardFiles.removeAll()
        }
        let failed = (event.failed ?? 0) + preparationRejectedCount
        let cancelled = cancelling || event.event == "cancelled"
        guard !cancelled, !convertedClipboardFiles.isEmpty else {
            for path in convertedClipboardFiles.keys { queue.update(path: path, status: .waiting, detail: "복사를 취소했습니다.") }
            clipboardResults.discard(jobID: job.id)
            message = cancelled ? "복사 취소: 기존 클립보드를 유지했습니다."
                : "복사할 변환 결과가 없습니다. 실패 \(failed) · 기존 클립보드를 유지했습니다."
            return
        }
        do {
            guard let expectedCount = clipboardChangeCounts[job.id] else { throw WorkerFailure.invalidEvent }
            let urls = job.files.compactMap { convertedClipboardFiles[$0] }
            let publishedCount = try clipboardResults.publish(jobID: job.id, urls: urls, expectedChangeCount: expectedCount)
            // 앱 자신의 복사는 다음 예약의 기준만 갱신하고 외부 변경은 갱신하지 않는다.
            for id in clipboardChangeCounts.keys where clipboardChangeCounts[id] == expectedCount {
                clipboardChangeCounts[id] = publishedCount
            }
            gate.resume(changeCount: publishedCount)
            for path in convertedClipboardFiles.keys { queue.update(path: path, status: .succeeded, detail: "클립보드에 복사됨") }
            message = "이미지 복사 완료: \(urls.count)개 · 실패 \(failed). 문서나 메신저에 붙여넣으세요."
        } catch {
            for path in convertedClipboardFiles.keys { queue.update(path: path, status: .failed, detail: error.localizedDescription) }
            clipboardResults.discard(jobID: job.id)
            message = "복사 실패: \(error.localizedDescription)"
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
    func shutdown(completion: (() -> Void)? = nil) {
        terminating = true
        timer?.invalidate(); timer = nil
        let jobID = queue.activeJob.flatMap { $0.destination == .clipboard ? $0.id : nil }
        worker.stop(afterExit: { [clipboardResults] in
            if let jobID { clipboardResults.discard(jobID: jobID) }
            clipboardResults.shutdown()
            completion?()
        })
        FileThumbnailStore.shared.removeAllCachedThumbnails()
    }
}
