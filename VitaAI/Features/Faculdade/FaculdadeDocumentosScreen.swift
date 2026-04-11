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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                if isLoading {
                    loadingState
                } else if let errorMessage {
                    errorState(errorMessage)
                } else if docs.isEmpty {
                    emptyState
                } else {
                    docsList
                }
                Spacer().frame(height: 40)
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

    // MARK: - Docs list (grouped by subject)

    private var docsList: some View {
        // Group by subjectId; null subject goes into "Outros"
        let grouped = Dictionary(grouping: docs) { $0.subjectId ?? "__none__" }
        let sortedKeys = grouped.keys.sorted { a, b in
            if a == "__none__" { return false }
            if b == "__none__" { return true }
            return a < b
        }
        return VStack(spacing: 14) {
            ForEach(sortedKeys, id: \.self) { key in
                if let items = grouped[key] {
                    let label = key == "__none__" ? "OUTROS" : items.first?.subjectId ?? key
                    subjectSection(label: label, docs: items)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func subjectSection(label: String, docs: [VitaDocument]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.accentHover.opacity(0.65))
                .padding(.leading, 4)
                .lineLimit(1)

            VStack(spacing: 6) {
                ForEach(docs) { doc in
                    docRow(doc)
                }
            }
        }
    }

    private func docRow(_ doc: VitaDocument) -> some View {
        Button {
            router.navigate(to: .pdfViewer(url: doc.fileUrl))
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
                        if doc.totalPages > 0 {
                            Text("\(doc.totalPages) pág")
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                        }
                        if let source = doc.source, source != "upload" {
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.30))
                            Text(source.capitalized)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(VitaColors.accentHover.opacity(0.60))
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

    // MARK: - Load

    private func loadDocs() async {
        isLoading = true
        errorMessage = nil
        do {
            let resp = try await container.api.getDocuments()
            docs = resp
        } catch {
            errorMessage = "Não foi possível carregar os documentos."
        }
        isLoading = false
    }
}
