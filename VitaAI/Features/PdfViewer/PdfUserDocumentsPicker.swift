import SwiftUI

/// Goodnotes-style document picker scoped to the user's Vita library.
/// Replaces the iOS Files picker (which was wrong UX — it pointed at iCloud
/// Drive / device-local files, not at the user's actual Vita PDFs synced
/// from Canvas / Mannesoft / uploads).
///
/// Layout: search bar on top, list grouped by subject (matéria), tap a row
/// to open it as a new PDF tab. Trailing toolbar button "Files" opens the
/// system picker as a fallback for ad-hoc imports (rare case).
struct PdfUserDocumentsPicker: View {
    let onSelect: (URL, String) -> Void
    let onCancel: () -> Void

    @Environment(\.appContainer) private var container
    @State private var docs: [VitaDocument] = []
    @State private var isLoading: Bool = true
    @State private var loadError: String? = nil
    @State private var searchText: String = ""
    @State private var showFilesPicker: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                VitaColors.surface.ignoresSafeArea()

                if isLoading {
                    OrbMascot(palette: .vita, state: .thinking, size: 96)
                } else if let err = loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(VitaColors.dataRed)
                        Text(err)
                            .font(VitaTypography.bodyMedium)
                            .foregroundStyle(VitaColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Tentar novamente") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                            .tint(VitaColors.accent)
                    }
                } else if filteredGrouped.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(VitaColors.textTertiary)
                        Text(searchText.isEmpty ? "Nenhum documento" : "Nenhum resultado para \"\(searchText)\"")
                            .font(VitaTypography.bodyMedium)
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                } else {
                    list
                }
            }
            .searchable(text: $searchText, prompt: "Buscar documento")
            .navigationTitle("Abrir documento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar", action: onCancel)
                        .foregroundStyle(VitaColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilesPicker = true
                    } label: {
                        Label("Files", systemImage: "folder")
                            .foregroundStyle(VitaColors.accent)
                    }
                }
            }
            // vita-modals-ignore: PdfTabDocumentPicker é UIViewControllerRepresentable nativo (UIDocumentPickerViewController) — VitaSheet quebra apresentação do system picker
            .sheet(isPresented: $showFilesPicker) {
                PdfTabDocumentPicker { pickedURL in
                    showFilesPicker = false
                    onSelect(pickedURL, pickedURL.lastPathComponent)
                }
            }
            .task { await load() }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(filteredGrouped, id: \.subject) { group in
                Section(header: Text(group.subject).font(VitaTypography.labelSmall).foregroundStyle(VitaColors.textTertiary)) {
                    ForEach(group.docs) { doc in
                        Button(action: { select(doc) }) {
                            DocRow(doc: doc)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(VitaColors.surfaceCard.opacity(0.4))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Data shaping

    private struct Group {
        let subject: String
        let docs: [VitaDocument]
    }

    private var filteredGrouped: [Group] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = q.isEmpty
            ? docs
            : docs.filter { $0.title.lowercased().contains(q) || ($0.subjectName?.lowercased().contains(q) ?? false) }

        let buckets = Dictionary(grouping: filtered) { $0.subjectName ?? "Sem matéria" }
        return buckets.keys.sorted().map { key in
            Group(subject: key, docs: buckets[key]!.sorted { $0.title < $1.title })
        }
    }

    // MARK: - Actions

    private func select(_ doc: VitaDocument) {
        let urlString = "\(AppConfig.apiBaseURL)/documents/\(doc.id)/file"
        guard let url = URL(string: urlString) else { return }
        onSelect(url, doc.title)
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            docs = try await container.api.getDocuments()
        } catch {
            loadError = "Não foi possível carregar seus documentos. Verifique sua conexão."
        }
        isLoading = false
    }
}

private struct DocRow: View {
    let doc: VitaDocument

    private var icon: String {
        let ext = doc.fileName.split(separator: ".").last?.lowercased() ?? ""
        switch ext {
        case "pdf": return "doc.text.fill"
        case "docx", "doc": return "doc.fill"
        case "xlsx", "xls": return "tablecells.fill"
        case "pptx", "ppt": return "rectangle.on.rectangle.fill"
        default: return "doc"
        }
    }

    private var ext: String {
        guard let last = doc.fileName.split(separator: ".").last else { return "" }
        return String(last).uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(VitaColors.accent)
                .frame(width: 32, height: 32)
                .background(VitaColors.accentSubtle.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(2)

                if !ext.isEmpty {
                    Text(ext)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
