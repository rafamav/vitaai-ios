import SwiftUI

// MARK: - EditProfileSheet
// Shell §5.2.4: "Editar Perfil" abre VitaSheet com PATCH /api/profile, NUNCA push
// pra Configurações. Avatar tap (shell §5.2.3) ainda não — endpoint
// POST /api/profile/avatar não existe. Volta quando backend suportar.

struct EditProfileSheet: View {
    let initialProfile: ProfileResponse?
    var onSaved: (ProfileResponse) -> Void

    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var universityQuery: String = ""
    @State private var selectedUniversityId: String?
    @State private var semesterText: String = ""
    @State private var examBoard: String = ""

    @State private var universities: [University] = []
    @State private var isSearching = false
    @State private var isSaving = false
    // TODO: migrar para VitaError quando struct existir (shell §5.10 §11).
    @State private var errorMessage: String?

    var body: some View {
        VitaSheet(title: "Editar perfil", detents: [.large]) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    nameField
                    universityField
                    semesterField
                    examBoardField

                    if let errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(VitaColors.dataRed.opacity(0.85))
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.textPrimary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VitaColors.dataRed.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
        }
        .task { hydrate() }
    }

    // MARK: - Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Nome")
            TextField("Seu nome", text: $displayName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(14)
                .background(VitaColors.glassInnerLight.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(VitaColors.accentHover.opacity(0.16), lineWidth: 1)
                )
                .foregroundStyle(VitaColors.textPrimary)
        }
    }

    private var universityField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Faculdade")
            TextField("Buscar faculdade", text: $universityQuery)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(14)
                .background(VitaColors.glassInnerLight.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(VitaColors.accentHover.opacity(0.16), lineWidth: 1)
                )
                .foregroundStyle(VitaColors.textPrimary)
                .onChange(of: universityQuery) { _, q in
                    Task { await searchUniversities(query: q) }
                }

            if !universities.isEmpty && selectedUniversityId == nil {
                VStack(spacing: 0) {
                    ForEach(universities.prefix(5)) { uni in
                        Button(action: { selectUniversity(uni) }) {
                            HStack {
                                Text("\(uni.name) — \(uni.city)/\(uni.state)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(VitaColors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if uni.id != universities.prefix(5).last?.id {
                            Rectangle().fill(VitaColors.textWarm.opacity(0.04)).frame(height: 1)
                        }
                    }
                }
                .background(VitaColors.glassInnerLight.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var semesterField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Semestre atual")
            TextField("Ex: 6", text: $semesterText)
                .keyboardType(.numberPad)
                .padding(14)
                .background(VitaColors.glassInnerLight.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(VitaColors.accentHover.opacity(0.16), lineWidth: 1)
                )
                .foregroundStyle(VitaColors.textPrimary)
        }
    }

    private var examBoardField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Banca alvo (opcional)")
            TextField("USMLE, Revalida, AP, etc", text: $examBoard)
                .padding(14)
                .background(VitaColors.glassInnerLight.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(VitaColors.accentHover.opacity(0.16), lineWidth: 1)
                )
                .foregroundStyle(VitaColors.textPrimary)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VitaColors.sectionLabel)
            .kerning(0.5)
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Text("Cancelar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(VitaColors.glassInnerLight.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(isSaving)

            Button(action: { Task { await save() } }) {
                HStack(spacing: 8) {
                    if isSaving { ProgressView().controlSize(.small).tint(VitaColors.accentLight) }
                    Text(isSaving ? "Salvando..." : "Salvar")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(VitaColors.accent.opacity(0.20))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(VitaColors.accentHover.opacity(0.30), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSaving || !canSave)
            .opacity((isSaving || !canSave) ? 0.5 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(.ultraThinMaterial.opacity(0.85))
    }

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Logic

    private func hydrate() {
        guard let p = initialProfile else { return }
        displayName = p.displayName ?? ""
        universityQuery = p.university ?? ""
        selectedUniversityId = p.universityId
        semesterText = p.semester.map(String.init) ?? ""
        examBoard = p.examBoard ?? ""
    }

    private func searchUniversities(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        // User edited the field — drop the previous selection so the dropdown shows again.
        if selectedUniversityId != nil { selectedUniversityId = nil }
        guard trimmed.count >= 2 else { universities = []; return }
        isSearching = true
        defer { isSearching = false }
        do {
            let resp = try await container.api.getUniversities(query: trimmed)
            universities = resp.universities
        } catch {
            universities = []
        }
    }

    private func selectUniversity(_ uni: University) {
        selectedUniversityId = uni.id
        universityQuery = uni.name
        universities = []
    }

    private func save() async {
        guard canSave, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let body = UpdateProfileRequest(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            semester: Int(semesterText),
            examBoard: examBoard.trimmingCharacters(in: .whitespaces).isEmpty ? nil : examBoard,
            universityId: selectedUniversityId
        )

        do {
            let updated = try await container.api.updateProfile(body)
            appData.profile = updated
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = "Não foi possível salvar agora. Tente novamente em instantes."
        }
    }
}
