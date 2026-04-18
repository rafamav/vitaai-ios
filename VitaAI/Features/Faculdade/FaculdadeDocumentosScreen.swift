import SwiftUI

// MARK: - FaculdadeDocumentosScreen
//
// Full-screen subpage: Faculdade → Documentos.
// Lists all PDFs from the user's library (synced from portal + uploads),
// grouped by subject. Tapping a doc opens it in the PDF viewer.
//
// Source of truth: GET /api/documents (returns array of VitaDocument).

struct FaculdadeDocumentosScreen: View {
    let onBack: () -> Void
    @Environment(\.appContainer) private var container
    @Environment(Router.self) private var router

    @State private var docs: [VitaDocument] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var expandedSections: Set<String> = []

    /// Build subject name map from documents' subjectName field (returned by API)
    private var subjectNameMap: [String: String] {
        var map: [String: String] = [:]
        for doc in docs {
            if let sid = doc.subjectId, let name = doc.subjectName, !name.isEmpty {
                map[sid] = name
            }
        }
        return map
    }

    private var filteredDocs: [VitaDocument] {
        guard !searchText.isEmpty else { return docs }
        let q = searchText.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return docs.filter { doc in
            let title = doc.title.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            if title.contains(q) { return true }
            if let name = doc.subjectName {
                return name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q)
            }
            return false
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                // Search bar
                if !docs.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        TextField("Buscar documento...", text: $searchText)
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.textPrimary)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(VitaColors.textWarm.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(VitaColors.glassBg))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.glassBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
                }

                if isLoading {
                    loadingState
                } else if let errorMessage {
                    errorState(errorMessage)
                } else if docs.isEmpty {
                    emptyState
                } else if filteredDocs.isEmpty {
                    Text("Nenhum documento encontrado")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                        .padding(.top, 40)
                } else {
                    docsList
                }
                Spacer().frame(height: 100)
            }
            .padding(.top, 8)
        }
        .task {
            await loadDocs()
        }
        .refreshable {
            await loadDocs()
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(VitaColors.accent)
            Text("Carregando documentos...")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(VitaColors.accentHover.opacity(0.50))
            Text("Erro ao carregar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 44))
                .foregroundStyle(VitaColors.accentHover.opacity(0.40))
            Text("Sem documentos")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
            Text("Conecte seu portal para importar planos de ensino, slides e materiais.")
                .font(.system(size: 11))
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Docs list (grouped by subject, tappable to navigate to discipline)

    private var docsList: some View {
        // Group by subjectId; null subject goes into "Outros"
        let grouped = Dictionary(grouping: filteredDocs) { $0.subjectId ?? "__none__" }
        let sortedKeys = grouped.keys.sorted { a, b in
            if a == "__none__" { return false }
            if b == "__none__" { return true }
            let nameA = subjectNameMap[a] ?? a
            let nameB = subjectNameMap[b] ?? b
            return nameA < nameB
        }
        return VStack(spacing: 14) {
            ForEach(sortedKeys, id: \.self) { key in
                if let items = grouped[key] {
                    let name = key == "__none__" ? "Outros" : (subjectNameMap[key] ?? key)
                    subjectSection(label: name, subjectId: key, docs: items)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func subjectSection(label: String, subjectId: String, docs: [VitaDocument]) -> some View {
        let isExpanded = expandedSections.contains(subjectId)
        // When searching, always show expanded
        let showDocs = isExpanded || !searchText.isEmpty

        return VStack(alignment: .leading, spacing: 6) {
            // Tappable header → expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedSections.contains(subjectId) {
                        expandedSections.remove(subjectId)
                    } else {
                        expandedSections.insert(subjectId)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    // Discipline icon
                    Image(DisciplineImages.imageAsset(for: label))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())

                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(docs.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(VitaColors.glassBg))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.30))
                        .rotationEffect(.degrees(showDocs ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(VitaColors.surfaceCard.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            if showDocs {
                VStack(spacing: 6) {
                    ForEach(docs) { doc in
                        docRow(doc)
                    }
                }
                .padding(.leading, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func docRow(_ doc: VitaDocument) -> some View {
        Button {
            router.navigate(to: .pdfViewer(url: "\(AppConfig.apiBaseURL)/documents/\(doc.id)/file"))
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(VitaColors.dataRed.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VitaColors.dataRed)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.title.isEmpty ? doc.fileName : doc.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        if let dateStr = doc.createdAt, let date = parseISO(dateStr) {
                            Text(date, style: .date)
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                        }
                        if doc.readProgress > 0 {
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.30))
                            Text("\(Int(doc.readProgress * 100))% lido")
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.dataGreen.opacity(0.75))
                        }
                    }
                }

                Spacer()

                if doc.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.accentHover.opacity(0.85))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.25))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(VitaColors.surfaceCard.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func parseISO(_ str: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: str) ?? ISO8601DateFormatter().date(from: str)
    }

    // MARK: - Load

    private func loadDocs() async {
        isLoading = true
        errorMessage = nil
        do {
            docs = try await container.api.getDocuments()
        } catch {
            errorMessage = "Não foi possível carregar os documentos."
        }
        isLoading = false
    }
}
