import SwiftUI
import SwiftData

// MARK: - TrabalhoEditorView
// Full-screen markdown editor for assignments.
// Mirrors AssignmentEditorScreen.kt (Android).
// Features: inline title field, Escrever/Visualizar tabs, markdown formatting toolbar,
// template chooser, AI assistant, auto-save, delete confirmation.

struct TrabalhoEditorView: View {
    let assignmentId: String?
    let templateId: String?
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TrabalhoEditorViewModel?
    @State private var selectedTab: Int = 0   // 0 = Escrever, 1 = Visualizar
    @State private var showDeleteConfirm: Bool = false

    // Editor colors — match Android EditorTopBarBg palette
    private let topBarBg      = Color(red: 0.118, green: 0.118, blue: 0.180)
    private let topBarText    = Color(red: 0.878, green: 0.878, blue: 0.910)
    private let topBarMuted   = Color(red: 0.533, green: 0.533, blue: 0.627)

    var body: some View {
        Group {
            if let vm = viewModel {
                editorContent(vm: vm)
            } else {
                loadingView
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = TrabalhoEditorViewModel(context: modelContext)
                viewModel = vm
                Task { await vm.loadOrCreate(assignmentId: assignmentId, templateId: templateId) }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()
            ProgressView().tint(VitaColors.accent)
        }
    }

    // MARK: - Main Editor

    @ViewBuilder
    private func editorContent(vm: TrabalhoEditorViewModel) -> some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                editorTopBar(vm: vm)

                if vm.isLoading {
                    Spacer()
                    ProgressView().tint(VitaColors.accent)
                    Spacer()
                } else {
                    tabRow(vm: vm)

                    ZStack {
                        if selectedTab == 0 {
                            editModeContent(vm: vm)
                                .transition(.opacity)
                        } else {
                            previewModeContent(vm: vm)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)

                    editorBottomBar(vm: vm)
                }
            }
        }
        // Template chooser
        .sheet(isPresented: Binding(
            get: { vm.showTemplateChooser },
            set: { if !$0 { vm.dismissTemplateChooser() } }
        )) {
            VitaBottomSheet(title: "Escolha um modelo") {
                templateChooserContent(vm: vm)
            }
        }
        // AI Assistant
        .sheet(isPresented: Binding(
            get: { vm.showAiPanel },
            set: { if !$0 { vm.dismissAiPanel() } }
        )) {
            VitaBottomSheet(title: "Assistente IA") {
                aiAssistantContent(vm: vm)
            }
        }
        // Delete confirmation
        .sheet(isPresented: $showDeleteConfirm) {
            VitaBottomSheet(title: "Excluir trabalho?") {
                deleteConfirmContent(vm: vm)
            }
        }
        .onDisappear {
            viewModel?.forceSave()
        }
    }

    // MARK: - Top Bar

    @ViewBuilder
    private func editorTopBar(vm: TrabalhoEditorViewModel) -> some View {
        HStack(spacing: 8) {
            // Back button
            Button(action: {
                vm.forceSave()
                onDismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(topBarText)
                    .frame(width: 44, height: 44)
            }

            // Inline title field
            TextField("Título do trabalho...", text: Binding(
                get: { vm.title },
                set: { vm.title = $0 }
            ))
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(topBarText)
            .tint(VitaColors.accent)

            Spacer()

            // Save status
            saveStatusView(vm: vm)

            // Overflow menu
            Menu {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Excluir", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundStyle(topBarMuted)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 52)
        .background(topBarBg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func saveStatusView(vm: TrabalhoEditorViewModel) -> some View {
        if vm.isSaving || vm.lastSavedAt != nil {
            HStack(spacing: 4) {
                if vm.isSaving {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(VitaColors.accent.opacity(0.5))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VitaColors.accent.opacity(0.6))
                }
                Text(vm.isSaving ? "Salvando..." : "Salvo")
                    .font(.system(size: 11))
                    .foregroundStyle(topBarMuted)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: vm.isSaving)
        }
    }

    // MARK: - Tab Row

    @ViewBuilder
    private func tabRow(vm: TrabalhoEditorViewModel) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(["Escrever", "Visualizar"].enumerated()), id: \.offset) { index, label in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text(label)
                            .font(.system(size: 14, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundStyle(
                                selectedTab == index ? VitaColors.textPrimary : VitaColors.textSecondary
                            )
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)

                        // Indicator
                        Rectangle()
                            .fill(selectedTab == index ? VitaColors.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(VitaColors.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(height: 0.5)
        }
    }

    // MARK: - Edit Mode

    @ViewBuilder
    private func editModeContent(vm: TrabalhoEditorViewModel) -> some View {
        VStack(spacing: 0) {
            // Formatting toolbar
            markdownFormattingToolbar(vm: vm)

            // Text editor
            TextEditor(text: Binding(
                get: { vm.content },
                set: { vm.content = $0 }
            ))
            .scrollContentBackground(.hidden)
            .background(VitaColors.surface)
            .font(.system(size: 15, design: .monospaced))
            .foregroundStyle(VitaColors.textPrimary)
            .tint(VitaColors.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .overlay(alignment: .topLeading) {
                if vm.content.isEmpty {
                    Text("Comece a escrever...\n\nUse markdown para formatar:\n# Título\n## Subtítulo\n**negrito** *itálico*\n- lista")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(VitaColors.textTertiary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Markdown Formatting Toolbar

    @ViewBuilder
    private func markdownFormattingToolbar(vm: TrabalhoEditorViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                FormatButton(icon: "bold", label: "Negrito") {
                    insertFormatting(into: vm, prefix: "**", suffix: "**", placeholder: "negrito")
                }
                FormatButton(icon: "italic", label: "Itálico") {
                    insertFormatting(into: vm, prefix: "*", suffix: "*", placeholder: "itálico")
                }
                formatDivider
                FormatButton(icon: "textformat.size.larger", label: "H1") {
                    insertLinePrefix(into: vm, prefix: "# ")
                }
                FormatButton(icon: "textformat.size", label: "H2") {
                    insertLinePrefix(into: vm, prefix: "## ")
                }
                FormatButton(icon: "textformat.size.smaller", label: "H3") {
                    insertLinePrefix(into: vm, prefix: "### ")
                }
                formatDivider
                FormatButton(icon: "list.bullet", label: "Lista") {
                    insertLinePrefix(into: vm, prefix: "- ")
                }
                FormatButton(icon: "list.number", label: "Lista numerada") {
                    insertLinePrefix(into: vm, prefix: "1. ")
                }
                FormatButton(icon: "quote.opening", label: "Citação") {
                    insertLinePrefix(into: vm, prefix: "> ")
                }
                formatDivider
                FormatButton(icon: "minus", label: "Separador") {
                    vm.content += "\n---\n"
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(topBarBg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 0.5)
        }
    }

    private var formatDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
    }

    private func insertFormatting(into vm: TrabalhoEditorViewModel, prefix: String, suffix: String, placeholder: String) {
        // Appends formatted placeholder at end of content
        // (SwiftUI TextEditor doesn't expose cursor position)
        let formatted = "\(prefix)\(placeholder)\(suffix)"
        if vm.content.isEmpty {
            vm.content = formatted
        } else if vm.content.hasSuffix("\n") {
            vm.content += formatted
        } else {
            vm.content += " \(formatted)"
        }
    }

    private func insertLinePrefix(into vm: TrabalhoEditorViewModel, prefix: String) {
        if vm.content.isEmpty {
            vm.content = prefix
        } else if vm.content.hasSuffix("\n") {
            vm.content += prefix
        } else {
            vm.content += "\n\(prefix)"
        }
    }

    // MARK: - Preview Mode

    @ViewBuilder
    private func previewModeContent(vm: TrabalhoEditorViewModel) -> some View {
        if vm.content.isEmpty && vm.title.isEmpty {
            VStack {
                Spacer()
                Text("Nada para visualizar.\nEscreva algo na aba Escrever.")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textTertiary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if !vm.title.isEmpty {
                        Text(vm.title)
                            .font(VitaTypography.headlineMedium)
                            .foregroundStyle(VitaColors.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    MarkdownPreview(content: vm.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .padding(.bottom, 80)
            }
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private func editorBottomBar(vm: TrabalhoEditorViewModel) -> some View {
        HStack {
            // Word count badge
            HStack(spacing: 4) {
                Text("\(vm.wordCount)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.accent)
                Text(vm.wordCount == 1 ? "palavra" : "palavras")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(VitaColors.glassBg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(VitaColors.glassBorder, lineWidth: 0.5))

            Spacer()

            // Template label
            Text(vm.templateLabel)
                .font(.system(size: 11))
                .foregroundStyle(VitaColors.textTertiary)
                .padding(.trailing, 8)

            // Template selector button
            Button {
                vm.openTemplateChooser()
            } label: {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 16))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .sensoryFeedback(.selection, trigger: vm.showTemplateChooser)

            // AI Assist button
            Button {
                vm.toggleAiPanel()
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 36, height: 36)
                    .background(VitaColors.accent.opacity(0.12))
                    .clipShape(Circle())
            }
            .sensoryFeedback(.selection, trigger: vm.showAiPanel)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(topBarBg)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 0.5)
        }
    }

    // MARK: - Template Chooser

    @ViewBuilder
    private func templateChooserContent(vm: TrabalhoEditorViewModel) -> some View {
        VStack(spacing: 8) {
            ForEach(assignmentTemplates) { template in
                Button {
                    vm.selectTemplate(template)
                } label: {
                    VitaGlassCard {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(VitaColors.accent.opacity(0.10))
                                    .frame(width: 44, height: 44)
                                Image(systemName: template.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(VitaColors.accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(VitaTypography.labelLarge)
                                    .foregroundStyle(VitaColors.textPrimary)
                                Text(template.description)
                                    .font(VitaTypography.bodySmall)
                                    .foregroundStyle(VitaColors.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: vm.templateType)
            }
            Spacer().frame(height: 8)
        }
    }

    // MARK: - AI Assistant

    @ViewBuilder
    private func aiAssistantContent(vm: TrabalhoEditorViewModel) -> some View {
        _AiAssistantPanel(
            suggestion: vm.aiSuggestion,
            isLoading: vm.isAiLoading,
            onSendPrompt: { prompt in vm.requestAiSuggestion(prompt: prompt) },
            onApply: { vm.applyAiSuggestion() },
            onDismiss: { vm.dismissAiPanel() }
        )
    }

    // MARK: - Delete Confirm

    @ViewBuilder
    private func deleteConfirmContent(vm: TrabalhoEditorViewModel) -> some View {
        VStack(spacing: 20) {
            Text("Esta ação não pode ser desfeita. O trabalho será removido permanentemente.")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button {
                    showDeleteConfirm = false
                } label: {
                    Text("Cancelar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(VitaColors.glassBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(VitaColors.glassBorder, lineWidth: 0.5)
                        )
                }

                Button {
                    vm.deleteAssignment()
                    showDeleteConfirm = false
                    onDismiss()
                } label: {
                    Text("Excluir")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VitaColors.dataRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(VitaColors.dataRed.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(VitaColors.dataRed.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .sensoryFeedback(.warning, trigger: showDeleteConfirm)
            }
            Spacer().frame(height: 4)
        }
    }
}

// MARK: - Format Button

private struct FormatButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    private let pillBg = Color(red: 0.165, green: 0.165, blue: 0.235)

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 36, height: 32)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(label)
    }
}

// MARK: - AI Assistant Panel

private struct _AiAssistantPanel: View {
    let suggestion: String
    let isLoading: Bool
    let onSendPrompt: (String) -> Void
    let onApply: () -> Void
    let onDismiss: () -> Void

    @State private var prompt: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // Prompt input row
            HStack(spacing: 8) {
                TextField("Ex: Reescreva a introdução...", text: $prompt)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .tint(VitaColors.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(VitaColors.glassBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.glassBorder, lineWidth: 0.5)
                    )

                Button {
                    guard !prompt.isEmpty else { return }
                    onSendPrompt(prompt)
                    prompt = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(prompt.isEmpty ? VitaColors.textTertiary : VitaColors.accent)
                        .frame(width: 40, height: 40)
                        .background(
                            prompt.isEmpty ? Color.clear : VitaColors.accent.opacity(0.12)
                        )
                        .clipShape(Circle())
                }
                .disabled(prompt.isEmpty || isLoading)
            }

            // State: loading / suggestion / quick prompts
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView().tint(VitaColors.accent)
                    Text("Gerando sugestão...")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !suggestion.isEmpty {
                VitaGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sugestão:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.accent)

                        Text(suggestion)
                            .font(VitaTypography.bodyMedium)
                            .foregroundStyle(VitaColors.textPrimary)

                        HStack {
                            Spacer()
                            Button(action: onApply) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13))
                                    Text("Aplicar")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(VitaColors.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(VitaColors.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(14)
                }
            } else {
                // Quick suggestion chips
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(["Melhore a clareza do texto", "Adicione uma conclusão", "Corrija erros gramaticais"], id: \.self) { chip in
                        Button {
                            onSendPrompt(chip)
                        } label: {
                            Text(chip)
                                .font(.system(size: 13))
                                .foregroundStyle(VitaColors.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .overlay(
                                    Capsule()
                                        .stroke(VitaColors.accent.opacity(0.2), lineWidth: 0.5)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer().frame(height: 4)
        }
    }
}

// MARK: - MarkdownPreview
// Simple markdown-ish renderer for the Visualizar tab.
// Full VitaMarkdown component is implemented by the VitaMarkdown task.

private struct MarkdownPreview: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(renderedLines.enumerated()), id: \.offset) { _, line in
                line
            }
        }
    }

    private var renderedLines: [AnyView] {
        content.components(separatedBy: "\n").map { line -> AnyView in
            if line.hasPrefix("### ") {
                return AnyView(
                    Text(line.dropFirst(4))
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)
                        .padding(.top, 4)
                )
            } else if line.hasPrefix("## ") {
                return AnyView(
                    Text(line.dropFirst(3))
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.accent)
                        .padding(.top, 8)
                )
            } else if line.hasPrefix("# ") {
                return AnyView(
                    Text(line.dropFirst(2))
                        .font(VitaTypography.headlineSmall)
                        .foregroundStyle(VitaColors.accent)
                        .padding(.top, 12)
                )
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                return AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(VitaTypography.bodyMedium)
                            .foregroundStyle(VitaColors.textSecondary)
                        Text(line.dropFirst(2))
                            .font(VitaTypography.bodyMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                    }
                )
            } else if line == "---" {
                return AnyView(
                    Rectangle()
                        .fill(VitaColors.glassBorder)
                        .frame(height: 1)
                        .padding(.vertical, 8)
                )
            } else if line.isEmpty {
                return AnyView(Spacer().frame(height: 4))
            } else {
                // Inline bold/italic (basic)
                return AnyView(
                    Text(renderInline(line))
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                )
            }
        }
    }

    private func renderInline(_ line: String) -> AttributedString {
        AttributedString(line)
    }
}
