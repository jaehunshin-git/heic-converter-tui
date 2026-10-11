import AppKit
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ConverterKit

final class AutomaticClipboardStoreTests: XCTestCase {
    private struct Representation: Equatable {
        let type: String
        let data: Data
    }
    private final class MissingData: NSObject, NSPasteboardItemDataProvider {
        func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem,
                        provideDataForType type: NSPasteboard.PasteboardType) {}
    }

    @MainActor private final class Fixture {
        let board = NSPasteboard(name: .init("AutomaticClipboardStoreTests-\(UUID().uuidString)"))
        let files = FileManager()
        let sandbox: URL
        let root: URL
        let store: AutomaticClipboardStore
        init(writer: ((NSPasteboard, [NSPasteboardItem]) -> Bool)? = nil,
             cleanupItemsReader: @escaping (NSPasteboard) -> [NSPasteboardItem]? = { $0.pasteboardItems },
             metadataReader: @escaping (URL) -> stat? = { AutomaticClipboardStoreTests.metadata($0) }) throws {
            sandbox = URL(fileURLWithPath: InputValidator.canonicalPath(FileManager.default.temporaryDirectory), isDirectory: true)
                .appendingPathComponent("AutomaticClipboardStoreTests-\(UUID().uuidString)", isDirectory: true)
            root = sandbox.appendingPathComponent("관리", isDirectory: true)
            try files.createDirectory(at: sandbox, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            store = AutomaticClipboardStore(pasteboard: board, root: root, fileManager: files,
                writer: writer ?? { $0.writeObjects($1) }, cleanupItemsReader: cleanupItemsReader,
                metadataReader: metadataReader)
        }
        func close() {
            try? store.shutdown()
            board.releaseGlobally()
            try? files.removeItem(at: sandbox)
        }
        func source(_ name: String = "원본.heic") throws -> URL {
            let url = sandbox.appendingPathComponent(name)
            try AutomaticClipboardStoreTests.image(.heic).write(to: url)
            return url
        }
        func put(_ items: [NSPasteboardItem]) {
            board.clearContents()
            XCTAssertTrue(board.writeObjects(items))
        }
        func putText(_ text: String = "새 내용") {
            put([AutomaticClipboardStoreTests.item([(.string, Data(text.utf8))])])
        }
        func ready(_ source: URL) throws -> (ClipboardSnapshot, String, [URL], URL) {
            put([AutomaticClipboardStoreTests.item([(.fileURL, Data(source.absoluteString.utf8))])])
            let snapshot = try store.capture()
            let id = UUID().uuidString
            let prepared = try store.prepare(snapshot: snapshot, jobID: id)
            return (snapshot, id, prepared.inputs, prepared.outputDirectory)
        }
        func output(_ directory: URL, _ name: String = "결과.png", type: UTType = .png) throws -> URL {
            let url = directory.appendingPathComponent(name)
            try AutomaticClipboardStoreTests.image(type).write(to: url)
            return url
        }
    }

    private static func metadata(_ url: URL) -> stat? {
        var value = stat()
        return url.withUnsafeFileSystemRepresentation { path in
            guard let path, Darwin.lstat(path, &value) == 0 else { return nil }
            return value
        }
    }

    private static func photosItem(source: URL, raw: Data) throws -> NSPasteboardItem {
        let asset = try PropertyListSerialization.data(fromPropertyList: ["mediaType": 1, "mediaSubtypes": 0],
                                                       format: .binary, options: 0)
        return item([(.fileURL, Data(source.absoluteString.utf8)), (.URL, Data(source.absoluteString.utf8)),
                     (.init(UTType.heic.identifier), raw),
                     (.init("com.apple.photos.object-reference.asset"), asset)])
    }

    private static func image(_ type: UTType, red: CGFloat = 0.2) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: 16, height: 12, bitsPerComponent: 8,
            bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: red, green: 0.7, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 12))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        guard CGImageDestinationFinalize(destination) else { throw AutomaticClipboardError.invalidImage }
        return data as Data
    }

    private static func item(_ values: [(NSPasteboard.PasteboardType, Data)]) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        for (type, data) in values { XCTAssertTrue(item.setData(data, forType: type)) }
        return item
    }

    @MainActor private func contents(_ board: NSPasteboard) throws -> [[Representation]] {
        try (board.pasteboardItems ?? []).map { item in
            try item.types.map { Representation(type: $0.rawValue, data: try XCTUnwrap(item.data(forType: $0))) }
        }
    }

    @MainActor
    func testMixedItemsDuplicateSourcesLongNameAndExactRestoration() throws {
        let f = try Fixture(); defer { f.close() }
        // 255바이트 원본은 표시·복구용으로 유지하고 내부 이름은 worker 저장 예산에 맞춘다.
        let source = try f.source(String(repeating: "a", count: 250) + ".heic")
        let png = f.sandbox.appendingPathComponent("보존.png")
        try Self.image(.png).write(to: png)
        let document = f.sandbox.appendingPathComponent("문서.txt")
        try Data("문서".utf8).write(to: document)
        let custom = NSPasteboard.PasteboardType("test.heic.caption")
        let oldTIFF = try XCTUnwrap(NSImage(data: Self.image(.png))?.tiffRepresentation)
        f.put([
            Self.item([(.fileURL, Data(source.absoluteString.utf8)), (.URL, Data(source.absoluteString.utf8)),
                       (.tiff, oldTIFF), (.string, Data("설명".utf8)), (custom, Data([0, 1, 255]))]),
            Self.item([(.string, Data("중간 텍스트".utf8))]),
            Self.item([(.fileURL, Data(png.absoluteString.utf8))]),
            Self.item([(.fileURL, Data(document.absoluteString.utf8))]),
            Self.item([(.fileURL, Data(source.absoluteString.utf8))])
        ])
        let original = try contents(f.board)
        let generation = f.board.changeCount
        let snapshot = try f.store.capture()
        XCTAssertEqual(snapshot.changeCount, generation)
        XCTAssertEqual(snapshot.files.map(\.isHEIC), [true, false, false, true])
        XCTAssertEqual(snapshot.targets.map(\.source), [source, source])
        let id = UUID().uuidString
        let prepared = try f.store.prepare(snapshot: snapshot, jobID: id)
        XCTAssertEqual(Set(prepared.inputs).count, 2)
        XCTAssertEqual(snapshot.files.filter(\.isHEIC).map(\.name), [source.lastPathComponent, source.lastPathComponent])
        XCTAssertTrue(prepared.inputs.allSatisfy { $0.lastPathComponent.utf8.count <= 200 })
        XCTAssertEqual(prepared.inputs[0].lastPathComponent, prepared.inputs[1].lastPathComponent)
        XCTAssertEqual(InputValidator.validate(prepared.inputs).accepted.count, 2)
        for input in prepared.inputs { XCTAssertEqual(try Data(contentsOf: input), try Data(contentsOf: source)) }
        XCTAssertEqual(f.board.changeCount, generation)
        let outputs = [try f.output(prepared.outputDirectory), try f.output(prepared.outputDirectory, "둘째.jpeg", type: .jpeg)]
        let own = try f.store.publish(snapshot: snapshot, jobID: id, results: outputs)
        XCTAssertEqual(f.store.ownedChangeCount, own)
        let published = try XCTUnwrap(f.board.pasteboardItems)
        XCTAssertEqual(published.count, 5)
        XCTAssertEqual(published[0].string(forType: .fileURL), outputs[0].absoluteString)
        XCTAssertEqual(published[0].string(forType: .URL), outputs[0].absoluteString)
        XCTAssertEqual(published[0].data(forType: .png), try Data(contentsOf: outputs[0]))
        XCTAssertEqual(published[0].data(forType: custom), Data([0, 1, 255]))
        XCTAssertEqual(published[0].string(forType: .string), "설명")
        XCTAssertEqual(published[4].data(forType: .init(UTType.jpeg.identifier)), try Data(contentsOf: outputs[1]))
        let after = try contents(f.board)
        for index in [1, 2, 3] { XCTAssertEqual(after[index], original[index]) }
        f.store.discard(jobID: id)
        f.store.clipboardDidChange()
        XCTAssertTrue(outputs.allSatisfy { f.files.fileExists(atPath: $0.path) })
        XCTAssertThrowsError(try f.store.capture()) { XCTAssertTrue($0 is AutomaticClipboardError) }
        try f.store.shutdown()
        XCTAssertEqual(try contents(f.board), original)
        XCTAssertTrue(outputs.allSatisfy { !f.files.fileExists(atPath: $0.path) })
        XCTAssertTrue(f.files.fileExists(atPath: source.path))
    }

    @MainActor
    func testStagingNameByteBudgetPreservesUnicodeAndOriginalDescriptors() throws {
        let f = try Fixture(); defer { f.close() }
        let names = [String(repeating: "a", count: 250) + ".heic",
                     String(repeating: "한", count: 83) + "a.heic",
                     String(repeating: "😀", count: 62) + "ab.heic",
                     "그대로 유지할 짧은 이름.heic"]
        let sources = try names.map { try f.source($0) }
        XCTAssertTrue(names.prefix(3).allSatisfy { $0.utf8.count == 255 })
        f.put(sources.map { Self.item([(.fileURL, Data($0.absoluteString.utf8))]) })
        let snapshot = try f.store.capture()
        XCTAssertEqual(snapshot.files.map(\.name), names)
        XCTAssertEqual(snapshot.targets.map(\.source), sources)
        let id = UUID().uuidString
        let prepared = try f.store.prepare(snapshot: snapshot, jobID: id)
        XCTAssertEqual(prepared.inputs.count, sources.count)
        XCTAssertEqual(Set(prepared.inputs).count, sources.count)
        for (source, input) in zip(sources, prepared.inputs) {
            XCTAssertEqual(input.pathExtension, "heic")
            XCTAssertLessThanOrEqual(input.lastPathComponent.utf8.count, 200)
            XCTAssertFalse(input.lastPathComponent.contains("�"))
            XCTAssertEqual(try Data(contentsOf: input), try Data(contentsOf: source))
        }
        XCTAssertEqual(prepared.inputs.last?.lastPathComponent, names.last)
        XCTAssertEqual(try f.store.prepare(snapshot: snapshot, jobID: id).inputs, prepared.inputs)
        f.store.discard(jobID: id)
        XCTAssertTrue(sources.allSatisfy { f.files.fileExists(atPath: $0.path) })
    }

    @MainActor
    func testRawHEICMaterializesAndPreservesRemoteURLAndNonImageBytes() throws {
        let f = try Fixture(); defer { f.close() }
        let heic = try Self.image(.heic)
        let remote = Data("https://example.com/photo".utf8)
        let rawType = NSPasteboard.PasteboardType(UTType.heic.identifier)
        f.put([Self.item([(rawType, heic), (.png, try Self.image(.png)), (.URL, remote), (.string, Data("제목".utf8))])])
        let original = try contents(f.board)
        let snapshot = try f.store.capture()
        XCTAssertNil(snapshot.files.first?.url)
        XCTAssertTrue(snapshot.files.first?.isHEIC == true)
        XCTAssertEqual(snapshot.files.first?.id, snapshot.targets.first?.id)
        XCTAssertFalse(f.files.fileExists(atPath: snapshot.targets[0].source.path))
        let id = UUID().uuidString
        let prepared = try f.store.prepare(snapshot: snapshot, jobID: id)
        XCTAssertEqual(try Data(contentsOf: prepared.inputs[0]), heic)
        let result = try f.output(prepared.outputDirectory, "사진.jpeg", type: .jpeg)
        _ = try f.store.publish(snapshot: snapshot, jobID: id, results: [result])
        let published = try XCTUnwrap(f.board.pasteboardItems?.first)
        XCTAssertNil(published.data(forType: rawType))
        XCTAssertNil(published.data(forType: .png))
        XCTAssertEqual(published.data(forType: .URL), remote)
        XCTAssertEqual(published.string(forType: .string), "제목")
        XCTAssertEqual(published.string(forType: .fileURL), result.absoluteString)
        XCTAssertEqual(published.data(forType: .init(UTType.jpeg.identifier)), try Data(contentsOf: result))
        try f.store.shutdown()
        XCTAssertEqual(try contents(f.board), original)
    }

    @MainActor
    func testPhotosRawOverridesMissingOrDifferentFileWithoutSourceMetadataLookup() throws {
        for existingFile in [false, true] {
            var sourceLookups: [URL] = []
            var sourceURL: URL?
            let f = try Fixture(metadataReader: { url in
                if url == sourceURL { sourceLookups.append(url); return nil }
                return Self.metadata(url)
            })
            defer { f.close() }
            let source = f.sandbox.appendingPathComponent("Photos 원본.heic")
            sourceURL = source
            // 기존 URL의 데이터가 raw와 달라도 Photos 복사 시점의 raw를 입력으로 삼는다.
            let fileBytes = Data("URL의 다른 데이터".utf8)
            if existingFile { try fileBytes.write(to: source) }
            let raw = try Self.image(.heic)
            f.put([try Self.photosItem(source: source, raw: raw)])
            let original = try contents(f.board)
            let generation = f.board.changeCount
            let snapshot = try f.store.capture()
            XCTAssertEqual(snapshot.targets.map(\.source), [source])
            XCTAssertEqual(snapshot.files.first?.name, source.lastPathComponent)
            XCTAssertNil(snapshot.files.first?.url, "원본 URL을 썸네일 디코더에 전달하면 안 됩니다.")
            let id = UUID().uuidString
            let prepared = try f.store.prepare(snapshot: snapshot, jobID: id)
            XCTAssertEqual(prepared.inputs.count, 1)
            XCTAssertEqual(try Data(contentsOf: prepared.inputs[0]), raw)
            XCTAssertEqual(f.board.changeCount, generation)
            let output = try f.output(prepared.outputDirectory)
            _ = try f.store.publish(snapshot: snapshot, jobID: id, results: [output])
            XCTAssertEqual(f.board.pasteboardItems?.first?.string(forType: .fileURL), output.absoluteString)
            XCTAssertEqual(f.board.pasteboardItems?.first?.string(forType: .URL), output.absoluteString)
            try f.store.shutdown()
            XCTAssertEqual(try contents(f.board), original)
            XCTAssertTrue(sourceLookups.isEmpty, "Photos 원본 URL의 metadata를 읽으면 안 됩니다.")
            if existingFile { XCTAssertEqual(try Data(contentsOf: source), fileBytes) }
            else { XCTAssertFalse(f.files.fileExists(atPath: source.path)) }
        }
    }

    @MainActor
    func testOrdinarySourceMetadataFailureDoesNotFallBackToValidRaw() throws {
        var sourceURL: URL?
        var sourceLookups = 0
        let f = try Fixture(metadataReader: { url in
            if url == sourceURL { sourceLookups += 1; return nil }
            return Self.metadata(url)
        })
        defer { f.close() }
        let source = try f.source()
        sourceURL = source
        let raw = try Data(contentsOf: source)
        f.put([Self.item([(.fileURL, Data(source.absoluteString.utf8)), (.init(UTType.heic.identifier), raw)])])
        let original = try contents(f.board)
        let generation = f.board.changeCount
        XCTAssertThrowsError(try f.store.capture()) {
            guard case AutomaticClipboardError.unsafePath = $0 else { return XCTFail("메타데이터 조회 실패를 거절하지 않았습니다: \($0)") }
        }
        XCTAssertEqual(sourceLookups, 1)
        XCTAssertEqual(f.board.changeCount, generation)
        XCTAssertEqual(try contents(f.board), original)
        XCTAssertEqual(try Data(contentsOf: source), raw)
        XCTAssertFalse(f.files.fileExists(atPath: f.root.path))
    }

    @MainActor
    func testOrdinaryDatalessSourceDoesNotReadFileOrFallBackToValidRaw() throws {
        var sourceURL: URL?
        var sourceLookups = 0
        let f = try Fixture(metadataReader: { url in
            guard var value = Self.metadata(url) else { return nil }
            if url == sourceURL { sourceLookups += 1; value.st_flags |= UInt32(SF_DATALESS) }
            return value
        })
        defer { f.close() }
        let source = f.sandbox.appendingPathComponent("오프라인 원본.heic")
        sourceURL = source
        // 실제 파일 플래그·파일 공급자는 변경하지 않는다. 파일을 읽었다면 invalidImage가 발생한다.
        let fileBytes = Data([1, 2, 3])
        try fileBytes.write(to: source)
        f.put([Self.item([(.fileURL, Data(source.absoluteString.utf8)),
                          (.init(UTType.heic.identifier), try Self.image(.heic))])])
        let original = try contents(f.board)
        let generation = f.board.changeCount
        XCTAssertThrowsError(try f.store.capture()) {
            guard case AutomaticClipboardError.fileUnavailable = $0 else { return XCTFail("dataless 파일을 읽기 전에 거절하지 않았습니다: \($0)") }
        }
        XCTAssertEqual(sourceLookups, 1)
        XCTAssertEqual(f.board.changeCount, generation)
        XCTAssertEqual(try contents(f.board), original)
        XCTAssertEqual(try Data(contentsOf: source), fileBytes)
        XCTAssertFalse(f.files.fileExists(atPath: f.root.path))
    }

    @MainActor
    func testOrdinaryFileAndDifferentRawAreRejectedWithoutChangingOriginal() throws {
        let f = try Fixture(); defer { f.close() }
        let source = try f.source()
        let fileBytes = try Data(contentsOf: source)
        // 색이 다른 유효한 HEIC를 사용해 손상된 raw 거절과 원본 불일치를 구분한다.
        let raw = try Self.image(.heic, red: 0.8)
        XCTAssertNotEqual(raw, fileBytes)
        XCTAssertNotNil(CGImageSourceCreateWithData(raw as CFData, nil))
        f.put([Self.item([(.fileURL, Data(source.absoluteString.utf8)), (.init(UTType.heic.identifier), raw)])])
        let original = try contents(f.board)
        let generation = f.board.changeCount
        XCTAssertThrowsError(try f.store.capture()) {
            guard case AutomaticClipboardError.unsupportedRepresentation = $0 else { return XCTFail("다른 원본 표현을 거절하지 않았습니다: \($0)") }
        }
        XCTAssertEqual(f.board.changeCount, generation)
        XCTAssertEqual(try contents(f.board), original)
        XCTAssertEqual(try Data(contentsOf: source), fileBytes)
    }

    @MainActor
    func testPhotosPreviewAfterMixedCaptureFailureDoesNotExposeOriginalURL() throws {
        let f = try Fixture(); defer { f.close() }
        let source = f.sandbox.appendingPathComponent("물질화되지 않은 Photos.heic")
        f.put([try Self.photosItem(source: source, raw: Self.image(.heic)),
               Self.item([(.init("com.apple.pasteboard.promised-file-url"), Data())])])
        let original = try contents(f.board)
        let generation = f.board.changeCount
        XCTAssertThrowsError(try f.store.capture())
        let preview = try XCTUnwrap(f.store.previewFiles().first)
        XCTAssertEqual(preview.name, source.lastPathComponent)
        XCTAssertTrue(preview.isHEIC)
        XCTAssertNil(preview.url, "전체 캡처가 실패해도 Photos 원본 URL을 썸네일에 전달하면 안 됩니다.")
        XCTAssertEqual(f.board.changeCount, generation)
        XCTAssertEqual(try contents(f.board), original)
    }

    @MainActor
    func testDatalessPreviewAfterCaptureFailureDoesNotExposeOriginalURL() throws {
        var sourceURL: URL?
        let f = try Fixture(metadataReader: { url in
            guard var value = Self.metadata(url) else { return nil }
            if url == sourceURL { value.st_flags |= UInt32(SF_DATALESS) }
            return value
        })
        defer { f.close() }
        let source = try f.source()
        sourceURL = source
        f.put([Self.item([(.fileURL, Data(source.absoluteString.utf8))])])
        let original = try contents(f.board)
        let generation = f.board.changeCount
        XCTAssertThrowsError(try f.store.capture())
        let preview = try XCTUnwrap(f.store.previewFiles().first)
        XCTAssertEqual(preview.name, source.lastPathComponent)
        XCTAssertTrue(preview.isHEIC)
        XCTAssertNil(preview.url, "캡처에서 거절한 dataless 파일을 썸네일에 전달하면 안 됩니다.")
        XCTAssertEqual(f.board.changeCount, generation)
        XCTAssertEqual(try contents(f.board), original)
    }

    @MainActor
    func testPromisesUnreadableExpressionsAndPreviewNeverAlterOriginal() throws {
        let f = try Fixture(); defer { f.close() }
        let source = try f.source()
        let promise = NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")
        f.put([Self.item([(.fileURL, Data(source.absoluteString.utf8)), (promise, Data("약속".utf8))])])
        let original = try contents(f.board)
        let generation = f.board.changeCount
        XCTAssertThrowsError(try f.store.capture())
        XCTAssertEqual(f.store.previewFiles().map(\.name), [source.lastPathComponent])
        XCTAssertEqual(f.board.changeCount, generation)
        XCTAssertEqual(try contents(f.board), original)
        let provider = MissingData()
        let missing = Self.item([(.fileURL, Data(source.absoluteString.utf8))])
        XCTAssertTrue(missing.setDataProvider(provider, forTypes: [.init("test.unreadable")]))
        f.put([missing])
        let unreadableGeneration = f.board.changeCount
        XCTAssertThrowsError(try f.store.capture())
        XCTAssertEqual(f.board.changeCount, unreadableGeneration)
        XCTAssertEqual(f.store.previewFiles().map(\.url), [source])
        f.put([Self.item([(.fileURL, Data(source.deletingPathExtension().appendingPathExtension("heif").absoluteString.utf8))])])
        XCTAssertTrue(try f.store.capture().targets.isEmpty)
        f.putText()
        XCTAssertTrue(try f.store.capture().files.isEmpty)
    }

    @MainActor
    func testAllOrNothingRejectsIncompleteInvalidUnreadableAndUnsafeResults() throws {
        let f = try Fixture(); defer { f.close() }
        let source = try f.source()
        f.put([Self.item([(.fileURL, Data(source.absoluteString.utf8))]), Self.item([(.fileURL, Data(source.absoluteString.utf8))])])
        let snapshot = try f.store.capture()
        let id = UUID().uuidString
        let p = try f.store.prepare(snapshot: snapshot, jobID: id)
        let valid = try f.output(p.outputDirectory)
        let invalid = p.outputDirectory.appendingPathComponent("손상.png")
        try Data([1, 2, 3]).write(to: invalid)
        let outside = try f.output(f.sandbox, "외부.png")
        let link = p.outputDirectory.appendingPathComponent("링크.png")
        try f.files.createSymbolicLink(at: link, withDestinationURL: outside)
        let unreadable = try f.output(p.outputDirectory, "읽기불가.png")
        try f.files.setAttributes([.posixPermissions: 0o000], ofItemAtPath: unreadable.path)
        defer { try? f.files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: unreadable.path) }
        let original = try contents(f.board)
        let generation = f.board.changeCount
        for results in [[], [valid], [valid, valid], [valid, invalid], [valid, outside], [valid, link], [valid, unreadable]] {
            XCTAssertThrowsError(try f.store.publish(snapshot: snapshot, jobID: id, results: results))
            XCTAssertEqual(f.board.changeCount, generation)
            XCTAssertEqual(try contents(f.board), original)
        }
        f.store.discard(jobID: id)
        XCTAssertFalse(f.files.fileExists(atPath: p.outputDirectory.path))
        XCTAssertTrue(f.files.fileExists(atPath: outside.path))
    }

    @MainActor
    func testSourceSystemAliasNSURLAndManagedPathOwnership() throws {
        let f = try Fixture(); defer { f.close() }
        let source = try f.source()
        let aliased = URL(fileURLWithPath: source.path.replacingOccurrences(of: "/private/var/", with: "/var/"))
        f.board.clearContents()
        XCTAssertTrue(f.board.writeObjects([aliased as NSURL]))
        let snapshot = try f.store.capture()
        XCTAssertEqual(snapshot.targets.count, 1)
        let id = UUID().uuidString
        let p = try f.store.prepare(snapshot: snapshot, jobID: id)
        XCTAssertEqual(try Data(contentsOf: p.inputs[0]), try Data(contentsOf: source))
        for bad in ["", "..", "../외부", UUID().uuidString + "/child"] {
            XCTAssertThrowsError(try f.store.prepare(snapshot: snapshot, jobID: bad))
            f.store.discard(jobID: bad)
        }
        let foreignID = UUID().uuidString
        let foreign = f.root.appendingPathComponent(foreignID)
        try f.files.createDirectory(at: foreign, withIntermediateDirectories: false)
        XCTAssertThrowsError(try f.store.prepare(snapshot: snapshot, jobID: foreignID))
        f.store.discard(jobID: foreignID)
        XCTAssertTrue(f.files.fileExists(atPath: foreign.path))
        let jobDirectory = p.outputDirectory.deletingLastPathComponent()
        try f.files.removeItem(at: jobDirectory)
        try f.files.createSymbolicLink(at: jobDirectory, withDestinationURL: f.sandbox)
        f.store.discard(jobID: id)
        XCTAssertTrue(f.files.fileExists(atPath: source.path))
        XCTAssertThrowsError(try f.store.prepare(snapshot: snapshot, jobID: id))
        let sourceLink = f.sandbox.appendingPathComponent("원본링크.heic")
        try f.files.createSymbolicLink(at: sourceLink, withDestinationURL: source)
        f.put([Self.item([(.fileURL, Data(sourceLink.absoluteString.utf8))])])
        XCTAssertThrowsError(try f.store.capture())
    }

    @MainActor
    func testNewGenerationBeforeAndDuringWriteRemainsUntouched() throws {
        let f = try Fixture(writer: { board, _ in
            board.clearContents()
            XCTAssertTrue(board.setString("쓰기 도중 새 복사", forType: .string))
            return false
        }); defer { f.close() }
        let source = try f.source()
        let (snapshot, id, _, output) = try f.ready(source)
        let result = try f.output(output)
        f.putText("쓰기 이전 새 복사")
        let before = f.board.changeCount
        XCTAssertThrowsError(try f.store.publish(snapshot: snapshot, jobID: id, results: [result]))
        XCTAssertEqual(f.board.changeCount, before)
        XCTAssertEqual(f.board.string(forType: .string), "쓰기 이전 새 복사")
        f.store.discard(jobID: id)
        let (next, nextID, _, nextOutput) = try f.ready(source)
        let nextResult = try f.output(nextOutput)
        XCTAssertThrowsError(try f.store.publish(snapshot: next, jobID: nextID, results: [nextResult]))
        let after = f.board.changeCount
        XCTAssertNil(f.store.ownedChangeCount)
        f.store.discard(jobID: nextID)
        XCTAssertTrue(f.files.fileExists(atPath: nextResult.path))
        f.store.clipboardDidChange()
        XCTAssertEqual(f.board.changeCount, after)
        XCTAssertEqual(f.board.string(forType: .string), "쓰기 도중 새 복사")
        XCTAssertFalse(f.files.fileExists(atPath: nextResult.path))
        try f.store.shutdown()
        XCTAssertEqual(f.board.changeCount, after)
    }

    @MainActor
    func testFailedWriteRollsBackExactlyAndAllowsCaptureRetry() throws {
        var calls = 0
        let f = try Fixture(writer: { board, items in
            calls += 1
            if calls == 1 { _ = board.writeObjects(items); return false }
            return board.writeObjects(items)
        }); defer { f.close() }
        let source = try f.source()
        let (snapshot, id, _, output) = try f.ready(source)
        let original = try contents(f.board)
        let result = try f.output(output)
        XCTAssertThrowsError(try f.store.publish(snapshot: snapshot, jobID: id, results: [result])) {
            guard case AutomaticClipboardError.writeFailed = $0 else { return XCTFail("예상한 게시 실패가 아닙니다: \($0)") }
        }
        XCTAssertEqual(try contents(f.board), original)
        XCTAssertEqual(f.store.ownedChangeCount, f.board.changeCount)
        XCTAssertEqual(try f.store.capture().targets.count, 1)
        f.store.discard(jobID: id)
        f.store.clipboardDidChange()
        XCTAssertTrue(f.files.fileExists(atPath: result.path))
        try f.store.shutdown()
        XCTAssertFalse(f.files.fileExists(atPath: result.path))
        XCTAssertEqual(try contents(f.board), original)
    }

    @MainActor
    func testRollbackAndShutdownRestoreFailureProtectExposedFilesUntilSuccessfulRetry() throws {
        var writingWorks = false
        let f = try Fixture(writer: { board, items in writingWorks && board.writeObjects(items) }); defer { f.close() }
        let source = try f.source()
        let (snapshot, id, _, output) = try f.ready(source)
        let original = try contents(f.board)
        let result = try f.output(output)
        XCTAssertThrowsError(try f.store.publish(snapshot: snapshot, jobID: id, results: [result]))
        XCTAssertEqual(f.store.ownedChangeCount, f.board.changeCount)
        f.store.discard(jobID: id)
        f.store.clipboardDidChange()
        XCTAssertTrue(f.files.fileExists(atPath: result.path))
        XCTAssertThrowsError(try f.store.capture())
        XCTAssertThrowsError(try f.store.shutdown())
        XCTAssertTrue(f.files.fileExists(atPath: result.path))
        f.store.clipboardDidChange()
        XCTAssertTrue(f.files.fileExists(atPath: result.path))
        writingWorks = true
        try f.store.shutdown()
        XCTAssertEqual(try contents(f.board), original)
        XCTAssertFalse(f.files.fileExists(atPath: result.path))
    }

    @MainActor
    func testSuccessfulPublishThenShutdownFailureKeepsPublishedFilesAndExternalCopy() throws {
        var writingWorks = true
        let f = try Fixture(writer: { board, items in writingWorks && board.writeObjects(items) }); defer { f.close() }
        let (snapshot, id, _, output) = try f.ready(f.source())
        let result = try f.output(output)
        _ = try f.store.publish(snapshot: snapshot, jobID: id, results: [result])
        writingWorks = false
        XCTAssertThrowsError(try f.store.shutdown())
        f.store.discard(jobID: id)
        f.store.clipboardDidChange()
        XCTAssertTrue(f.files.fileExists(atPath: result.path))
        f.putText("종료 도중 외부 복사")
        let external = f.board.changeCount
        try f.store.shutdown()
        XCTAssertEqual(f.board.changeCount, external)
        XCTAssertEqual(f.board.string(forType: .string), "종료 도중 외부 복사")
        XCTAssertFalse(f.files.fileExists(atPath: result.path))
    }

    @MainActor
    func testItemLookupFailureKeepsFilesUntilUnreferencedClipboardCanBeRead() throws {
        var lookupFails = false
        let f = try Fixture(cleanupItemsReader: { lookupFails ? nil : $0.pasteboardItems })
        defer { f.close() }
        let (snapshot, id, _, output) = try f.ready(f.source())
        let result = try f.output(output)
        _ = try f.store.publish(snapshot: snapshot, jobID: id, results: [result])
        // 새 복사가 같은 결과를 참조하더라도 항목 조회 자체는 실패할 수 있다.
        f.put([Self.item([(.fileURL, Data(result.absoluteString.utf8))])])
        let generation = f.board.changeCount
        XCTAssertFalse(try XCTUnwrap(f.board.types).isEmpty)
        lookupFails = true
        f.store.clipboardDidChange()
        f.store.discard(jobID: id)
        XCTAssertTrue(f.files.fileExists(atPath: result.path))
        try f.store.shutdown()
        XCTAssertTrue(f.files.fileExists(atPath: result.path))
        XCTAssertEqual(f.board.changeCount, generation)
        XCTAssertEqual(f.board.string(forType: .fileURL), result.absoluteString)
        lookupFails = false
        f.store.clipboardDidChange()
        XCTAssertTrue(f.files.fileExists(atPath: result.path))
        f.putText()
        lookupFails = true
        f.store.clipboardDidChange()
        XCTAssertTrue(f.files.fileExists(atPath: result.path), "조회 실패를 참조 부재로 취급하면 안 됩니다.")
        lookupFails = false
        f.store.clipboardDidChange()
        XCTAssertFalse(f.files.fileExists(atPath: result.path))
    }

    @MainActor
    func testCleanupTracksPublicURLFileAndDirectoryAncestorsAndUnknownPromises() throws {
        let f = try Fixture(); defer { f.close() }
        let (snapshot, id, _, output) = try f.ready(f.source())
        let result = try f.output(output)
        _ = try f.store.publish(snapshot: snapshot, jobID: id, results: [result])
        let jobDirectory = output.deletingLastPathComponent()
        for reference in [result, jobDirectory, f.root, f.sandbox] {
            f.put([Self.item([(.URL, Data(reference.absoluteString.utf8))])])
            f.store.clipboardDidChange()
            f.store.discard(jobID: id)
            XCTAssertTrue(f.files.fileExists(atPath: result.path), reference.path)
        }
        f.put([Self.item([(.init("com.apple.pasteboard.promised-file-url"), Data())])])
        f.store.clipboardDidChange()
        XCTAssertTrue(f.files.fileExists(atPath: result.path))
        f.put([Self.item([(.URL, Data("https://example.com/".utf8))])])
        f.store.clipboardDidChange()
        XCTAssertFalse(f.files.fileExists(atPath: result.path))
        XCTAssertEqual(f.board.string(forType: .URL), "https://example.com/")
    }
}
