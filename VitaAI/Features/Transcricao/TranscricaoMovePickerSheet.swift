import SwiftUI

/// Sheet pra mover uma gravação pra uma pasta custom do user ou pra uma
/// disciplina do portal. User cria pastas próprias via "+ Nova pasta".
///
/// Dados:
///   - Disciplinas: `appData.gradesResponse` (academic_subjects, auto do portal).
///   - Pastas custom: GET /api/studio/folders (studio_folders table).
///
/// Persistência (via `VitaAPI.updateStudioSource`):
///   - Pasta custom selecionada: `folderId`.
///   - Disciplina selecionada: `disciplineSlug`.
///   - "Sem pasta": `clearFolder=true` + `clearDiscipline=true`.
struct TranscricaoMovePickerSheet: View {
    let currentSlug: String?
    let currentFolderId: String?
    /// Callback recebe `(folderId, disciplineSlug)`. Nil em ambos = "sem pasta".
    let onPick: (_ folderId: String?, _ disciplineSlug: String?) -> Void

    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @Environment(\.dismiss) private var dismiss

    @State private var folders: [VitaAPI.StudioFolder] = []
    @State private var foldersLoading = true
    @State private var showCreateDialog = false
    @State private var newFolderName: String = ""
    @State private var creatingFolder = false
    @State private var errorMessage: String?

    private var subjects: [(slug: String, name: String)] {
        let current = appData.gradesResponse?.current ?? []
        let completed = appData.gradesResponse?.completed ?? []
        return (current + completed)
            .compactMap { s in
                guard !s.subjectName.isEmpty else { return nil }
                let slug = s.subjectName
                    .lowercased()
                    .folding(options: .diacriticInsensitive, locale: .init(identifier: "pt_BR"))
                    .replacingOccurrences(of: " ", with: "-")
                    .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                return (slug: slug, name: s.subjectName)
            }
    }

    var body: some View {
        NavigationStack {
            List {
                // "Sem pasta" — reset both folderId + disciplineSlug.
                Section {
                    Button {
                        onPick(nil, nil)
                        dismiss()
                    } label: {
                        rowLabel(
                            icon: "tray",
                            text: "Sem pasta",
                            selected: currentFolderId == nil && currentSlug == nil,
                            iconColor: Color.white.opacity(0.55)
                        )
                    }
                }

                Section("Minhas pastas") {
                    if foldersLoading {
                        HStack { ProgressView(); Text("Carregando…").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.45)) }
                    } else if folders.isEmpty {
                        Text("Nenhuma pasta criada ainda.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.45))
                    } else {
                        ForEach(folders) { f in
                            Button {
                                onPick(f.id, nil)
                                dismiss()
                            } label: {
                                rowLabel(
                                    icon: f.icon ?? "folder.fill",
                                    text: f.name,
                                    selected: currentFolderId == f.id,
                                    iconColor: VitaColors.accent
                                )
                            }
                        }
                    }

                    Button {
                        newFolderName = ""
                        showCreateDialog = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(VitaColors.accentLight)
                            Text("Nova pasta…")
                                .foregroundStyle(VitaColors.accentLight)
                        }
                    }
                }

                if !subjects.isEmpty {
                    Section("Disciplinas (do portal)") {
                        ForEach(subjects, id: \.slug) { s in
                            Button {
                                onPick(nil, s.slug)
                                dismiss()
                            } label: {
                                rowLabel(
                                    icon: "graduationcap",
                                    text: s.name,
                                    selected: currentSlug == s.slug,
                                    iconColor: Color.white.opacity(0.55)
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.04, green: 0.03, blue: 0.02))
            .navigationTitle("Mover pra pasta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(VitaColors.accentLight)
                }
            }
            // vita-modals-ignore: TextField inline no .alert — VitaAlert não suporta input de texto
            .alert("Nova pasta", isPresented: $showCreateDialog) {
                TextField("Nome da pasta", text: $newFolderName)
                Button("Cancelar", role: .cancel) {}
                Button("Criar") { Task { await createFolder() } }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Organize suas gravações em pastas.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
        .task { await loadFolders() }
    }

    private func rowLabel(icon: String, text: String, selected: Bool, iconColor: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            Text(text)
                .foregroundStyle(Color.white.opacity(0.90))
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(VitaColors.accentLight)
            }
        }
    }

    private func loadFolders() async {
        foldersLoading = true
        do {
            folders = try await container.api.listStudioFolders()
        } catch {
            errorMessage = "Falha ao carregar pastas"
        }
        foldersLoading = false
    }

    private func createFolder() async {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !creatingFolder else { return }
        creatingFolder = true
        defer { creatingFolder = false }
        do {
            let f = try await container.api.createStudioFolder(name: trimmed)
            folders.insert(f, at: 0)
            // Seleciona direto a pasta recém-criada.
            onPick(f.id, nil)
            dismiss()
        } catch {
            errorMessage = "Falha ao criar pasta"
        }
    }
}
