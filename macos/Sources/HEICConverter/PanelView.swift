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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var closeFocused: Bool
    @FocusState private var dropFocused: Bool
    @StateObject private var presentation = PanelPresentationState()
    private var dropHighlighted: Bool { model.dropTargeted || presentation.dropHovered || dropFocused }
    private var dropTitle: String {
        if model.dropTargeted { return "여기에 놓아서 파일 선택" }
        switch presentation.dropFeedback {
        case .idle: return "파일을 놓거나 클릭해 붙여넣기"
        case .loading: return "파일을 확인하고 있습니다"
        case .accepted: return "HEIC 파일을 선택했습니다"
        case .rejected: return "추가할 수 없는 파일입니다"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(14)
            Divider().padding(.horizontal, 14)
            OverlayScrollView {
                VStack(alignment: .leading, spacing: 12) {
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
                }.padding(14)
                    .buttonStyle(PanelActionButtonStyle()).controlSize(.regular)
            }
            Divider().padding(.horizontal, 14)
            footer.padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                if reduceTransparency {
                    Color(nsColor: .windowBackgroundColor)
                } else {
                    PanelGlass(opacity: 1)
                    Color(nsColor: .windowBackgroundColor).opacity(contrast == .increased ? 1 : 0.9)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(contrast == .increased ? Color.primary.opacity(0.5) : Color.white.opacity(colorScheme == .dark ? 0.22 : 0.6), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .controlSize(.regular)
        .buttonStyle(PanelActionButtonStyle())
        .onChange(of: removablePaths) { _, paths in presentation.selectedPaths.formIntersection(paths) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.badge.arrow.down.fill")
                .font(.title2).foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
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
        Button(action: model.paste) {
            VStack(spacing: 6) {
                if presentation.dropFeedback == .loading {
                    ProgressView().controlSize(.small).frame(height: 22)
                } else {
                    Image(systemName: model.dropTargeted ? "arrow.down.circle.fill"
                          : presentation.dropFeedback == .accepted ? "checkmark.circle"
                          : presentation.dropFeedback == .rejected ? "exclamationmark.circle" : "arrow.down.doc")
                        .font(.system(size: 22)).foregroundStyle(Color.accentColor).accessibilityHidden(true)
                }
                Text(dropTitle).font(.headline).foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text("Finder에서 HEIC 파일을 복사한 뒤 클릭하세요")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 100).padding(12)
            .background(Color.accentColor.opacity(model.dropTargeted ? 0.2 : dropHighlighted ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor.opacity(dropHighlighted ? 0.85 : 0.35),
                        style: StrokeStyle(lineWidth: model.dropTargeted ? 2 : dropFocused ? 1.5 : presentation.dropHovered ? 1.5 : 1,
                                           dash: model.dropTargeted || dropFocused ? [] : [5, 4])))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .keyboardShortcut("v", modifiers: .command)
        .focused($dropFocused).focusEffectDisabled()
        .accessibilityLabel("HEIC 파일 붙여넣기")
        .accessibilityHint("Finder에서 복사한 HEIC 파일을 대기 목록에 추가합니다. 파일을 끌어놓을 수도 있습니다.")
        .onHover { presentation.dropHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: dropHighlighted)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: model.dropTargeted)
        .onChange(of: model.staged.isEmpty) { _, empty in
            if empty && presentation.dropFeedback == .accepted { presentation.dropFeedback = .idle }
        }
        .help("Photos 직접 드롭은 아직 지원하지 않습니다. Photos에서 수정되지 않은 HEIC 원본을 내보낸 뒤 Finder에서 드롭하세요.")
        .onDrop(of: [UTType.fileURL.identifier] + NSFilePromiseReceiver.readableDraggedTypes,
                isTargeted: $model.dropTargeted, perform: drop)
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
                Button("취소", action: model.cancelStaged)
                Spacer()
                Button("대기 목록에 추가") { model.acceptStaged(convert: false) }
                Button("지금 변환") { model.acceptStaged(convert: true) }.buttonStyle(PanelActionButtonStyle(tone: .accent))
            }
        }.glassCard()
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { presentation.settingsExpanded.toggle() } label: {
                HStack {
                    Label("변환 설정", systemImage: "slider.horizontal.3").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(presentation.settingsExpanded ? "접기" : "펼치기").font(.caption)
                    Image(systemName: presentation.settingsExpanded ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold))
                }.foregroundStyle(.primary).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("변환 설정")
            .accessibilityValue(presentation.settingsExpanded ? "펼침" : "접힘")
            .help("형식·품질·저장 위치를 요약합니다. 펼치면 메타데이터와 동일 이름 정책도 변경할 수 있습니다.")
            if presentation.settingsExpanded {
                expandedSettings
            } else {
                HStack(spacing: 6) {
                    formatSegments.frame(width: 104, height: 22)
                    Text(model.settings.options.outputFormat == "jpeg"
                         ? "\(model.settings.options.qualityPreset.label) · 품질 \(model.settings.options.jpegQuality)"
                         : "\(model.settings.options.pngCompressionPreset.label) · 압축 \(model.settings.options.pngCompression)")
                        .font(.system(size: 10)).fixedSize()
                    outputLocation(editable: false).frame(maxWidth: .infinity, alignment: .trailing)
                }

            }
        }.glassCard()
    }

    private var expandedSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            formatSegments.frame(height: 26)
            if model.settings.options.outputFormat == "jpeg" {
                CompactSegments(title: "JPEG 품질", selection: $model.settings.options.qualityPreset,
                                choices: QualityPreset.allCases.map { SegmentChoice(value: $0, title: $0.label) })
                    .frame(height: 26)
                    .help("Low 60 · Medium 80 · High 90 · Raw 100. 인코더 설정값이며 백분율이 아닙니다. Raw도 손실 JPEG입니다.")
                Text("품질 \(model.settings.options.jpegQuality) · Low 60 / Medium 80 / High 90 / Raw 100")
                    .font(.caption).foregroundStyle(.primary)
            } else {
                CompactSegments(title: "PNG 압축", selection: $model.settings.options.pngCompressionPreset,
                                choices: PNGCompressionPreset.displayOrder.map { SegmentChoice(value: $0, title: $0.label) })
                    .frame(height: 26)
                Text("압축 \(model.settings.options.pngCompression) · 화질은 같고 저장 시간과 크기가 달라집니다.")
                    .font(.caption).foregroundStyle(.primary)
                Text("네이티브 HDR PNG에는 이 압축 설정이 적용되지 않습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("메타데이터").font(.caption).foregroundStyle(.secondary)
                    Picker("메타데이터", selection: $model.settings.options.metadata) {
                        Text("안전 보존").tag("safe"); Text("모두 보존").tag("preserve"); Text("제거").tag("strip")
                    }.labelsHidden()
                }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 4) {
                    Text("동일 이름").font(.caption).foregroundStyle(.secondary)
                    Picker("동일 이름", selection: $model.settings.options.onConflict) {
                        Text("새 이름").tag("rename"); Text("건너뛰기").tag("skip"); Text("덮어쓰기").tag("overwrite"); Text("오류").tag("error")
                    }.labelsHidden()
                }.frame(maxWidth: .infinity)
            }
            outputLocation(editable: true)
        }
    }

    private var formatSegments: some View {
        CompactSegments(title: "형식", selection: $model.settings.options.outputFormat,
                        choices: [SegmentChoice(value: "jpeg", title: "JPEG"), SegmentChoice(value: "png", title: "PNG")])
    }

    private func outputLocation(editable: Bool) -> some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            Image(systemName: "folder").foregroundStyle(.secondary).accessibilityHidden(true)
            Text(model.settings.displayOutputDirectory).font(.caption).foregroundStyle(.primary)
                .lineLimit(1).truncationMode(.head).help(model.settings.outputDirectory)
            if editable {
                Button("변경", action: model.chooseOutput).accessibilityLabel("저장 위치 변경")
            }
        }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("파일 목록", systemImage: "photo.stack").font(.subheadline.weight(.semibold))
                Text("대기 \(model.waitingCount)개").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("재시도", action: model.retryFailures).font(.caption).buttonStyle(PanelActionButtonStyle(compact: true))
                    .accessibilityLabel("실패 재시도").disabled(!model.queue.items.contains { $0.status == .failed })
                Button("정리", action: model.clearCompleted).font(.caption).buttonStyle(PanelActionButtonStyle(compact: true))
                    .accessibilityLabel("완료 정리").disabled(!model.queue.items.contains { $0.status.finished })
            }
            if model.queue.items.isEmpty {
                Label("대기 중인 파일이 없습니다.", systemImage: "tray")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2)
            } else {
                HStack(spacing: 6) {
                    Button(allRemovableSelected ? "선택 해제" : "전체 선택") {
                        presentation.selectedPaths = allRemovableSelected ? [] : removablePaths
                    }.font(.caption).buttonStyle(PanelActionButtonStyle(compact: true)).disabled(removablePaths.isEmpty)
                    Text("선택 \(presentation.selectedPaths.count)개").font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("선택 삭제") { model.removeSelected(presentation.selectedPaths); presentation.selectedPaths.removeAll() }
                        .font(.caption).buttonStyle(PanelActionButtonStyle(compact: true)).disabled(presentation.selectedPaths.isEmpty)
                    Button("전체 삭제") { model.removeAll(); presentation.selectedPaths.removeAll() }
                        .font(.caption).buttonStyle(PanelActionButtonStyle(compact: true)).disabled(removablePaths.isEmpty)
                }
                Text("목록에서만 제거됩니다. 예약·변환 중인 항목은 유지됩니다.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                LazyVStack(spacing: 0) {
                    ForEach(model.queue.items) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Button {
                                if presentation.selectedPaths.contains(item.id) { presentation.selectedPaths.remove(item.id) }
                                else { presentation.selectedPaths.insert(item.id) }
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: item.status.locked ? "lock" : presentation.selectedPaths.contains(item.id) ? "checkmark.square.fill" : "square")
                                        .font(.caption).foregroundStyle(presentation.selectedPaths.contains(item.id) ? Color.accentColor : .secondary)
                                        .frame(width: 14, height: 32).accessibilityHidden(true)
                                    FileThumbnailView(url: item.url)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.url.lastPathComponent).font(.callout).lineLimit(1).help(item.id)
                                        Text(item.status.label).font(.caption).foregroundStyle(color(item.status))
                                        if let detail = item.detail { Text(detail).font(.caption2).foregroundStyle(.secondary) }
                                    }
                                    Spacer(minLength: 0)
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).disabled(item.status.locked)
                            .accessibilityLabel("\(item.url.lastPathComponent) 선택")
                            .accessibilityValue(presentation.selectedPaths.contains(item.id) ? "선택됨" : "선택 안 됨")
                            if let destination = item.destination { Button("결과") { model.reveal(destination) } }
                            if item.status == .failed { Button("재시도") { model.retry(item.id) } }
                            Button { model.remove(item.id) } label: { Image(systemName: "xmark").frame(width: 22, height: 22) }
                                .buttonStyle(.borderless).disabled(item.status.locked).accessibilityLabel("\(item.url.lastPathComponent) 제거").help("항목 제거")
                        }.padding(.vertical, 9).padding(.horizontal, 4)
                            .background(presentation.selectedPaths.contains(item.id) ? Color.accentColor.opacity(0.14) : .clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                        Divider()
                    }
                }
            }
        }.glassCard()
    }

    private var removablePaths: Set<String> { Set(model.queue.items.filter { !$0.status.locked }.map(\.id)) }
    private var allRemovableSelected: Bool {
        !removablePaths.isEmpty && presentation.selectedPaths == removablePaths
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.message).font(.caption).foregroundStyle(.primary).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if model.active {
                HStack {
                    ProgressView().controlSize(.small)
                    Button(model.cancelling ? "취소 대기 중" : "현재 파일 완료 후 취소", action: model.cancel).disabled(model.cancelling)
                }
            }
            Button(action: model.startWaiting) {
                Label(model.active ? "대기 파일 변환 예약" : "대기 목록 변환 시작", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(PanelActionButtonStyle(tone: .accent))
            .disabled(!model.queue.items.contains { $0.status == .waiting })
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    clipboardButton
                    Spacer(minLength: 0)
                    outputButton
                    quitButton
                }
                VStack(spacing: 8) {
                    clipboardButton
                    HStack(spacing: 8) { outputButton; quitButton }
                }.frame(maxWidth: .infinity)
            }
            if let status = model.clipboardMessage { Text(status).font(.caption).foregroundStyle(.primary) }
        }
    }

    private var clipboardButton: some View {
        Button { model.setClipboard(!model.settings.clipboardEnabled) } label: {
            Label(model.settings.clipboardEnabled ? "클립보드 감지 켜짐" : "클립보드 감지 꺼짐",
                  systemImage: model.settings.clipboardEnabled ? "checkmark.circle.fill" : "minus.circle")
                .font(.caption.weight(.semibold)).fixedSize()
        }
        .buttonStyle(PanelActionButtonStyle(tone: model.settings.clipboardEnabled ? .detection : .neutral))
        .accessibilityLabel("클립보드 감지")
        .accessibilityValue(model.settings.clipboardEnabled ? "켜짐" : "꺼짐")
        .help(model.settings.clipboardEnabled ? "클립보드 감지 끄기" : "클립보드 감지 켜기")
    }

    private var outputButton: some View {
        Button("폴더 열기", action: model.openOutput).font(.caption.weight(.medium)).fixedSize()
            .accessibilityLabel("저장 폴더 열기")
    }

    private var quitButton: some View {
        Button("앱 종료") { NSApplication.shared.terminate(nil) }
            .font(.caption.weight(.semibold)).fixedSize()
            .buttonStyle(PanelActionButtonStyle(tone: .destructive))
    }

    private func drop(_ providers: [NSItemProvider]) -> Bool {
        let dropID = UUID()
        presentation.latestDropID = dropID
        let supported = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !supported.isEmpty else {
            presentation.dropFeedback = .rejected
            model.message = "Photos 직접 드롭은 아직 지원하지 않습니다. HEIC 원본을 내보낸 뒤 Finder에서 추가하세요."
            return false
        }
        presentation.dropFeedback = .loading
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
            if urls.isEmpty {
                if presentation.latestDropID == dropID {
                    presentation.dropFeedback = .rejected
                    model.message = "파일 URL을 읽지 못했습니다. Photos 사진은 HEIC 원본을 내보낸 뒤 Finder에서 추가하세요."
                }
            } else {
                let previousCount = model.staged.count
                model.stage(urls, updateNotices: presentation.latestDropID == dropID)
                if presentation.latestDropID == dropID {
                    presentation.dropFeedback = model.staged.count > previousCount ? .accepted : .rejected
                }
            }
        }
        return true
    }
    private func color(_ status: FileStatus) -> Color {
        switch status { case .succeeded: return .green; case .failed: return .red; case .running: return .accentColor; default: return .secondary }
    }
}

private struct SegmentChoice<Value: Hashable> {
    let value: Value
    let title: String
}

/// 네이티브 선택·키보드 동작을 유지하면서 작은 글꼴을 명시한다.
private struct CompactSegments<Value: Hashable>: NSViewRepresentable {
    let title: String
    @Binding var selection: Value
    let choices: [SegmentChoice<Value>]

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.segmentStyle = .rounded
        control.trackingMode = .selectOne
        control.controlSize = .small
        control.font = .systemFont(ofSize: 11, weight: .medium)
        control.target = context.coordinator
        control.action = #selector(Coordinator.select(_:))
        return control
    }
    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        control.segmentCount = choices.count
        for (index, choice) in choices.enumerated() { control.setLabel(choice.title, forSegment: index) }
        control.selectedSegment = choices.firstIndex { $0.value == selection } ?? -1
        control.setAccessibilityLabel(title)
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    final class Coordinator: NSObject {
        var parent: CompactSegments
        init(parent: CompactSegments) { self.parent = parent }
        @objc func select(_ sender: NSSegmentedControl) {
            guard parent.choices.indices.contains(sender.selectedSegment) else { return }
            parent.selection = parent.choices[sender.selectedSegment].value
        }
    }
}

/// 네이티브 오버레이 스크롤바를 사용하여 좌우 여백을 동일하게 유지한다.
private struct OverlayScrollView<Content: View>: NSViewRepresentable {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = PanelScrollView()
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        let hosting = NSHostingView(rootView: hostedContent(context: context))
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hosting
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hosting.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            hosting.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        return scrollView
    }
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        (scrollView.documentView as? NSHostingView<AnyView>)?.rootView =
            hostedContent(context: context)
    }

    private func hostedContent(context: Context) -> AnyView {
        AnyView(content
            .environment(\.colorScheme, context.environment.colorScheme)
            .environment(\.layoutDirection, context.environment.layoutDirection)
            .environment(\.locale, context.environment.locale)
            .environment(\.isEnabled, context.environment.isEnabled))
    }

    private final class PanelScrollView: NSScrollView {
        // 이 패널은 시스템 선호가 변경돼도 스크롤바 공간을 차감하지 않는다.
        override var scrollerStyle: NSScroller.Style {
            get { super.scrollerStyle }
            set { super.scrollerStyle = .overlay }
        }
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
        content.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity((reduceTransparency || contrast == .increased) ? 1 : (colorScheme == .dark ? 0.72 : 0.82)), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(contrast == .increased ? 0.4 : 0.08), lineWidth: 1).allowsHitTesting(false))
    }
}

private extension View {
    func glassCard() -> some View { modifier(GlassCard()) }
}

@MainActor private final class PanelPresentationState: ObservableObject {
    enum DropFeedback { case idle, loading, accepted, rejected }
    @Published var settingsExpanded = false
    @Published var selectedPaths: Set<String> = []
    @Published var dropHovered = false
    @Published var dropFeedback: DropFeedback = .idle
    var latestDropID = UUID()
}

@MainActor private final class PanelButtonInteractionState: ObservableObject {
    @Published var hovered = false
}

/// 창 활성 여부와 무관하게 상태 색과 공통 모서리를 유지한다.
private struct PanelActionButtonStyle: ButtonStyle {
    enum Tone { case neutral, accent, detection, destructive }
    var tone: Tone = .neutral
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        PanelActionButtonBody(configuration: configuration, tone: tone, compact: compact)
    }
}

private struct PanelActionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let tone: PanelActionButtonStyle.Tone
    let compact: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var interaction = PanelButtonInteractionState()
    private var hovered: Bool { interaction.hovered }

    private var tint: Color {
        switch tone {
        case .accent: return .accentColor
        case .detection: return .blue
        case .destructive: return Color(red: 0.82, green: 0.12, blue: 0.18)
        case .neutral: return .primary
        }
    }
    private var filled: Bool { tone == .accent || tone == .destructive }
    private var usesDarkFilledForeground: Bool {
        guard tone == .accent, let color = NSColor.controlAccentColor.usingColorSpace(.sRGB) else { return false }
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(color.redComponent) + 0.7152 * linear(color.greenComponent)
            + 0.0722 * linear(color.blueComponent)
        return luminance > 0.179
    }
    private var filledForeground: Color { usesDarkFilledForeground ? .black : .white }
    var body: some View {
        configuration.label
            .foregroundStyle(enabled ? (filled ? filledForeground : tint) : Color.secondary)
            .padding(.horizontal, compact ? 8 : 10).padding(.vertical, compact ? 5 : 9)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(enabled && filled ? tint : tint.opacity(enabled ? (hovered ? 0.18 : 0.1) : 0.06))
                    .overlay {
                        if enabled && filled {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill((usesDarkFilledForeground ? Color.white : Color.black)
                                    .opacity(configuration.isPressed ? 0.2 : hovered ? 0.12 : 0))
                        } else if enabled && configuration.isPressed {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.12))
                        }
                    }.allowsHitTesting(false)
            }
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(enabled ? (hovered ? 0.45 : 0.2) : 0.08), lineWidth: 1).allowsHitTesting(false))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: enabled && hovered ? tint.opacity(0.18) : .clear, radius: 3, y: 1)
            .scaleEffect(enabled && configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .onHover { interaction.hovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct NeutralCloseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(.secondary)
            .background(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.06), in: Circle())
            .contentShape(Circle())
    }
}
