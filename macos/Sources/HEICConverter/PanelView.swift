import AppKit
import SwiftUI
import ConverterKit

struct PanelView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var chrome: PanelChromeState
    var onClose: () -> Void = {}
    // 스크롤 컨테이너 대신 실제 행을 배치해 필요한 패널 높이를 측정한다.
    var measuresContent = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var closeFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header.padding(14)
            Divider().padding(.horizontal, 14)
            clipboardToggle.padding(14)
            HStack {
                Text("현재 클립보드").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(model.clipboardFiles.count)개").font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 14).padding(.bottom, 8)
            if model.clipboardFiles.isEmpty {
                emptyState.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if measuresContent {
                fileRows(Array(model.clipboardFiles.prefix(3)))
            } else {
                OverlayScrollView {
                    fileRows(model.clipboardFiles)
                }
                // 새 클립보드로 바뀌면 첫 행부터 표시하고 상태 갱신 시에는 위치를 유지한다.
                .id(model.clipboardFiles.map(\.id))
            }
            Divider().padding(.horizontal, 14)
            guidance.padding(14)
        }
        .padding(.top, PanelPlacement.pointerHeight)
        .frame(maxWidth: .infinity, maxHeight: measuresContent ? nil : .infinity)
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
        .clipShape(PanelOutline(pointerX: chrome.pointerX))
        .overlay {
            PanelOutline(pointerX: chrome.pointerX)
                .stroke(contrast == .increased ? Color.primary.opacity(0.5) : Color.white.opacity(colorScheme == .dark ? 0.22 : 0.6), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .controlSize(.regular)
    }

    private func fileRows(_ files: [ClipboardDisplayFile]) -> some View {
        VStack(spacing: 0) {
            ForEach(files, id: \.id) { file in
                ClipboardFileRow(file: file)
                if file.id != files.last?.id { Divider().padding(.leading, 56) }
            }
        }.padding(.horizontal, 14)
    }

    private var header: some View {
        HStack(spacing: 12) {
            PhotoClipboardIconShape().fill(Color(white: contrast == .increased ? 0.25 : 0.40))
                .frame(width: 22, height: 24)
                .frame(width: 34, height: 34)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(white: contrast == .increased ? 0.60 : 0.90), lineWidth: 0.75)
                        .allowsHitTesting(false)
                }
                .accessibilityHidden(true)
            Text("HEIC Converter").font(.title3.bold())
            Spacer(minLength: 4)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 32, height: 32)
            }
            .buttonStyle(NeutralCloseButtonStyle())
            .accessibilityLabel("패널 숨기기")
            .help("패널 숨기기 · 자동 변환은 계속됩니다")
            .focused($closeFocused).focusEffectDisabled()
            .overlay(Circle().strokeBorder(Color.primary.opacity(closeFocused ? 0.45 : 0), lineWidth: 1.5).allowsHitTesting(false))
            .keyboardShortcut(.escape, modifiers: [])
        }
    }

    private var clipboardToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                Text("클립보드 자동 변환").font(.headline)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Toggle("클립보드 자동 변환", isOn: Binding(
                    get: { model.settings.clipboardEnabled },
                    set: { model.setClipboard($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .fixedSize()
                .accessibilityLabel("클립보드 자동 변환")
                .accessibilityHint("끄면 이후 자동 변환과 아직 게시하지 않은 결과의 게시를 중지합니다.")
            }
            Text(model.settings.clipboardEnabled ? "켜짐 · 복사한 HEIC를 자동으로 변환합니다" : "꺼짐 · 새로 복사한 내용은 변환하지 않습니다")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            PhotoClipboardIconShape().fill(.secondary).frame(width: 29, height: 32)
                .accessibilityHidden(true)
            Text("클립보드에 표시할 파일이 없습니다").font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text(model.settings.clipboardEnabled ? "Finder에서 HEIC 파일을 복사하세요." : "자동 변환을 켠 뒤 HEIC 파일을 복사하세요.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center).padding(.horizontal, 14).padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !model.message.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    if model.active {
                        ProgressView().controlSize(.small).accessibilityHidden(true)
                    }
                    Text(model.message).font(.caption).lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(model.message)
                        .accessibilityLabel(model.message)
                }
            }
            Text(!model.clipboardFiles.isEmpty && model.clipboardFiles.allSatisfy(\.isVideo)
                 ? "복사한 동영상의 클립보드 내용을 그대로 유지합니다."
                 : model.settings.clipboardEnabled
                 ? "변환 완료 후 ⌘V로 붙여넣으세요. 완료 전에는 원본이 전달될 수 있습니다."
                 : "이미 변환해 준비한 클립보드는 유지됩니다.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ClipboardFileRow: View {
    let file: ClipboardDisplayFile

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if file.isVideo {
                Image(systemName: "video.fill")
                    .font(.system(size: 19)).foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)
            } else if let url = file.url {
                FileThumbnailView(url: url)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 19)).foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(file.name).font(.callout.weight(.medium))
                    .lineLimit(1).truncationMode(.middle)
                    .help(file.name)
                Label(file.isVideo ? "변환 제외" : file.status.label, systemImage: statusIcon)
                    .font(.caption).foregroundStyle(statusColor)
                if let detail = file.detail, !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2).help(detail)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(file.name)
        .accessibilityValue([file.status.label, file.detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
    }

    private var statusIcon: String {
        switch file.status {
        case .ready: return "circle.dashed"
        case .converting: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .unsupported: return "minus.circle"
        }
    }

    private var statusColor: Color {
        switch file.status {
        case .ready, .unsupported: return .secondary
        case .converting: return .accentColor
        case .completed: return .green
        case .failed: return .red
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

private struct NeutralCloseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(.secondary)
            .background(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.06), in: Circle())
            .contentShape(Circle())
    }
}
