import SwiftUI
#if canImport(UIKit)
import AVFoundation
import UIKit
#endif

/// 识别进度状态机：校正 → OCR → 字段解析 → 人工确认。
struct ScanSession: Identifiable {
    let id = UUID()
    var originalData: Data
    var processedData: Data?
    var quad: CardQuad = .wholeImage
    var rawText: String?
    var fields: ParsedContactFields?
    var errorMessage: String?
    var stage: Stage = .correcting

    enum Stage {
        case correcting
        case recognizing
        case ready
        case failed
    }
}

struct ScannerView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var pickerSource: UIImagePickerController.SourceType?
    @State private var session: ScanSession?
    @State private var showEdit = false
    /// 手动录入模式不依赖识别会话；与 showEdit 分开保存草稿，
    /// 避免"识别失败 → 手动录入"时因 session 为 nil 而出现空白表单。
    @State private var manualDraft: CardDraft?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = pickerSource {
                    CameraPicker(source: image) { data in
                        pickerSource = nil
                        if let data { startRecognition(with: data) }
                    } onCancel: {
                        pickerSource = nil
                    }
                    .ignoresSafeArea()
                } else {
                    choiceView
                }
            }
            .navigationTitle("扫描名片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .accessibilityIdentifier("scanner-cancel")
                }
            }
            .overlay {
                if let session {
                    recognitionOverlay(session)
                }
            }
            .task {
                #if DEBUG
                // UI 测试：跳过相机，直接用打包内的合成名片图像走完整识别链路（T06 / T19）。
                if AppEnvironment.pendingInjectedScan,
                   let id = LaunchOptions.injectedScanFixtureID,
                   let data = Fixtures.imageData(id: id, variant: LaunchOptions.injectedScanVariant) {
                    startRecognition(with: data)
                }
                AppEnvironment.consumeInjectedScan()
                #endif
            }
            .sheet(isPresented: $showEdit, onDismiss: {
                // 识别成功或手动录入都结束本次扫描；识别失败且未进入表单时留在扫描页重试（T20）。
                let shouldClose = ScannerDismissal.shouldCloseScannerAfterEdit(
                    sessionReady: session?.stage == .ready,
                    isManualEntry: manualDraft != nil
                )
                session = nil
                manualDraft = nil
                if shouldClose { dismiss() }
            }) {
                if let session, let fields = session.fields, let raw = session.rawText {
                    CardEditView(
                        draft: CardDraft(
                            fields: fields,
                            rawOCRText: raw,
                            originalImageData: session.originalData,
                            processedImageData: session.processedData ?? session.originalData
                        ),
                        isNew: true
                    )
                } else if let manualDraft {
                    CardEditView(draft: manualDraft, isNew: true)
                }
            }
        }
    }

    private var choiceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("拍摄或导入一张名片")
                .font(.headline)
            switch cameraState {
            case .denied:
                // T03：权限被拒绝时给出明确说明与替代入口，不静默失败。
                Text("相机权限已被拒绝，可在系统设置中开启，或从照片库导入名片。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("camera-permission-denied")
                Button {
                    openSettings()
                } label: {
                    Label("前往设置", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("scanner-open-settings")
            case .unavailable:
                Text("当前设备没有可用相机，请从照片库导入名片。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("camera-unavailable")
            case .ready:
                Button {
                    pickerSource = .camera
                } label: {
                    Label("拍照", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("scanner-camera")
            }

            Button {
                pickerSource = .photoLibrary
            } label: {
                Label("从照片库导入", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("scanner-library")
        }
        .padding(32)
    }

    private enum CameraState {
        case ready, denied, unavailable
    }

    private var cameraState: CameraState {
        #if canImport(UIKit)
        switch LaunchOptions.cameraAuthorizationOverride {
        case "denied": return .denied
        case "authorized": return .ready
        default: break
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            return .denied
        default:
            return UIImagePickerController.isSourceTypeAvailable(.camera) ? .ready : .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    private func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    private func recognitionOverlay(_ session: ScanSession) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                switch session.stage {
                case .correcting:
                    ProgressView().controlSize(.large)
                    Text("正在检测并校正名片区域…")
                        .accessibilityIdentifier("scan-stage-correcting")
                case .recognizing:
                    ProgressView().controlSize(.large)
                    Text("正在识别文字…")
                        .accessibilityIdentifier("scan-stage-recognizing")
                case .failed:
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(session.errorMessage ?? "识别失败")
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("scan-error")
                    HStack {
                        Button("重试") { startRecognition(with: session.originalData) }
                        Button("手动录入") {
                            sessionErrorToManual(session)
                        }
                        .accessibilityIdentifier("scan-manual-fallback")
                    }
                case .ready:
                    EmptyView()
                }
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 16).fill(.background))
            .padding(40)
        }
    }

    private func startRecognition(with data: Data) {
        var current = ScanSession(originalData: data)
        session = current
        let extractor = environment.textExtractor
        Task {
            do {
                let corrected = try CardImageCorrector.correct(data)
                current.processedData = corrected.data
                current.quad = corrected.quad
                current.stage = .recognizing
                session = current

                let rawText = try await extractor.extractText(from: corrected.data)
                let fields = BusinessCardFieldParser().parse(rawText)
                current.rawText = rawText
                current.fields = fields
                current.stage = .ready
                session = current
                showEdit = true
            } catch {
                current.stage = .failed
                current.errorMessage = error.localizedDescription
                session = current
            }
        }
    }

    private func sessionErrorToManual(_ session: ScanSession) {
        manualDraft = CardDraft(
            fields: ParsedContactFields(),
            rawOCRText: session.rawText ?? "",
            originalImageData: session.originalData,
            processedImageData: session.processedData
        )
        self.session = nil
        showEdit = true
    }
}

#if canImport(UIKit)
struct CameraPicker: UIViewControllerRepresentable {
    let source: UIImagePickerController.SourceType
    let onImage: (Data?) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImage: (Data?) -> Void
        private let onCancel: () -> Void

        init(onImage: @escaping (Data?) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onImage(image?.normalizedUp().jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
#endif
