import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ConverterKit

struct PanelView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "photo.badge.arrow.down.fill").font(.title2).foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text("HEIC Converter").font(.title3.bold())
                    Text("원본을 보존하며 JPEG · PNG로 변환").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("붙여넣기", action: model.paste).keyboardShortcut("v", modifiers: .command)
            }
            VStack(spacing: 7) {
                Image(systemName: "arrow.down.doc").font(.largeTitle).foregroundStyle(.blue)
                Text("HEIC 파일을 여기에 놓으세요").font(.headline)
                Text("파일을 놓은 뒤 변환하거나 대기 목록에 추가할 수 있습니다.").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(18)
            .background(model.dropTargeted ? Color.blue.opacity(0.18) : Color.blue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.blue.opacity(model.dropTargeted ? 0.8 : 0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $model.dropTargeted, perform: drop)

            if !model.staged.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("선택한 파일 \(model.staged.count)개").font(.headline)
                    ScrollView { VStack(alignment: .leading) {
                        ForEach(model.staged, id: \.path) { Text($0.lastPathComponent).font(.caption).help($0.path) }
                    }.frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 70)
                    HStack {
                        Button("취소") { model.staged.removeAll() }
                        Spacer()
                        Button("대기 목록에 추가") { model.acceptStaged(convert: false) }
                        Button("지금 변환") { model.acceptStaged(convert: true) }.buttonStyle(.borderedProminent)
                    }
                }.padding(10).background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
            settings
            Divider()
            HStack {
                Text("파일 목록 · 대기 \(model.waitingCount)개").font(.headline)
                Spacer()
                Button("실패 재시도", action: model.retryFailures).disabled(!model.queue.items.contains { $0.status == .failed })
                Button("완료 정리") { model.queue.clearCompleted() }.disabled(!model.queue.items.contains { $0.status.finished })
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    if model.queue.items.isEmpty {
                        Text("대기 중인 파일이 없습니다.").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(30)
                    }
                    ForEach(model.queue.items) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: icon(item.status)).foregroundStyle(color(item.status)).frame(width: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.url.lastPathComponent).font(.callout).lineLimit(1).help(item.id)
                                Text(item.status.label).font(.caption).foregroundStyle(color(item.status))
                                if let detail = item.detail { Text(detail).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled) }
                            }
                            Spacer(minLength: 0)
                            if let destination = item.destination { Button("결과") { model.reveal(destination) } }
                            if item.status == .failed { Button("재시도") { model.retry(item.id) } }
                            Button { model.queue.remove(item.id) } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).disabled(item.status.locked).help("항목 제거")
                        }.padding(.vertical, 9)
                        Divider()
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(minHeight: 100, maxHeight: .infinity)
            if !model.notices.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(model.notices.enumerated()), id: \.offset) { _, notice in
                            Text("\(URL(fileURLWithPath: notice.path).lastPathComponent): \(notice.reason)").font(.caption).foregroundStyle(.orange)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 65)
            }
            Text(model.message).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if model.active {
                    ProgressView().controlSize(.small)
                    Button(model.cancelling ? "취소 대기 중" : "현재 파일 완료 후 취소", action: model.cancel).disabled(model.cancelling)
                }
                Spacer()
                Button(model.active ? "대기 파일 변환 예약" : "대기 목록 변환 시작", action: model.startWaiting)
                    .buttonStyle(.borderedProminent).disabled(!model.queue.items.contains { $0.status == .waiting })
            }
            Divider()
            HStack {
                Toggle("클립보드 감지", isOn: Binding(get: { model.settings.clipboardEnabled }, set: model.setClipboard)).toggleStyle(.switch).controlSize(.small)
                Spacer()
                Button("저장 폴더 열기", action: model.openOutput)
                Button("앱 종료") { NSApplication.shared.terminate(nil) }
            }
            if let status = model.clipboardMessage { Text(status).font(.caption).foregroundStyle(.orange) }
        }
        .padding(18).frame(minWidth: 540, idealWidth: 570, minHeight: 690)
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Picker("형식", selection: $model.settings.options.outputFormat) { Text("JPEG").tag("jpeg"); Text("PNG").tag("png") }.pickerStyle(.segmented).frame(width: 170)
                if model.settings.options.outputFormat == "jpeg" {
                    Text("품질 \(model.settings.options.jpegQuality)").font(.caption).frame(width: 65)
                    Slider(value: Binding(get: { Double(model.settings.options.jpegQuality) }, set: { model.settings.options.jpegQuality = Int($0) }), in: 1...100, step: 1)
                } else {
                    Text("압축 \(model.settings.options.pngCompression)").font(.caption).frame(width: 65)
                    Slider(value: Binding(get: { Double(model.settings.options.pngCompression) }, set: { model.settings.options.pngCompression = Int($0) }), in: 0...9, step: 1)
                }
            }
            HStack {
                Picker("메타데이터", selection: $model.settings.options.metadata) {
                    Text("안전 보존").tag("safe"); Text("모두 보존").tag("preserve"); Text("제거").tag("strip")
                }
                Picker("동일 이름", selection: $model.settings.options.onConflict) {
                    Text("새 이름").tag("rename"); Text("건너뛰기").tag("skip"); Text("덮어쓰기").tag("overwrite"); Text("오류").tag("error")
                }
            }
            HStack {
                Image(systemName: "folder").foregroundStyle(.secondary)
                Text(model.settings.outputDirectory).font(.caption).lineLimit(1).truncationMode(.middle).help(model.settings.outputDirectory)
                Spacer(); Button("저장 위치 변경", action: model.chooseOutput)
            }
            if model.settings.options.outputFormat == "png" {
                Text("HDR은 지원 조건을 만족할 때 적용됩니다. 네이티브 HDR PNG에는 압축 수준이 적용되지 않을 수 있습니다.").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
    private func drop(_ providers: [NSItemProvider]) -> Bool {
        let supported = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !supported.isEmpty else { return false }
        Task { @MainActor in
            var urls: [URL] = []
            for provider in supported {
                let url: URL? = await withCheckedContinuation { continuation in
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { value, _ in
                        if let data = value as? Data { continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil)) }
                        else if let url = value as? URL { continuation.resume(returning: url) }
                        else { continuation.resume(returning: nil) }
                    }
                }
                if let url { urls.append(url) }
            }
            model.stage(urls)
        }
        return true
    }
    private func icon(_ status: FileStatus) -> String {
        switch status { case .waiting: return "clock"; case .scheduled: return "calendar.badge.clock"; case .running: return "arrow.triangle.2.circlepath"; case .succeeded: return "checkmark.circle.fill"; case .skipped: return "forward.end"; case .failed: return "exclamationmark.circle.fill" }
    }
    private func color(_ status: FileStatus) -> Color {
        switch status { case .succeeded: return .green; case .failed: return .red; case .running: return .blue; default: return .secondary }
    }
}
