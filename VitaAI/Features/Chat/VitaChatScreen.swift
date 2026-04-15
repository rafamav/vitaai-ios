import SwiftUI
import PhotosUI

// MARK: - VitaChatScreen — Overlay between top bar and tab bar

struct VitaChatScreen: View {
    @Environment(\.appContainer) private var container
    var onClose: () -> Void
    @State private var viewModel: ChatViewModel?
    @State private var showVoiceMode: Bool = false
    @FocusState private var isInputFocused: Bool
    @Namespace private var mascotNS

    var body: some View {
        ZStack {
            // Glassmorphism — real blur of content behind
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            // Soft gold ambient — top fades in, bottom transparent
            LinearGradient(
                colors: [
                    VitaColors.accent.opacity(0.07),
                    VitaColors.accent.opacity(0.02),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if let viewModel {
                chatContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .top) {
            // Top gold glow line
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(height: 1)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ChatViewModel(
                    chatClient: container.chatClient,
                    api: container.api
                )
            }
            viewModel?.newConversation()
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
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                // Header — history toggle + close button
                ChatHeader(
                    onHistory: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.showHistory.toggle()
                            if viewModel.showHistory {
                                Task { await viewModel.loadHistory() }
                            }
                        }
                    },
                    onClose: onClose
                )

                // Messages or empty state
                if viewModel.messages.isEmpty {
                    EmptyState(viewModel: viewModel, isInputFocused: $isInputFocused, mascotNS: mascotNS)
                } else {
                    MessagesList(viewModel: viewModel, mascotNS: mascotNS)
                }

                // Input bar
                ChatInput(viewModel: viewModel, isInputFocused: $isInputFocused)
            }
            .ignoresSafeArea(.keyboard)
            .animation(.spring(response: 0.65, dampingFraction: 0.78), value: viewModel.messages.isEmpty)

            // History sidebar overlay
            if viewModel.showHistory {
                HistoryPanel(viewModel: viewModel)
                    .transition(.move(edge: .leading))
            }
        }
    }
}

// MARK: - Header

private struct ChatHeader: View {
    var onHistory: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Hamburger — opens conversation history
            Button(action: onHistory) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(VitaColors.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Histórico")

            Spacer()

            // Close — exits chat
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(VitaColors.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Empty State

private struct EmptyState: View {
    let viewModel: ChatViewModel
    var isInputFocused: FocusState<Bool>.Binding
    let mascotNS: Namespace.ID

    private let suggestions = [
        "O que estudar hoje?",
        "Análise meu progresso",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Vita mascot — animated. Shares id with the first assistant
                // avatar so it "flies" to the bubble when conversation starts.
                VitaMascot(state: .awake, size: 100, showStaff: false)
                    .matchedGeometryEffect(id: "vitaMascot", in: mascotNS, properties: .position)
                    .frame(height: 120)

                Text("Como posso te ajudar?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(VitaColors.textPrimary)

                // Quick action chips
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { text in
                        Button {
                            viewModel.inputText = text
                            isInputFocused.wrappedValue = true
                            Task { await viewModel.send() }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text(text)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(VitaColors.accent.opacity(0.75))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .liquidGlassChip(cornerRadius: 20)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Messages List

private struct MessagesList: View {
    let viewModel: ChatViewModel
    let mascotNS: Namespace.ID

    private var firstAssistantId: String? {
        viewModel.messages.first(where: { $0.role == "assistant" })?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        MessageRow(
                            message: message,
                            isStreaming: viewModel.isStreaming && message.id == viewModel.messages.last?.id,
                            isFirstAssistant: message.id == firstAssistantId,
                            mascotNS: mascotNS,
                            onRetry: message.isError ? {
                                Task { await viewModel.retryLastMessage() }
                            } : nil,
                            onFeedback: { value in
                                Task { await viewModel.sendFeedback(messageId: message.id, value: value) }
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
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

// MARK: - Message Row

private struct MessageRow: View {
    let message: ChatMessage
    let isStreaming: Bool
    let isFirstAssistant: Bool
    let mascotNS: Namespace.ID
    var onRetry: (() -> Void)?
    var onFeedback: ((Int) -> Void)?
    @State private var cursorVisible: Bool = true

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 52)
                userBubble
            } else {
                assistantAvatar
                VStack(alignment: .leading, spacing: 6) {
                    assistantBubble
                    if message.isError, let onRetry {
                        Button(action: onRetry) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Tentar novamente")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(VitaColors.dataRed)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(VitaColors.dataRed.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    // Action buttons (copy, share, time) — only when done streaming
                    if !isStreaming && !message.content.isEmpty && !message.isError {
                        MessageActions(message: message, onFeedback: onFeedback)
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
                    .font(.system(size: 13))
                    .foregroundColor(VitaColors.textPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlassUserBubble(cornerRadius: 20)
    }

    @ViewBuilder
    private var assistantAvatar: some View {
        if isFirstAssistant {
            // Mascot flies from the empty-state center via matchedGeometry
            VitaMascot(state: isStreaming ? .thinking : .awake, size: 32, showStaff: false)
                .matchedGeometryEffect(id: "vitaMascot", in: mascotNS, properties: .position)
                .frame(width: 40, height: 40)
                .alignmentGuide(.bottom) { d in d[.bottom] }
        } else {
            Image("vita-btn-active")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                .alignmentGuide(.bottom) { d in d[.bottom] }
        }
    }

    private var assistantBubble: some View {
        Group {
            if message.content.isEmpty && isStreaming {
                HStack(spacing: 6) {
                    Text("Pensando")
                        .font(.system(size: 13))
                        .foregroundColor(VitaColors.textSecondary)
                    TypingDots()
                }
                .padding(.vertical, 4)
            } else if isStreaming {
                (Text(message.content)
                    .font(.system(size: 13))
                    .foregroundColor(VitaColors.textPrimary)
                + Text(cursorVisible ? " |" : "  ")
                    .font(.system(size: 13))
                    .foregroundColor(VitaColors.accent))
            } else {
                VitaMarkdown(content: message.content)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassAssistantBubble(cornerRadius: 20)
        .onAppear {
            if isStreaming { startCursorBlink() }
        }
        .onChange(of: isStreaming) { streaming in
            if !streaming { cursorVisible = false }
        }
    }

    private func startCursorBlink() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            cursorVisible = false
        }
    }
}

// MARK: - History Panel

private struct HistoryPanel: View {
    let viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Conversas")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VitaColors.textPrimary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.showHistory = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(VitaColors.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(VitaColors.textWarm.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .overlay(VitaColors.glassBorder)

            if viewModel.conversations.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28))
                        .foregroundColor(VitaColors.textTertiary)
                    Text("Nenhuma conversa ainda")
                        .font(.system(size: 12))
                        .foregroundColor(VitaColors.textTertiary)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(groupedConversations, id: \.key) { group in
                            // Date section header
                            Text(group.key)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(VitaColors.textTertiary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 4)

                            ForEach(group.items) { conv in
                                HistoryRow(
                                    conversation: conv,
                                    isActive: conv.id == viewModel.currentConversationId
                                ) {
                                    Task { await viewModel.loadConversation(conv) }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(width: 280)
        .frame(maxHeight: .infinity)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(width: 1)
        }
    }

    private struct DateGroup: Identifiable {
        let key: String
        let items: [ConversationEntry]
        var id: String { key }
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = frac.date(from: string) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    private var groupedConversations: [DateGroup] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [String: [ConversationEntry]] = [:]
        var order: [String] = []

        for conv in viewModel.conversations {
            let label: String
            if let date = parseDate(conv.updatedAt) {
                if calendar.isDateInToday(date) {
                    label = "Hoje"
                } else if calendar.isDateInYesterday(date) {
                    label = "Ontem"
                } else if calendar.dateComponents([.day], from: date, to: now).day ?? 8 < 7 {
                    label = "Esta semana"
                } else {
                    let df = DateFormatter()
                    df.dateFormat = "MMMM yyyy"
                    df.locale = Locale(identifier: "pt-BR")
                    label = df.string(from: date).capitalized
                }
            } else {
                label = "Sem data"
            }

            if groups[label] == nil { order.append(label) }
            groups[label, default: []].append(conv)
        }

        return order.map { DateGroup(key: $0, items: groups[$0] ?? []) }
    }
}

private struct HistoryRow: View {
    let conversation: ConversationEntry
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.title ?? "Nova conversa")
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? VitaColors.accent : VitaColors.textPrimary)
                    .lineLimit(1)

                if let preview = conversation.messagePreview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 11))
                        .foregroundColor(VitaColors.textTertiary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isActive ? VitaColors.accent.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Actions (copy, share, time)

private struct MessageActions: View {
    let message: ChatMessage
    var onFeedback: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            // Response time
            if let duration = message.responseDuration {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(formatDuration(duration))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(VitaColors.textTertiary)
            }

            Spacer()

            // Thumbs up
            Button {
                let newValue = message.feedback == 1 ? 0 : 1
                if newValue != 0 { onFeedback?(newValue) }
            } label: {
                Image(systemName: message.feedback == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 11))
                    .foregroundColor(message.feedback == 1 ? VitaColors.accent : VitaColors.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Gostei")

            // Thumbs down
            Button {
                let newValue = message.feedback == -1 ? 0 : -1
                if newValue != 0 { onFeedback?(newValue) }
            } label: {
                Image(systemName: message.feedback == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 11))
                    .foregroundColor(message.feedback == -1 ? VitaColors.accent : VitaColors.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Nao gostei")

            // Copy
            Button {
                UIPasteboard.general.string = message.content
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundColor(VitaColors.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copiar")

            // Share
            Button {
                let av = UIActivityViewController(
                    activityItems: [message.content],
                    applicationActivities: nil
                )
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    root.present(av, animated: true)
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                    .foregroundColor(VitaColors.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Compartilhar")
        }
        .padding(.horizontal, 4)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1 { return "<1s" }
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m \(s % 60)s"
    }
}

// MARK: - Typing Dots

private struct TypingDots: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(VitaColors.accent.opacity(phase == i ? 0.7 : 0.2))
                    .frame(width: 5, height: 5)
                    .scaleEffect(phase == i ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation { phase = (phase + 1) % 3 }
            }
        }
    }
}

// MARK: - Input Bar

private struct ChatInput: View {
    let viewModel: ChatViewModel
    var isInputFocused: FocusState<Bool>.Binding

    @State private var isListening: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera: Bool = false
    @State private var isLoadingImage: Bool = false

    private var canSend: Bool {
        let hasText = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || viewModel.hasPendingImage) && !viewModel.isStreaming
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pending image
            if viewModel.hasPendingImage {
                PendingImagePreview(
                    imageData: viewModel.pendingImageData,
                    onRemove: { viewModel.clearImageAttachment() }
                )
            }

            HStack(spacing: 8) {
                // Attach button
                PhotosPicker(
                    selection: Binding(
                        get: { nil },
                        set: { item in if let item { selectedPhotoItem = item } }
                    ),
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(VitaColors.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(VitaColors.textWarm.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Text input
                TextField(
                    "Pergunte ao Vita...",
                    text: Binding(
                        get: { viewModel.inputText },
                        set: { viewModel.inputText = $0 }
                    ),
                    axis: .vertical
                )
                .font(.system(size: 13))
                .foregroundColor(VitaColors.textPrimary)
                .tint(VitaColors.accent)
                .lineLimit(1...4)
                .focused(isInputFocused)
                .submitLabel(.send)
                .onSubmit {
                    isInputFocused.wrappedValue = false
                    Task { await viewModel.send() }
                }

                // Mic button
                VitaMicButton(isListening: $isListening) { transcribed in
                    if viewModel.inputText.isEmpty {
                        viewModel.inputText = transcribed
                    } else {
                        viewModel.inputText += " " + transcribed
                    }
                }

                // Send button
                Button {
                    isInputFocused.wrappedValue = false
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(canSend ? VitaColors.surface : VitaColors.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(canSend ? VitaColors.accent.opacity(0.85) : VitaColors.textWarm.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .animation(.easeInOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlassInput(focused: isInputFocused.wrappedValue, cornerRadius: 22)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            .padding(.top, 8)
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            isLoadingImage = true
            Task {
                defer { isLoadingImage = false; selectedPhotoItem = nil }
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.setImageAttachment(data: data, mimeType: newItem.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg")
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { imageData in
                if let imageData { viewModel.setImageAttachment(data: imageData, mimeType: "image/jpeg") }
                showCamera = false
            }
        }
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
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(VitaColors.glassBorder, lineWidth: 1)
                        )
                    Button(action: onRemove) {
                        ZStack {
                            Circle().fill(Color.black.opacity(0.7)).frame(width: 20, height: 20)
                            Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundColor(VitaColors.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -5)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
    }
}

// MARK: - Camera Capture

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

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data?) -> Void
        init(onCapture: @escaping (Data?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image.jpegData(compressionQuality: 0.8))
            } else { onCapture(nil) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCapture(nil) }
    }
}
