import SwiftUI
import PhotosUI

// MARK: - VitaPlusSheet
// Bottom sheet aberta pelo botão "+" no input bar do chat.
// Exibe quick-actions do backend: suggestions, studyTools, aboutYou, connectors, attachments.

struct VitaPlusSheet: View {
    let viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container

    @State private var quickActions: QuickActionsResponse?
    @State private var isLoading = true
    @State private var expandedSections: Set<String> = ["suggestions", "studyTools", "aboutYou", "connectors", "attachments"]

    // Subject selector state
    @State private var showSubjectSelector = false
    @State private var pendingAction: QuickAction?

    // Attachment pickers
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                // Glass background
                VitaColors.surface.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(VitaColors.accent)
                } else if let qa = quickActions {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Search placeholder (non-functional Phase 1)
                            searchBar

                            // Suggestions
                            if !qa.suggestions.isEmpty {
                                collapsibleSection(title: "Sugestões", key: "suggestions") {
                                    chipGrid(actions: qa.suggestions)
                                }
                            }

                            // Study Tools
                            if !qa.studyTools.isEmpty {
                                collapsibleSection(title: "Ferramentas de Estudo", key: "studyTools") {
                                    chipGrid(actions: qa.studyTools)
                                }
                            }

                            // About You
                            if !qa.aboutYou.isEmpty {
                                collapsibleSection(title: "Sobre Você", key: "aboutYou") {
                                    chipGrid(actions: qa.aboutYou)
                                }
                            }

                            // Connectors
                            ForEach(qa.connectors, id: \.provider) { connector in
                                if connector.connected && !connector.actions.isEmpty {
                                    collapsibleSection(
                                        title: connector.displayName,
                                        key: "connector_\(connector.provider)"
                                    ) {
                                        chipGrid(actions: connector.actions)
                                    }
                                }
                            }

                            // Attachments
                            if !qa.attachments.isEmpty {
                                collapsibleSection(title: "Anexos", key: "attachments") {
                                    attachmentGrid(attachments: qa.attachments)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                } else {
                    // Error / empty state
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundColor(VitaColors.textTertiary)
                        Text("Não foi possível carregar ações")
                            .font(.system(size: 13))
                            .foregroundColor(VitaColors.textSecondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Vita+")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(VitaColors.textPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(VitaColors.textSecondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .task { await loadQuickActions() }
        .sheet(isPresented: $showSubjectSelector) {
            SubjectSelectorSheet(
                subjects: container.dataManager.enrolledDisciplines,
                onSelect: { subject in
                    guard let action = pendingAction else { return }
                    let enrichedPrompt = action.prompt.replacingOccurrences(of: "{subject}", with: subject.displayName ?? subject.canonicalName ?? subject.name)
                    Task {
                        await viewModel.sendQuickAction(prompt: enrichedPrompt, toolHint: action.toolHint)
                    }
                    pendingAction = nil
                    dismiss()
                }
            )
            .presentationDetents([.medium])
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.setImageAttachment(data: data, mimeType: newItem.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg")
                }
                selectedPhotoItem = nil
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureSheetView { imageData in
                if let imageData {
                    viewModel.setImageAttachment(data: imageData, mimeType: "image/jpeg")
                }
                showCamera = false
                dismiss()
            }
        }
    }

    // MARK: - Search Bar (placeholder)

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(VitaColors.textTertiary)
            Text("Buscar ações...")
                .font(.system(size: 13))
                .foregroundColor(VitaColors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(VitaColors.accent.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Collapsible Section

    @ViewBuilder
    private func collapsibleSection<Content: View>(
        title: String,
        key: String,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSections.contains(key) {
                        expandedSections.remove(key)
                    } else {
                        expandedSections.insert(key)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 12))
                            .foregroundColor(VitaColors.accent)
                    }
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(VitaColors.sectionLabel)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: expandedSections.contains(key) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(VitaColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if expandedSections.contains(key) {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Chip Grid

    @ViewBuilder
    private func chipGrid(actions: [QuickAction]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(actions) { action in
                chipButton(action: action)
            }
        }
    }

    private func chipButton(action: QuickAction) -> some View {
        Button {
            handleActionTap(action)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.system(size: 11))
                    .foregroundColor(VitaColors.accent)

                Text(action.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(VitaColors.textPrimary)
                    .lineLimit(1)

                if let badge = action.badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(VitaColors.surface)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(VitaColors.accent)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(VitaColors.accent.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Attachment Grid

    @ViewBuilder
    private func attachmentGrid(attachments: [AttachmentAction]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(attachments) { attachment in
                attachmentButton(attachment: attachment)
            }
        }
    }

    private func attachmentButton(attachment: AttachmentAction) -> some View {
        Button {
            handleAttachmentTap(attachment)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: attachment.icon)
                    .font(.system(size: 11))
                    .foregroundColor(VitaColors.accent)
                Text(attachment.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(VitaColors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(VitaColors.accent.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func handleActionTap(_ action: QuickAction) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if let selector = action.needsSelector, (selector == .subject || selector == .topic) {
            pendingAction = action
            showSubjectSelector = true
        } else {
            Task {
                await viewModel.sendQuickAction(prompt: action.prompt, toolHint: action.toolHint)
            }
            dismiss()
        }
    }

    private func handleAttachmentTap(_ attachment: AttachmentAction) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        switch attachment.kind {
        case .photo:
            showPhotoPicker = true
        case .camera:
            showCamera = true
        case .file:
            // Phase 1: reuse photo picker for file selection
            showPhotoPicker = true
        case .audio:
            // Audio recording — dismiss and let the mic button handle it
            dismiss()
        case .document, .note:
            // Phase 2 — dismiss for now, picker implemented in next sprint
            dismiss()
        }
    }

    // MARK: - Network

    private func loadQuickActions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            quickActions = try await viewModel.fetchQuickActions()
        } catch {
            NSLog("[VitaPlusSheet] Failed to load quick actions: %@", "\(error)")
            quickActions = nil
        }
    }
}

// MARK: - Subject Selector Sheet

private struct SubjectSelectorSheet: View {
    let subjects: [AcademicSubject]
    let onSelect: (AcademicSubject) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(subjects) { subject in
                Button {
                    onSelect(subject)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        if let icon = subject.icon {
                            Image(icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(VitaColors.accent.opacity(0.15))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "book.closed")
                                        .font(.system(size: 12))
                                        .foregroundColor(VitaColors.accent)
                                )
                        }
                        Text(subject.displayName ?? subject.canonicalName ?? subject.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(VitaColors.textPrimary)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(VitaColors.surface)
            .navigationTitle("Escolha a disciplina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(VitaColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Camera Capture (reuse pattern from VitaChatScreen)

private struct CameraCaptureSheetView: UIViewControllerRepresentable {
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
