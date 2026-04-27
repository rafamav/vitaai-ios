import SwiftUI
import PhotosUI

// MARK: - VitaInputPopout
// D4 anchored popout que cresce do botão "+" do input do VitaChat.
// Substitui `.sheet(VitaPlusSheet)` (proibido pelo shell.md §10) por overlay
// ZStack-root com matchedGeometryEffect, tokens VitaModalTokens, glassCard
// nas tiles (mesmo modifier das bubbles do chat — VitaChatScreen.swift:440).
//
// Template: VitaMenuPopout.swift adaptado pra anchor `.bottomLeading`.
// Tokens: NÃO inventa novo — TUDO em VitaModalTokens (warm gold tint 6%,
// border gold 22%, shadow black 50% radius 24 y 8, spring 0.35/0.78,
// haptic .soft).
//
// Fase 1 (Rafael 2026-04-26): SF Symbols + 6 tiles + 4 attachment chips.
// Fase 2: imagens AI hero pré-geradas, quick-prompts dinâmicos, search bar.

struct VitaInputPopout: View {
    let viewModel: ChatViewModel
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    @Environment(\.appContainer) private var container
    @State private var isVisible = false

    // Subject selector (mantém compat com fluxo de placeholders {subject}/{topic})
    @State private var showSubjectSelector = false
    @State private var pendingTile: Tile?

    // Attachment pickers (Foto/Câmera/Arquivo/Áudio)
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    // MARK: - Tile model

    fileprivate struct Tile: Identifiable {
        let id: String
        let icon: String          // SF Symbol (Fase 1) — Fase 2: AssetName de hero AI
        let label: String
        let prompt: String        // {subject}/{topic} resolvido via SubjectSelector
        let toolHint: String?
        let needsSubject: Bool
    }

    private let tiles: [Tile] = [
        Tile(id: "mindmap",  icon: "brain.head.profile",       label: "Mapa mental",
             prompt: "Cria um mapa mental sobre {subject}",   toolHint: nil, needsSubject: true),
        Tile(id: "case",     icon: "stethoscope",              label: "Caso clínico",
             prompt: "Gera um caso clínico de {subject}",     toolHint: nil, needsSubject: true),
        Tile(id: "simulado", icon: "doc.text.magnifyingglass", label: "Simulado",
             prompt: "Cria simulado de {subject}",            toolHint: "create_simulado", needsSubject: true),
        Tile(id: "flash",    icon: "rectangle.stack",          label: "Flashcards",
             prompt: "Cria flashcards sobre {topic}",         toolHint: "create_flashcard", needsSubject: true),
        Tile(id: "trabalho", icon: "doc.richtext",             label: "Trabalho",
             prompt: "Me ajuda com trabalho sobre {topic}",   toolHint: nil, needsSubject: true),
        Tile(id: "spotify",  icon: "music.note",               label: "Spotify",
             prompt: "O que está tocando?",                   toolHint: "spotify_current", needsSubject: false),
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop blur idêntico ao do hamburguer (AppRouter:333-346) —
            // ofusca chat atrás dando profundidade. Tap dismissa.
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { dismissAnimated() }

            popoutContent
                .padding(.leading, 14)
                .padding(.bottom, 92) // acima do input bar (~74pt input + 18 folga)
                // Anchor matched ao botão "+" — a entrada cresce do botão (Rafael spec)
                .matchedGeometryEffect(id: "plus_popout_origin", in: namespace)
                .scaleEffect(isVisible ? 1.0 : 0.4, anchor: .bottomLeading)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(VitaModalTokens.openSpring) {
                isVisible = true
            }
        }
        // Subject selector — VitaSheet wrapper (não viola §10)
        .sheet(isPresented: $showSubjectSelector) {
            VitaSheet(title: "Escolha a disciplina", detents: [.medium]) {
                SubjectSelectorList(
                    subjects: container.dataManager.enrolledDisciplines,
                    onSelect: { subject in
                        guard let tile = pendingTile else { return }
                        let label = subject.displayName ?? subject.canonicalName ?? subject.name
                        let enriched = tile.prompt
                            .replacingOccurrences(of: "{subject}", with: label)
                            .replacingOccurrences(of: "{topic}", with: label)
                        Task {
                            await viewModel.sendQuickAction(prompt: enriched, toolHint: tile.toolHint)
                        }
                        pendingTile = nil
                        showSubjectSelector = false
                        dismissAnimated()
                    }
                )
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.setImageAttachment(
                        data: data,
                        mimeType: newItem.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                    )
                }
                selectedPhotoItem = nil
                dismissAnimated()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            PopoutCameraCapture { imageData in
                if let imageData {
                    viewModel.setImageAttachment(data: imageData, mimeType: "image/jpeg")
                }
                showCamera = false
                dismissAnimated()
            }
        }
    }

    // MARK: - Popout container

    private var popoutContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle no topo (eco do VitaSheet — pista visual de modalidade)
            dragHandle

            // Grid 2 colunas, 6 tiles 16:9
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(tiles) { tile in
                    tileButton(tile)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // Divider sutil entre tools e attachments
            Rectangle()
                .fill(VitaModalTokens.borderColor.opacity(0.6))
                .frame(height: 1)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

            // Attachment chips — pills horizontais. Áudio removido (Rafael
            // 2026-04-27: "ja temos no vitachat" — mic button no input bar).
            HStack(spacing: 8) {
                attachChip(icon: "photo",  label: "Foto")    { showPhotoPicker = true }
                attachChip(icon: "camera", label: "Câmera")  { showCamera = true }
                attachChip(icon: "doc",    label: "Arquivo") { showPhotoPicker = true }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(width: 300)
        .background {
            ZStack(alignment: .top) {
                // VitaModalTokens glass — ultraThinMaterial + warm gold tint 6% + border gold 22%
                VitaModalTokens.glassBackground(cornerRadius: 28)

                // Top-edge glow (idêntico VitaSheet:106-118) — gold 32% → 8% → clear
                LinearGradient(
                    colors: [
                        VitaColors.accent.opacity(0.32),
                        VitaColors.accent.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 90)
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .shadow(
            color: VitaModalTokens.shadowColor,
            radius: VitaModalTokens.shadowRadius,
            y: VitaModalTokens.shadowY
        )
    }

    // MARK: - Drag handle

    private var dragHandle: some View {
        Capsule()
            .fill(VitaColors.textTertiary.opacity(0.45))
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Tile button — .glassCard(cornerRadius: 18) MESMO das chat bubbles

    private func tileButton(_ tile: Tile) -> some View {
        Button {
            handleTileTap(tile)
        } label: {
            // Ícone topo-leading + label bottom-leading. Rafael 2026-04-27:
            // "pros de cima precisa de um texto bonito, os de baixo não".
            // Fase 2: SF Symbol vira hero image AI; label permanece overlay.
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: tile.icon)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(VitaColors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
                    .padding(.leading, 14)

                Spacer(minLength: 0)

                Text(tile.label)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 18)
        .accessibilityIdentifier("popout_tile_\(tile.id)")
        .accessibilityLabel(tile.label)
    }

    // MARK: - Attachment chip — pill com glassCard cornerRadius 12

    private func attachChip(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            // Só ícone — Rafael 2026-04-27 "nao precisa de texto em nenhum
            // daqueles blocos". Label fica em accessibility pra VoiceOver.
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(VitaColors.accent.opacity(0.95))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 12)
        .accessibilityLabel(label)
        .accessibilityIdentifier("popout_attach_\(label.lowercased())")
    }

    // MARK: - Actions

    private func handleTileTap(_ tile: Tile) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if tile.needsSubject {
            pendingTile = tile
            showSubjectSelector = true
        } else {
            Task { await viewModel.sendQuickAction(prompt: tile.prompt, toolHint: tile.toolHint) }
            dismissAnimated()
        }
    }

    private func dismissAnimated() {
        withAnimation(VitaModalTokens.openSpring) {
            isVisible = false
        }
        // Aguarda fim da animação de saída antes de remover do ZStack
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            onDismiss()
        }
    }
}

// MARK: - SubjectSelectorList (lista leve embebida em VitaSheet)

private struct SubjectSelectorList: View {
    let subjects: [AcademicSubject]
    let onSelect: (AcademicSubject) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(subjects) { subject in
                    Button {
                        onSelect(subject)
                    } label: {
                        HStack(spacing: 12) {
                            if let icon = subject.icon {
                                Image(icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(VitaColors.accent.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "book.closed")
                                            .font(.system(size: 14))
                                            .foregroundStyle(VitaColors.accent)
                                    )
                            }
                            Text(subject.displayName ?? subject.canonicalName ?? subject.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(VitaColors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassCard(cornerRadius: 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Camera wrapper (UIImagePickerController bridge)

private struct PopoutCameraCapture: UIViewControllerRepresentable {
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
            } else {
                onCapture(nil)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCapture(nil) }
    }
}
