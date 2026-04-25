import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - ExamUploadSheet
//
// Upload flow for analyzing a professor's exam.
// Sources: Camera, Photo Library, Files (PDF).
// POST /api/exams/analyze (multipart)

struct ExamUploadSheet: View {
    let subjectId: String
    var onSuccess: (() -> Void)?

    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var phase: UploadPhase = .picking
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedFileData: Data?
    @State private var selectedFileName: String = ""
    @State private var errorMessage: String?

    // Tokens
    private var goldPrimary: Color { VitaColors.accentHover }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }
    private var cardBg: Color { VitaColors.surfaceCard.opacity(0.55) }

    enum UploadPhase {
        case picking
        case preview
        case uploading
        case success
        case error(String)
    }

    var body: some View {
        // vita-modals-ignore: camera/document sub-sheets are system UI
        VitaSheet(detents: [.medium]) {
            VStack(spacing: 24) {
                switch phase {
                case .picking:
                    pickingView
                case .preview:
                    previewView
                case .uploading:
                    uploadingView
                case .success:
                    successView
                case .error(let msg):
                    errorView(message: msg)
                }

                Spacer()
            }
        }
        // vita-modals-ignore: UIKit CameraPickerView wrapper — não é SwiftUI content
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                selectedImage = image
                selectedFileData = nil
                selectedFileName = "foto_prova.jpg"
                phase = .preview
            }
        }
        // vita-modals-ignore: UIKit document picker delegation
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(
                allowedTypes: [UTType.pdf, UTType.jpeg, UTType.png]
            ) { url in
                if let data = try? Data(contentsOf: url) {
                    selectedFileData = data
                    selectedFileName = url.lastPathComponent
                    selectedImage = nil
                    phase = .preview
                }
            }
        }
        .onChange(of: photosPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    selectedFileData = nil
                    selectedFileName = "galeria_prova.jpg"
                    phase = .preview
                }
            }
        }
    }

    // MARK: - Picking View

    private var pickingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(goldPrimary.opacity(0.60))

            VStack(spacing: 6) {
                Text("Analisar Prova")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(textPrimary)
                Text("Escolha como enviar a prova do professor")
                    .font(.system(size: 13))
                    .foregroundStyle(textDim)
            }

            VStack(spacing: 10) {
                sourceButton(icon: "camera.fill", title: "Tirar Foto", subtitle: "Use a câmera do celular") {
                    showCamera = true
                }

                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    sourceButtonLabel(icon: "photo.on.rectangle", title: "Escolher da Galeria", subtitle: "Selecione uma foto salva")
                }
                .buttonStyle(.plain)

                sourceButton(icon: "doc.fill", title: "Escolher Arquivo", subtitle: "PDF ou imagem") {
                    showDocumentPicker = true
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func sourceButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            sourceButtonLabel(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }

    private func sourceButtonLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(goldPrimary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(goldPrimary.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(textDim)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
        )
    }

    // MARK: - Preview View

    private var previewView: some View {
        VStack(spacing: 16) {
            Text("Prova selecionada")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(textPrimary)

            // Thumbnail preview
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // PDF icon fallback
                VStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(goldPrimary.opacity(0.60))
                    Text(selectedFileName)
                        .font(.system(size: 11))
                        .foregroundStyle(textDim)
                        .lineLimit(1)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(cardBg)
                )
            }

            HStack(spacing: 12) {
                Button("Cancelar") {
                    phase = .picking
                    selectedImage = nil
                    selectedFileData = nil
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(cardBg)
                )

                Button("Analisar") {
                    Task { await uploadExam() }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.surface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(goldPrimary)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Uploading View

    private var uploadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(goldPrimary)
                .scaleEffect(1.5)

            VStack(spacing: 6) {
                Text("Analisando com IA...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Text("Isso pode levar alguns segundos")
                    .font(.system(size: 12))
                    .foregroundStyle(textDim)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(VitaColors.dataGreen)

            VStack(spacing: 6) {
                Text("Prova analisada!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(textPrimary)
                Text("O perfil do professor foi atualizado")
                    .font(.system(size: 13))
                    .foregroundStyle(textDim)
            }

            Button("Fechar") {
                onSuccess?()
                dismiss()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(VitaColors.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(goldPrimary)
            )
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(VitaColors.dataRed)

            VStack(spacing: 6) {
                Text("Erro no envio")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(textDim)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Button("Cancelar") {
                    phase = .picking
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(cardBg))

                Button("Tentar novamente") {
                    Task { await uploadExam() }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.surface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(goldPrimary))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Upload Logic

    private func uploadExam() async {
        phase = .uploading

        // Build file data + metadata
        let fileData: Data
        let fileName: String
        let mimeType: String

        if let image = selectedImage,
           let jpegData = image.jpegData(compressionQuality: 0.85) {
            fileData = jpegData
            fileName = selectedFileName.isEmpty ? "prova.jpg" : selectedFileName
            mimeType = "image/jpeg"
        } else if let pdfData = selectedFileData {
            fileData = pdfData
            fileName = selectedFileName.isEmpty ? "prova.pdf" : selectedFileName
            mimeType = selectedFileName.hasSuffix(".pdf") ? "application/pdf" : "image/jpeg"
        } else {
            phase = .error("Nenhum arquivo selecionado")
            return
        }

        do {
            let _: ExamAnalyzeResponse = try await container.api.analyzeExam(
                fileData: fileData,
                fileName: fileName,
                mimeType: mimeType,
                subjectId: subjectId
            )
            phase = .success
        } catch {
            phase = .error("Falha ao analisar a prova. Tente novamente.")
        }
    }
}

// MARK: - Camera Picker Wrapper

struct CameraPickerView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker Wrapper

struct DocumentPickerView: UIViewControllerRepresentable {
    var allowedTypes: [UTType]
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                _ = url.startAccessingSecurityScopedResource()
                onPick(url)
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}
