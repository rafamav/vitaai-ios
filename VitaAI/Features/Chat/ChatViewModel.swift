import Foundation
import Observation

// MARK: - ChatViewModel
// Uses ChatMessage from Models/Domain/ChatMessage.swift
// Uses ConversationEntry, ConversationMessagesResponse, ConversationMessage
//   from Models/API/ConversationModels.swift

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var currentConversationId: String?
    var conversations: [ConversationEntry] = []
    var showHistory: Bool = false

    // Image attachment state
    var pendingImageData: Data?
    var pendingImageMimeType: String?
    var isUploadingImage: Bool = false

    var hasPendingImage: Bool { pendingImageData != nil }

    private let chatClient: VitaChatClient
    private let api: VitaAPI
    private var streamingTask: Task<Void, Never>?

    init(chatClient: VitaChatClient, api: VitaAPI) {
        self.chatClient = chatClient
        self.api = api
    }

    // MARK: - Image Attachment

    func setImageAttachment(data: Data, mimeType: String = "image/jpeg") {
        pendingImageData = data
        pendingImageMimeType = mimeType
    }

    func clearImageAttachment() {
        pendingImageData = nil
        pendingImageMimeType = nil
    }

    // MARK: - Send

    func send() async {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard (hasText || hasPendingImage), !isStreaming else { return }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        // Capture and clear pending image
        let attachedImageData = pendingImageData
        let attachedImageMime = pendingImageMimeType
        clearImageAttachment()

        var userMsg = ChatMessage(
            id: UUID().uuidString,
            role: "user",
            content: text.isEmpty ? "[Imagem]" : text,
            timestamp: Date()
        )
        userMsg.imageData = attachedImageData
        userMsg.imageMimeType = attachedImageMime
        messages.append(userMsg)

        var assistantMsg = ChatMessage(
            id: UUID().uuidString,
            role: "assistant",
            content: "",
            timestamp: Date()
        )
        messages.append(assistantMsg)
        let idx = messages.count - 1

        isStreaming = true
        let streamStartTime = Date()

        // Encode image as base64 if present
        let imageBase64: String? = attachedImageData?.base64EncodedString()
        let imageType: String? = attachedImageMime

        streamingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                for try await event in await self.chatClient.streamChat(
                    message: userMsg.content,
                    conversationId: self.currentConversationId,
                    imageBase64: imageBase64,
                    imageType: imageType
                ) {
                    guard !Task.isCancelled else { break }
                    switch event {
                    case .textDelta(let chunk):
                        if self.messages[idx].content.hasPrefix("\u{23f3}") {
                            self.messages[idx].content = chunk
                        } else {
                            self.messages[idx].content += chunk
                        }

                    case .toolProgress(let text):
                        self.messages[idx].content = "\u{23f3} \(text)"

                    case .messageStop(let convId):
                        // Strip [MEMORIA: ...] from end of response
                        self.messages[idx].content = self.stripMemoriaTag(self.messages[idx].content)
                        if let convId {
                            self.currentConversationId = convId
                        }

                    case .error:
                        self.messages[idx].content = "Erro ao gerar resposta."
                        self.messages[idx].isError = true
                    }
                }
            } catch {
                if !Task.isCancelled {
                    NSLog("[ChatViewModel] Stream error: %@", "\(error)")
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .forbidden:
                            self.messages[idx].content = "O Chat IA está disponível apenas para assinantes Pro. Assine para desbloquear!"
                        case .unauthorized:
                            self.messages[idx].content = "Sessão expirada. Faça login novamente."
                        default:
                            self.messages[idx].content = "Erro de conexão. Tente novamente."
                        }
                    } else {
                        self.messages[idx].content = "Erro de conexão. Tente novamente."
                    }
                    self.messages[idx].isError = true
                }
            }

            // Record response duration for assistant message
            if idx < self.messages.count && !self.messages[idx].isError {
                self.messages[idx].responseDuration = Date().timeIntervalSince(streamStartTime)
            }
            self.isStreaming = false
            self.streamingTask = nil
        }

        await streamingTask?.value
    }

    /// Cancel the current streaming response.
    func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
    }

    // MARK: - Retry

    func retryLastMessage() async {
        // Find the last user message
        guard let lastUserIndex = messages.lastIndex(where: { $0.role == "user" }) else { return }
        let userText = messages[lastUserIndex].content
        let retryImageData = messages[lastUserIndex].imageData
        let retryImageMime = messages[lastUserIndex].imageMimeType

        // Remove the error assistant message (should be right after the user message)
        let assistantIndex = lastUserIndex + 1
        if assistantIndex < messages.count,
           messages[assistantIndex].role == "assistant",
           messages[assistantIndex].isError {
            messages.remove(at: assistantIndex)
        }

        // Also remove the user message — send() will re-append both
        messages.remove(at: lastUserIndex)

        // Restore image attachment if present
        if let retryImageData {
            pendingImageData = retryImageData
            pendingImageMimeType = retryImageMime
        }

        // Re-send
        inputText = userText
        await send()
    }

    // MARK: - Send from suggestion chip

    func sendSuggestion(_ text: String) async {
        inputText = text
        await send()
    }

    // MARK: - History

    func loadHistory() async {
        do {
            conversations = try await api.getConversations()
        } catch {
            // Silent fallback — history is non-critical
            print("[ChatViewModel] loadHistory error: \(error)")
        }
    }

    func loadConversation(_ conv: ConversationEntry) async {
        currentConversationId = conv.id
        showHistory = false

        do {
            let resp = try await api.getConversationMessages(conversationId: conv.id)
            let formatter = ISO8601DateFormatter()
            messages = resp.messages.map { m in
                ChatMessage(
                    id: m.id.isEmpty ? UUID().uuidString : m.id,
                    role: m.role,
                    content: m.content,
                    timestamp: formatter.date(from: m.createdAt ?? "") ?? Date()
                )
            }
        } catch {
            print("[ChatViewModel] loadConversation error: \(error)")
        }
    }

    func newConversation() {
        currentConversationId = nil
        messages = []
        showHistory = false
    }

    // MARK: - Helpers

    /// Strips "[MEMORIA: ...]" tags from the end of AI responses (system prompt artifact)
    private func stripMemoriaTag(_ text: String) -> String {
        guard let range = text.range(of: "\\[MEMORIA:.*\\]\\s*$", options: .regularExpression) else {
            return text
        }
        return text[text.startIndex..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
