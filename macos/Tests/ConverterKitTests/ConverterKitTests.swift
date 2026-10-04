import XCTest
@testable import ConverterKit

final class ConverterKitTests: XCTestCase {
    func testQueueSnapshotCancellationAndNewInputs() {
        var queue = QueueState()
        let first = URL(fileURLWithPath: "/tmp/한글 사진.heic")
        let second = URL(fileURLWithPath: "/tmp/second.heic")
        let later = URL(fileURLWithPath: "/tmp/later.heic")
        queue.add([first, second, first])
        XCTAssertEqual(queue.items.count, 2)
        var settings = AppSettings()
        queue.schedule(paths: [first.path, second.path], settings: settings)
        settings.options.jpegQuality = 10
        let job = queue.next()!
        XCTAssertEqual(job.options.jpegQuality, 90)
        XCTAssertNil(queue.next())
        queue.add([later])
        queue.update(path: first.path, status: .succeeded, destination: "/tmp/result.jpg")
        queue.finish()
        XCTAssertEqual(queue.items.map(\.status), [.succeeded, .waiting, .waiting])
        queue.add([first])
        XCTAssertEqual(queue.items.count, 3)
        queue.clearCompleted()
        queue.add([first])
        XCTAssertEqual(queue.items.last?.status, .waiting)
    }
    func testScheduledJobKeepsOptionsAndWorkerFailureReleasesLaterJobs() {
        var queue = QueueState()
        queue.add([URL(fileURLWithPath: "/a.heic"), URL(fileURLWithPath: "/b.heic")])
        var settings = AppSettings()
        queue.schedule(paths: ["/a.heic"], settings: settings)
        _ = queue.next()
        settings.options.outputFormat = "png"
        queue.schedule(paths: ["/b.heic"], settings: settings)
        settings.options.outputFormat = "jpeg"
        XCTAssertEqual(queue.jobs.first?.options.outputFormat, "png")
        queue.remove("/a.heic")
        XCTAssertEqual(queue.items.count, 2)
        queue.failActive("worker 종료")
        XCTAssertEqual(queue.items.map(\.status), [.failed, .waiting])
        XCTAssertTrue(queue.jobs.isEmpty)
        queue.schedule(paths: ["/a.heic"], settings: settings)
        XCTAssertEqual(queue.next()?.files, ["/a.heic"])
    }
    func testClipboardBaselineDenialAndResume() {
        var gate = ClipboardGate(changeCount: 1)
        XCTAssertFalse(gate.shouldRead(changeCount: 1, enabled: true, accessDenied: false))
        XCTAssertTrue(gate.shouldRead(changeCount: 2, enabled: true, accessDenied: false))
        XCTAssertFalse(gate.shouldRead(changeCount: 2, enabled: true, accessDenied: false))
        XCTAssertFalse(gate.shouldRead(changeCount: 3, enabled: false, accessDenied: false))
        gate.resume(changeCount: 3)
        XCTAssertFalse(gate.shouldRead(changeCount: 3, enabled: true, accessDenied: false))
        XCTAssertFalse(gate.shouldRead(changeCount: 4, enabled: true, accessDenied: true))
        XCTAssertFalse(gate.shouldRead(changeCount: 5, enabled: true, accessDenied: false))
        gate.resume(changeCount: 5)
        XCTAssertTrue(gate.shouldRead(changeCount: 6, enabled: true, accessDenied: false))
    }
    func testInputRejectionsAndCanonicalDuplicate() throws {
        let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("한글 사진.HEIC")
        try Data([0]).write(to: source)
        let link = folder.appendingPathComponent("link.heic")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        let directory = folder.appendingPathComponent("directory.heic")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let result = InputValidator.validate([source, source, link, directory, folder.appendingPathComponent("gone.heic"), folder.appendingPathComponent("not.heif"), URL(string: "https://example.com/a.heic")!])
        XCTAssertEqual(result.accepted, [URL(fileURLWithPath: InputValidator.canonicalPath(source))])
        XCTAssertEqual(result.rejected.count, 6)
        XCTAssertTrue(result.rejected.contains { $0.reason.contains("심볼릭") })
    }
    func testProtocolSplitLinesVersionAndOptions() throws {
        let job = ConversionJob(files: ["/tmp/한글 사진.heic"], settings: AppSettings())
        let data = try WorkerRequest(command: "prepare", job: job).line()
        let request = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(request["protocol_version"] as? Int, 1)
        XCTAssertEqual(request["files"] as? [String], job.files)
        XCTAssertEqual((request["options"] as? [String: Any])?["jpeg_quality"] as? Int, 90)
        let line = Data("{\"protocol_version\":1,\"job_id\":\"test\",\"event\":\"completed\",\"succeeded\":1,\"skipped\":0,\"failed\":0,\"total\":1,\"remaining\":[]}\n".utf8)
        var buffer = JSONLineBuffer()
        XCTAssertTrue(try buffer.append(line.prefix(12)).isEmpty)
        let events = try buffer.append(line.dropFirst(12) + line)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.first?.succeeded, 1)
        XCTAssertThrowsError(try WorkerEvent.decode(Data("{\"protocol_version\":2,\"job_id\":\"test\",\"event\":\"prepared\"}".utf8)))
        XCTAssertThrowsError(try WorkerEvent.decode(Data("{\"protocol_version\":1,\"job_id\":\"test\",\"event\":\"unknown\"}".utf8)))
        XCTAssertThrowsError(try WorkerEvent.decode(Data("not json".utf8)))
        XCTAssertThrowsError(try WorkerEvent.decode(Data("{\"protocol_version\":1,\"job_id\":\"test\",\"event\":\"completed\"}".utf8)))
        XCTAssertThrowsError(try WorkerEvent.decode(Data("{\"protocol_version\":1,\"job_id\":\"test\",\"event\":\"prepared\",\"files\":[],\"rejected\":[],\"total\":2}".utf8)))
    }
    func testSettingsPersistWithoutQueueHistory() throws {
        let name = "heic-converter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var settings = AppSettings()
        XCTAssertTrue(settings.clipboardEnabled)
        XCTAssertEqual(settings.options.jpegQuality, 90)
        XCTAssertEqual(settings.options.pngCompression, 6)
        settings.clipboardEnabled = false; settings.outputDirectory = "/tmp/저장 폴더"
        settings.save(to: defaults)
        XCTAssertEqual(AppSettings.load(from: defaults), settings)
        XCTAssertEqual(defaults.persistentDomain(forName: name)?.keys.count, 1)
    }
}
