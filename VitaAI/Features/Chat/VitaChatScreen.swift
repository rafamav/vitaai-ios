import SwiftUI
import PhotosUI

// MARK: - VitaChatScreen

struct VitaChatScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ChatViewModel?
    @State private var showVoiceMode: Bool = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Group {
            if let viewModel {
                chatContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ChatViewModel(
                    chatClient: container.chatClient,
                    api: container.api
                )
            }
        }
        .fullScreenCover(isPresented: $showVoiceMode) {
            VoiceModeScreen(
                viewModel: VoiceModeViewModel(chatClient: container.chatClient),
                onDismiss: { showVoiceMode = false }
            )
        }
    }

    @ViewBuilder
    private func chatContent(viewModel: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            ChatTopBar(viewModel: viewModel, onVoiceMode: { showVoiceMode = true }, onClose: { dismiss() })

            Divider()
                .background(VitaColors.surfaceBorder)

            if viewModel.messages.isEmpty {
                EmptyStateView(viewModel: viewModel, isInputFocused: $isInputFocused)
            } else {
                MessagesArea(viewModel: viewModel)
            }

            ChatInputBar(viewModel: viewModel, isInputFocused: $isInputFocused)
        }
        
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: Binding(
            get: { viewModel.showHistory },
            set: { viewModel.showHistory = $0 }
        )) {
            HistorySheet(viewModel: viewModel)
        }
    }
}

// MARK: - Top Bar

private struct ChatTopBar: View {
    let viewModel: ChatViewModel
    let onVoiceMode: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VitaColors.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar chat")

            // AI avatar
            ZStack {
                Circle()
                    .fill(VitaColors.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "cross.vial.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(VitaColors.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Vita IA")
                    .font(VitaTypography.titleMedium)
                    .foregroundColor(VitaColors.white)
                Text(viewModel.isStreaming ? "Digitando..." : "Assistente de estudos")
                    .font(VitaTypography.labelSmall)
                    .foregroundColor(
                        viewModel.isStreaming ? VitaColors.accent : VitaColors.textTertiary
                    )
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isStreaming)
            }

            Spacer()

            // Voice mode button
            Button(action: onVoiceMode) {
                ZStack {
                    Circle()
                        .fill(VitaColors.accent.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(VitaColors.accent)
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Modo voz")

            // New conversation
            Button {
                viewModel.newConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18))
                    .foregroundColor(VitaColors.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Nova conversa")

            // History
            Button {
                Task { await viewModel.loadHistory() }
                viewModel.showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18))
                    .foregroundColor(VitaColors.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Historico")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Messages Area

private struct MessagesArea: View {
    let viewModel: ChatViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            isStreaming: viewModel.isStreaming && message.id == viewModel.messages.last?.id,
                            onRetry: message.isError ? {
                                Task { await viewModel.retryLastMessage() }
                            } : nil
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.content) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = viewModel.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let isStreaming: Bool
    var onRetry: (() -> Void)? = nil

    @State private var cursorVisible: Bool = true

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 52)
                userBubble
            } else {
                assistantAvatar
                VStack(alignment: .leading, spacing: 8) {
                    assistantBubble
                    if message.isError, let onRetry {
                        RetryButton(action: onRetry)
                    }
                }
                Spacer(minLength: 52)
            }
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let image = message.uiImage {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: 200, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if message.content != "[Imagem]" || !message.hasImage {
                Text(message.content)
                    .font(VitaTypography.bodyMedium)
                    .foregroundColor(VitaColors.textPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(VitaColors.accent.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(VitaColors.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(VitaColors.accent.opacity(0.12))
                .frame(width: 28, height: 28)
            Image(systemName: "cross.vial.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(VitaColors.accent)
        }
        .alignmentGuide(.bottom) { d in d[.bottom] }
    }

    private var assistantBubble: some View {
        Group {
            if message.content.isEmpty && isStreaming {
                // Typing indicator: three pulsing dots
                TypingIndicator()
                    .padding(.vertical, 4)
            } else if isStreaming {
                // During streaming: plain text + cursor (avoid re-parsing markdown mid-stream)
                (Text(message.content)
                    .font(VitaTypography.bodyMedium)
                    .foregroundColor(VitaColors.textPrimary)
                + Text(cursorVisible ? " |" : "  ")
                    .font(VitaTypography.bodyMedium)
                    .foregroundColor(VitaColors.accent))
            } else {
                // Finished: render full Markdown
                VitaMarkdown(content: message.content)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.isError ? VitaColors.dataRed.opacity(0.06) : VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    message.isError ? VitaColors.dataRed.opacity(0.3) : VitaColors.glassBorder,
                    lineWidth: 1
                )
        )
        .onAppear {
            if isStreaming {
                startCursorBlink()
            }
        }
        .onChange(of: isStreaming) { streaming in
            if !streaming { cursorVisible = false }
        }
    }

    private func startCursorBlink() {
        withAnimation(
            .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
        ) {
            cursorVisible = false
        }
    }
}

// MARK: - Retry Button

private struct RetryButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                Text("Tentar novamente")
                    .font(VitaTypography.labelSmall)
            }
            .foregroundColor(VitaColors.dataRed)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(VitaColors.dataRed.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(VitaColors.dataRed.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(VitaColors.accent.opacity(phase == i ? 0.9 : 0.3))
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == i ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .padding(.vertical, 4)
        .task {
            // Cycle phase 0→1→2→0... until task is cancelled (view disappears)
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    let viewModel: ChatViewModel
    var isInputFocused: FocusState<Bool>.Binding

    private let suggestions = [
        "O que estudar hoje?",
        "Revise Cardiologia",
        "Monte um simulado"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(VitaColors.accent.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Circle()
                        .stroke(VitaColors.accent.opacity(0.2), lineWidth: 1)
                        .frame(width: 80, height: 80)
                    Image(systemName: "cross.vial.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(VitaColors.accent)
                }

                VStack(spacing: 6) {
                    Text("Vita IA")
                        .font(VitaTypography.headlineSmall)
                        .foregroundColor(VitaColors.white)
                    Text("Seu assistente de estudos de medicina")
                        .font(VitaTypography.bodySmall)
                        .foregroundColor(VitaColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Suggestion chips
                VStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        SuggestionChip(text: suggestion) {
                            viewModel.inputText = suggestion
                            isInputFocused.wrappedValue = true
                            Task { await viewModel.send() }
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

private struct SuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundColor(VitaColors.accent)
                Text(text)
                    .font(VitaTypography.labelMedium)
                    .foregroundColor(VitaColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Plus Menu (Attachments + Studio Actions)

private struct ChatPlusMenu: View {
    let onStudioSelect: (String) -> Void
    let onCamera: () -> Void
    let onGalleryItem: (PhotosPickerItem) -> Void
    @Binding var isPresented: Bool

    private struct StudioAction {
        let icon: String
        let label: String
        let prompt: String
    }

    private let studioActions: [StudioAction] = [
        StudioAction(icon: "brain.head.profile", label: "Gerar Flashcards",   prompt: "Gere flashcards sobre "),
        StudioAction(icon: "doc.text",           label: "Gerar Resumo",       prompt: "Faca um resumo completo sobre "),
        StudioAction(icon: "list.clipboard",     label: "Gerar Quiz",         prompt: "Gere um quiz sobre ")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Attachment section header
            Text("ANEXAR")
                .font(VitaTypography.labelSmall)
                .foregroundColor(VitaColors.textTertiary)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Camera
            Button {
                isPresented = false
                onCamera()
            } label: {
                menuRow(icon: "camera.fill", label: "Camera")
            }
            .buttonStyle(.plain)

            Divider()
                .background(VitaColors.surfaceBorder)
                .padding(.horizontal, 14)

            // Gallery (PhotosPicker)
            PhotosPicker(
                selection: Binding(
                    get: { nil },
                    set: { item in
                        if let item {
                            isPresented = false
                            onGalleryItem(item)
                        }
                    }
                ),
                matching: .images,
                photoLibrary: .shared()
            ) {
                menuRow(icon: "photo.fill", label: "Galeria")
            }
            .buttonStyle(.plain)

            Divider()
                .background(VitaColors.surfaceBorder)
                .padding(.horizontal, 14)
                .padding(.vertical, 2)

            // Studio section header
            Text("STUDIO")
                .font(VitaTypography.labelSmall)
                .foregroundColor(VitaColors.textTertiary)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 4)

            ForEach(studioActions, id: \.label) { action in
                Button {
                    isPresented = false
                    onStudioSelect(action.prompt)
                } label: {
                    menuRow(icon: action.icon, label: action.label)
                }
                .buttonStyle(.plain)

                if action.label != studioActions.last?.label {
                    Divider()
                        .background(VitaColors.surfaceBorder)
                        .padding(.horizontal, 14)
                }
            }
        }
        .padding(.bottom, 6)
        .background(VitaColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
    }

    @ViewBuilder
    private func menuRow(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(VitaColors.accent.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VitaColors.accent)
            }
            Text(label)
                .font(VitaTypography.bodyMedium)
                .foregroundColor(VitaColors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Pending Image Preview

private struct PendingImagePreview: View {
    let imageData: Data?
    let onRemove: () -> Void

    var body: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            HStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(VitaColors.glassBorder, lineWidth: 1)
                        )

                    Button(action: onRemove) {
                        ZStack {
                            Circle()
                                .fill(VitaColors.surface.opacity(0.85))
                                .frame(width: 22, height: 22)
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(VitaColors.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                    .accessibilityLabel("Remover imagem")
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Camera Capture View (UIKit bridge)

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data?) -> Void

        init(onCapture: @escaping (Data?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Compress to JPEG at 0.8 quality to keep size reasonable
                let data = image.jpegData(compressionQuality: 0.8)
                onCapture(data)
            } else {
                onCapture(nil)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}

// MARK: - Input Bar

private struct ChatInputBar: View {
    let viewModel: ChatViewModel
    var isInputFocused: FocusState<Bool>.Binding

    @State private var isListening: Bool = false
    @State private var showPlusMenu: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera: Bool = false
    @State private var isLoadingImage: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(VitaColors.surfaceBorder)

            // Pending image preview
            if viewModel.hasPendingImage {
                PendingImagePreview(
                    imageData: viewModel.pendingImageData,
                    onRemove: { viewModel.clearImageAttachment() }
                )
            }

            HStack(spacing: 10) {
                // Plus button — Studio actions + attachments
                Button {
                    showPlusMenu.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(showPlusMenu ? VitaColors.accent.opacity(0.18) : VitaColors.surfaceCard)
                            .frame(width: 34, height: 34)
                        if isLoadingImage {
                            ProgressView()
                                .tint(VitaColors.accent)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: showPlusMenu ? "xmark" : "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(showPlusMenu ? VitaColors.accent : VitaColors.textSecondary)
                                .animation(.easeInOut(duration: 0.15), value: showPlusMenu)
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingImage)
                .accessibilityLabel(showPlusMenu ? "Fechar menu" : "Abrir menu")
                .overlay(alignment: .bottomLeading) {
                    if showPlusMenu {
                        ChatPlusMenu(
                            onStudioSelect: { prompt in
                                viewModel.inputText = prompt
                                isInputFocused.wrappedValue = true
                            },
                            onCamera: {
                                showPlusMenu = false
                                showCamera = true
                            },
                            onGalleryItem: { item in
                                showPlusMenu = false
                                selectedPhotoItem = item
                            },
                            isPresented: $showPlusMenu
                        )
                        .frame(width: 250)
                        .offset(x: 0, y: -250)
                        .zIndex(100)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomLeading)))
                    }
                }
                .animation(.easeOut(duration: 0.18), value: showPlusMenu)

                TextField(
                    isListening ? "Ouvindo..." : "Pergunte para a Vita...",
                    text: Binding(
                        get: { viewModel.inputText },
                        set: { viewModel.inputText = $0 }
                    ),
                    axis: .vertical
                )
                .font(VitaTypography.bodyMedium)
                .foregroundColor(VitaColors.textPrimary)
                .tint(VitaColors.accent)
                .lineLimit(1...5)
                .focused(isInputFocused)
                .submitLabel(.send)
                .disabled(isListening)
                .onSubmit {
                    Task { await viewModel.send() }
                }

                // Mic button — appends transcribed text to input
                VitaMicButton(isListening: $isListening) { transcribed in
                    if viewModel.inputText.isEmpty {
                        viewModel.inputText = transcribed
                    } else {
                        viewModel.inputText += " " + transcribed
                    }
                }

                SendButton(viewModel: viewModel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isListening
                    ? VitaColors.dataRed.opacity(0.06)
                    : VitaColors.surfaceElevated
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isListening ? VitaColors.dataRed.opacity(0.25) : VitaColors.glassBorder,
                        lineWidth: 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isListening)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            isLoadingImage = true
            Task {
                defer {
                    isLoadingImage = false
                    selectedPhotoItem = nil
                }
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    let mimeType: String
                    if let contentType = newItem.supportedContentTypes.first?.preferredMIMEType {
                        mimeType = contentType
                    } else {
                        mimeType = "image/jpeg"
                    }
                    viewModel.setImageAttachment(data: data, mimeType: mimeType)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { imageData in
                if let imageData {
                    viewModel.setImageAttachment(data: imageData, mimeType: "image/jpeg")
                }
                showCamera = false
            }
        }
    }
}

private struct SendButton: View {
    let viewModel: ChatViewModel

    private var canSend: Bool {
        let hasText = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImage = viewModel.hasPendingImage
        return (hasText || hasImage) && !viewModel.isStreaming
    }

    var body: some View {
        Button {
            Task { await viewModel.send() }
        } label: {
            ZStack {
                Circle()
                    .fill(canSend ? VitaColors.accent : VitaColors.surfaceCard)
                    .frame(width: 34, height: 34)
                Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(canSend ? VitaColors.surface : VitaColors.textTertiary)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.isStreaming ? "Parar" : "Enviar mensagem")
        .disabled(!canSend)
        .opacity(canSend ? 1.0 : 0.4)
        .animation(.easeInOut(duration: 0.15), value: canSend)
    }
}

// MARK: - History Sheet

private struct HistorySheet: View {
    let viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                VitaScreenBg()

                Group {
                    if viewModel.conversations.isEmpty {
                        emptyHistory
                    } else {
                        conversationList
                    }
                }
            }
            .navigationTitle("Histórico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundColor(VitaColors.accent)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.newConversation()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Nova")
                        }
                        .font(VitaTypography.labelMedium)
                        .foregroundColor(VitaColors.accent)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyHistory: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundColor(VitaColors.textTertiary)
            Text("Nenhuma conversa ainda")
                .font(VitaTypography.bodyMedium)
                .foregroundColor(VitaColors.textSecondary)
        }
    }

    private var conversationList: some View {
        List {
            ForEach(viewModel.conversations) { conv in
                Button {
                    Task { await viewModel.loadConversation(conv) }
                } label: {
                    ConversationRow(conv: conv)
                }
                .buttonStyle(.plain)
                .listRowBackground(VitaColors.surfaceElevated)
                .listRowSeparatorTint(VitaColors.surfaceBorder)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct ConversationRow: View {
    let conv: ConversationEntry

    private var displayTitle: String {
        conv.title?.isEmpty == false ? (conv.title ?? "Conversa") : "Conversa sem título"
    }

    private var formattedDate: String {
        guard let raw = conv.updatedAt,
              let date = ISO8601DateFormatter().date(from: raw) else {
            return ""
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(VitaColors.accent.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 13))
                    .foregroundColor(VitaColors.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(VitaTypography.labelMedium)
                    .foregroundColor(VitaColors.textPrimary)
                    .lineLimit(1)
                if !formattedDate.isEmpty {
                    Text(formattedDate)
                        .font(VitaTypography.labelSmall)
                        .foregroundColor(VitaColors.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(VitaColors.textTertiary)
        }
        .padding(.vertical, 4)
    }
}
