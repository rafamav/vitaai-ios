import SwiftUI

// MARK: - VitaChatScreen

struct VitaChatScreen: View {
    @Environment(\.appContainer) private var container
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
                    .background(VitaColors.surface)
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
            ChatTopBar(viewModel: viewModel, onVoiceMode: { showVoiceMode = true })

            Divider()
                .background(VitaColors.surfaceBorder)

            if viewModel.messages.isEmpty {
                EmptyStateView(viewModel: viewModel, isInputFocused: $isInputFocused)
            } else {
                MessagesArea(viewModel: viewModel)
            }

            ChatInputBar(viewModel: viewModel, isInputFocused: $isInputFocused)
        }
        .background(VitaColors.surface)
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

    var body: some View {
        HStack(spacing: 12) {
            // AI avatar
            ZStack {
                Circle()
                    .fill(VitaColors.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "cross.vial.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(VitaColors.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Vita IA")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.white)
                Text(viewModel.isStreaming ? "Digitando..." : "Assistente de estudos")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(
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
                        .foregroundStyle(VitaColors.accent)
                }
            }
            .buttonStyle(.plain)

            // New conversation
            Button {
                viewModel.newConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            // History
            Button {
                Task { await viewModel.loadHistory() }
                viewModel.showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
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
                            isStreaming: viewModel.isStreaming && message.id == viewModel.messages.last?.id
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.content) {
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

    @State private var cursorVisible: Bool = true

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 52)
                userBubble
            } else {
                assistantAvatar
                assistantBubble
                Spacer(minLength: 52)
            }
        }
    }

    private var userBubble: some View {
        Text(message.content)
            .font(VitaTypography.bodyMedium)
            .foregroundStyle(VitaColors.textPrimary)
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
                .foregroundStyle(VitaColors.accent)
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
                    .foregroundStyle(VitaColors.textPrimary)
                + Text(cursorVisible ? " |" : "  ")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.accent))
            } else {
                // Finished: render full Markdown
                VitaMarkdown(content: message.content)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
        .onAppear {
            if isStreaming {
                startCursorBlink()
            }
        }
        .onChange(of: isStreaming) { _, streaming in
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
                        .foregroundStyle(VitaColors.accent)
                }

                VStack(spacing: 6) {
                    Text("Vita IA")
                        .font(VitaTypography.headlineSmall)
                        .foregroundStyle(VitaColors.white)
                    Text("Seu assistente de estudos de medicina")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
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
                    .foregroundStyle(VitaColors.accent)
                Text(text)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textSecondary)
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

// MARK: - Input Bar

private struct ChatInputBar: View {
    let viewModel: ChatViewModel
    var isInputFocused: FocusState<Bool>.Binding

    @State private var isListening: Bool = false
    @State private var showToolsSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(VitaColors.surfaceBorder)

            HStack(spacing: 10) {
                // "+" tools button
                Button {
                    showToolsSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(VitaColors.glassBg)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Circle().stroke(VitaColors.glassBorder, lineWidth: 1)
                            )
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                TextField(
                    isListening ? "Ouvindo..." : "Pergunte para a Vita...",
                    text: Binding(
                        get: { viewModel.inputText },
                        set: { viewModel.inputText = $0 }
                    ),
                    axis: .vertical
                )
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textPrimary)
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
        .background(VitaColors.surface)
        .sheet(isPresented: $showToolsSheet) {
            ChatToolsSheet(isPresented: $showToolsSheet, viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VitaColors.surfaceElevated)
        }
    }
}

// MARK: - Chat Tools Sheet

private struct ChatToolItem: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let color: Color
    let prompt: String?
}

private let chatToolsVitaStudio: [ChatToolItem] = [
    ChatToolItem(label: "Flashcards IA", icon: "rectangle.on.rectangle.angled",  color: VitaColors.accent,     prompt: "Crie flashcards sobre o conteúdo que estudei."),
    ChatToolItem(label: "Resumo IA",     icon: "doc.text.fill",                   color: VitaColors.dataBlue,   prompt: "Faça um resumo do conteúdo."),
    ChatToolItem(label: "Quiz IA",       icon: "questionmark.circle.fill",         color: VitaColors.dataIndigo, prompt: "Monte um quiz para testar meu conhecimento."),
]

private let chatToolsFerramentas: [ChatToolItem] = [
    ChatToolItem(label: "Camera",        icon: "camera.fill",         color: VitaColors.textSecondary, prompt: nil),
    ChatToolItem(label: "Galeria",       icon: "photo.fill",          color: VitaColors.textSecondary, prompt: nil),
    ChatToolItem(label: "Arquivos",      icon: "doc.fill",            color: VitaColors.textSecondary, prompt: nil),
    ChatToolItem(label: "Banco Quest.",  icon: "list.bullet.clipboard", color: VitaColors.dataGreen,   prompt: "Quero resolver questões do banco."),
    ChatToolItem(label: "Simulado",      icon: "checkmark.square.fill", color: VitaColors.dataAmber,   prompt: "Quero fazer um simulado."),
    ChatToolItem(label: "Flashcards",    icon: "rectangle.on.rectangle", color: VitaColors.accent,    prompt: "Quero revisar flashcards."),
]

private struct ChatToolsSheet: View {
    @Binding var isPresented: Bool
    let viewModel: ChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Drag handle area + title
            HStack {
                Text("Ferramentas")
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            // Vita Studio section
            ToolSection(title: "Vita Studio", items: chatToolsVitaStudio) { item in
                applyTool(item)
            }

            // Ferramentas section
            ToolSection(title: "Ferramentas", items: chatToolsFerramentas) { item in
                applyTool(item)
            }

            Spacer()
        }
        .padding(.top, 12)
    }

    private func applyTool(_ item: ChatToolItem) {
        if let prompt = item.prompt {
            viewModel.inputText = prompt
        }
        isPresented = false
    }
}

private struct ToolSection: View {
    let title: String
    let items: [ChatToolItem]
    let onTap: (ChatToolItem) -> Void

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(VitaColors.textTertiary)
                .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    Button {
                        onTap(item)
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(item.color.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                Image(systemName: item.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(item.color.opacity(0.80))
                            }
                            Text(item.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(VitaColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(VitaColors.glassBg)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(VitaColors.glassBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct SendButton: View {
    let viewModel: ChatViewModel

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isStreaming
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
                    .foregroundStyle(canSend ? VitaColors.surface : VitaColors.textTertiary)
            }
        }
        .buttonStyle(.plain)
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
                VitaColors.surface.ignoresSafeArea()

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
                        .foregroundStyle(VitaColors.accent)
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
                        .foregroundStyle(VitaColors.accent)
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
                .foregroundStyle(VitaColors.textTertiary)
            Text("Nenhuma conversa ainda")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
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
                    .foregroundStyle(VitaColors.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
                if !formattedDate.isEmpty {
                    Text(formattedDate)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(.vertical, 4)
    }
}
