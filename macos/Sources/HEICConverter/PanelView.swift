import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ConverterKit

struct PanelView: View {
    @ObservedObject var model: AppModel
    var onClose: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var closeFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header.padding(18)
            Divider().padding(.horizontal, 18)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    dropZone
                    if !model.staged.isEmpty { stagedFiles }
                    settings
                    fileList
                    if !model.notices.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(model.notices.enumerated()), id: \.offset) { _, notice in
                                Label("\(URL(fileURLWithPath: notice.path).lastPathComponent): \(notice.reason)", systemImage: "exclamationmark.triangle")
                                    .font(.caption).foregroundStyle(.primary)
                            }
                        }.glassCard()
                    }
                }.padding(18)
            }
            Divider().padding(.horizontal, 18)
            footer.padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                if reduceTransparency {
                    Color(nsColor: .windowBackgroundColor)
                } else {
                    PanelGlass(opacity: contrast == .increased ? 1 : 0.72)
                    LinearGradient(colors: [Color.accentColor.opacity(colorScheme == .dark ? 0.06 : 0.04), .clear, .white.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(contrast == .increased ? Color.primary.opacity(0.5) : Color.white.opacity(colorScheme == .dark ? 0.22 : 0.6), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .controlSize(.regular)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.badge.arrow.down.fill")
                .font(.title2).foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("HEIC Converter").font(.title3.bold())
                Text("원본을 보존하며 JPEG · PNG로 변환").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 32, height: 32) }
                .buttonStyle(NeutralCloseButtonStyle()).accessibilityLabel("패널 숨기기").help("패널 숨기기 · 작업과 감지는 계속됩니다")
                .focused($closeFocused).focusEffectDisabled()
                .overlay(Circle().strokeBorder(Color.primary.opacity(closeFocused ? 0.45 : 0), lineWidth: 1.5).allowsHitTesting(false))
                .keyboardShortcut(.escape, modifiers: [])
        }
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc").font(.system(size: 28)).foregroundStyle(Color.accentColor).accessibilityHidden(true)
            Text("HEIC 파일을 여기에 놓으세요").font(.headline)
            HStack(spacing: 8) {
                Text("Finder 파일을 놓거나 붙여넣으세요.").font(.caption).foregroundStyle(.secondary)
                Button("붙여넣기", action: model.paste).keyboardShortcut("v", modifiers: .command)
            }
            Text("Photos 사진은 HEIC 원본을 내보낸 뒤 Finder에서 추가하세요.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(16)
        .background(Color.accentColor.opacity(model.dropTargeted ? 0.18 : 0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor.opacity(model.dropTargeted ? 0.8 : 0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        .help("Photos 직접 드롭은 아직 지원하지 않습니다. Photos에서 수정되지 않은 HEIC 원본을 내보낸 뒤 Finder에서 드롭하세요.")
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $model.dropTargeted, perform: drop)
    }

    private var stagedFiles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("선택한 파일 \(model.staged.count)개").font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.staged, id: \.path) { url in
                        HStack(spacing: 10) {
                            FileThumbnailView(url: url)
                            Text(url.lastPathComponent).font(.callout).lineLimit(1).help(url.path)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 120)
            HStack {
                Button("취소") { model.staged.removeAll() }
                Spacer()
                Button("대기 목록에 추가") { model.acceptStaged(convert: false) }
                Button("지금 변환") { model.acceptStaged(convert: true) }.buttonStyle(.borderedProminent)
            }
        }.glassCard()
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("변환 설정", systemImage: "slider.horizontal.3").font(.headline)
                Spacer()
                Picker("형식", selection: $model.settings.options.outputFormat) {
                    Text("JPEG").tag("jpeg"); Text("PNG").tag("png")
                }.pickerStyle(.segmented).frame(width: 160)
            }
            if model.settings.options.outputFormat == "jpeg" {
                HStack {
                    Text("품질").font(.caption).foregroundStyle(.secondary)
                    Picker("JPEG 품질", selection: $model.settings.options.qualityPreset) {
                        ForEach(QualityPreset.allCases) { preset in Text(preset.label).tag(preset) }
                    }.pickerStyle(.segmented).labelsHidden()
                }
                Text("JPEG 품질 \(model.settings.options.jpegQuality) · Low 60 / Medium 80 / High 90 / Raw 100")
                    .font(.caption).foregroundStyle(.secondary)
                if model.settings.options.qualityPreset == .raw {
                    Text("Raw도 손실 JPEG입니다. 최대 품질은 파일 크기가 크게 늘 수 있습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text("압축").font(.caption).foregroundStyle(.secondary)
                    Picker("PNG 압축", selection: $model.settings.options.pngCompressionPreset) {
                        ForEach(PNGCompressionPreset.allCases) { preset in Text(preset.label).tag(preset) }
                    }.pickerStyle(.segmented).labelsHidden()
                }
                Text("압축 수준 \(model.settings.options.pngCompression) · 화질은 동일하며 저장 시간과 파일 크기가 달라집니다.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("네이티브 HDR PNG에는 이 압축 설정이 적용되지 않습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Picker("메타데이터", selection: $model.settings.options.metadata) {
                    Text("안전 보존").tag("safe"); Text("모두 보존").tag("preserve"); Text("제거").tag("strip")
                }
                Picker("동일 이름", selection: $model.settings.options.onConflict) {
                    Text("새 이름").tag("rename"); Text("건너뛰기").tag("skip"); Text("덮어쓰기").tag("overwrite"); Text("오류").tag("error")
                }
            }
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "folder").foregroundStyle(.secondary).accessibilityHidden(true)
                Text(model.settings.displayOutputDirectory).font(.caption).lineLimit(1).truncationMode(.middle).help(model.settings.outputDirectory)
                Spacer(minLength: 0)
                Button("저장 위치 변경", action: model.chooseOutput)
            }
        }.glassCard()
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("파일 목록").font(.headline)
                Text("대기 \(model.waitingCount)개").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("실패 재시도", action: model.retryFailures).disabled(!model.queue.items.contains { $0.status == .failed })
                Button("완료 정리") { model.queue.clearCompleted() }.disabled(!model.queue.items.contains { $0.status.finished })
            }
            if model.queue.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray").font(.title2).accessibilityHidden(true)
                    Text("대기 중인 파일이 없습니다.").font(.caption)
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(model.queue.items) { item in
                        HStack(alignment: .top, spacing: 8) {
                            FileThumbnailView(url: item.url)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.url.lastPathComponent).font(.callout).lineLimit(1).help(item.id)
                                Text(item.status.label).font(.caption).foregroundStyle(color(item.status))
                                if let detail = item.detail { Text(detail).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled) }
                            }
                            Spacer(minLength: 0)
                            if let destination = item.destination { Button("결과") { model.reveal(destination) } }
                            if item.status == .failed { Button("재시도") { model.retry(item.id) } }
                            Button { model.queue.remove(item.id) } label: { Image(systemName: "xmark").frame(width: 22, height: 22) }
                                .buttonStyle(.borderless).disabled(item.status.locked).accessibilityLabel("\(item.url.lastPathComponent) 제거").help("항목 제거")
                        }.padding(.vertical, 9)
                        Divider()
                    }
                }
            }
        }.glassCard()
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.message).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            if model.active {
                HStack {
                    ProgressView().controlSize(.small)
                    Button(model.cancelling ? "취소 대기 중" : "현재 파일 완료 후 취소", action: model.cancel).disabled(model.cancelling)
                }
            }
            Button(action: model.startWaiting) {
                Label(model.active ? "대기 파일 변환 예약" : "대기 목록 변환 시작", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(!model.queue.items.contains { $0.status == .waiting })
            HStack(spacing: 12) {
                Toggle("클립보드 감지", isOn: Binding(get: { model.settings.clipboardEnabled }, set: model.setClipboard))
                    .toggleStyle(ClipboardDetectionStyle())
                Spacer(minLength: 0)
                Button("저장 폴더 열기", action: model.openOutput).controlSize(.large)
                Button("앱 종료") { NSApplication.shared.terminate(nil) }.controlSize(.large)
            }
            if let status = model.clipboardMessage { Text(status).font(.caption).foregroundStyle(.primary) }
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
    private func color(_ status: FileStatus) -> Color {
        switch status { case .succeeded: return .green; case .failed: return .red; case .running: return .accentColor; default: return .secondary }
    }
}

/// 창 뒤의 화면을 흐리게 하는 macOS 기본 유리 소재를 사용한다.
private struct PanelGlass: NSViewRepresentable {
    var opacity: CGFloat
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = opacity
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { nsView.alphaValue = opacity }
}

private struct GlassCard: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity((reduceTransparency || contrast == .increased) ? 1 : (colorScheme == .dark ? 0.18 : 0.22)), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(contrast == .increased ? 0.4 : 0.08), lineWidth: 1).allowsHitTesting(false))
    }
}

private extension View {
    func glassCard() -> some View { modifier(GlassCard()) }
}

/// 비활성 패널에서도 감지 상태를 색상과 글자로 함께 표시한다.
private struct ClipboardDetectionStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.label.font(.caption)
            Button { configuration.isOn.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "minus.circle")
                    Text(configuration.isOn ? "켜짐" : "꺼짐").font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 9).padding(.vertical, 7)
                .foregroundStyle(configuration.isOn ? Color.white : Color.primary)
                .background(configuration.isOn ? Color.blue : Color.primary.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("클립보드 감지")
            .accessibilityValue(configuration.isOn ? "켜짐" : "꺼짐")
        }
    }
}

private struct NeutralCloseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(.secondary)
            .background(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.06), in: Circle())
            .contentShape(Circle())
    }
}
