import Foundation
import ConverterKit

@MainActor final class WorkerClient {
    var onEvent: ((WorkerEvent) -> Void)?
    var onFailure: ((String) -> Void)?
    private var process: Process?
    private var stopping = false
    private var input: FileHandle?
    private var generation = UUID()
    private var buffer = JSONLineBuffer()
    private var diagnostics = ""

    func start() throws {
        if stopping {
            guard process?.isRunning != true else { throw WorkerFailure.stopping }
            process = nil; stopping = false
        }
        if process?.isRunning == true { return }
        guard let resources = Bundle.main.resourceURL else { throw WorkerFailure.unavailable }
        let executable = resources.appendingPathComponent("worker/heic-worker")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw WorkerFailure.unavailable }
        let task = Process()
        task.executableURL = executable
        // 사용자 Python, 셸, PATH 설정을 실행 경로로 사용하지 않는다.
        task.environment = ["PATH": "/usr/bin:/bin", "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                            "LANG": "en_US.UTF-8", "PYTHONUTF8": "1"]
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        task.standardInput = stdin; task.standardOutput = stdout; task.standardError = stderr
        let token = UUID(); generation = token; buffer = JSONLineBuffer(); diagnostics = ""
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil }
            DispatchQueue.main.async {
                guard let self, self.generation == token else { return }
                if data.isEmpty {
                    self.fail("worker의 출력 연결이 종료되었습니다.")
                    return
                }
                do { for event in try self.buffer.append(data) { self.onEvent?(event) } }
                catch { self.fail(error.localizedDescription) }
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.diagnostics = String((self.diagnostics + (String(data: data, encoding: .utf8) ?? "")).suffix(4096))
            }
        }
        try task.run()
        process = task; input = stdin.fileHandleForWriting
    }
    func send(_ request: WorkerRequest) throws {
        guard let input, process?.isRunning == true else { throw WorkerFailure.unavailable }
        try input.write(contentsOf: request.line())
    }
    func fail(_ message: String) { stop(); onFailure?(message) }
    /// 종료된 worker만 임시 결과를 정리하도록 실제 프로세스 종료 뒤 콜백을 보낸다.
    func stop(afterExit: (() -> Void)? = nil) {
        if let afterExit {
            if let process, process.isRunning {
                let previousHandler = process.terminationHandler
                process.terminationHandler = { task in
                    previousHandler?(task)
                    DispatchQueue.main.async { afterExit() }
                }
            } else { afterExit() }
        }
        if stopping { return }
        generation = UUID()
        try? input?.close(); input = nil
        if let process {
            (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
            (process.standardError as? Pipe)?.fileHandleForReading.readabilityHandler = nil
            if process.isRunning {
                let previousHandler = process.terminationHandler
                process.terminationHandler = { [weak self] task in
                    previousHandler?(task)
                    DispatchQueue.main.async {
                        guard let self, self.process === task else { return }
                        self.process = nil; self.stopping = false
                    }
                }
                process.terminate()
            }
        }
        stopping = process?.isRunning == true
        if !stopping { process = nil }
    }
}
