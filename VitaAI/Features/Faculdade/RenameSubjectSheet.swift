import SwiftUI

// MARK: - RenameSubjectSheet
//
// Bottom sheet to set/clear the user-ownable `displayName` on an academic_subject.
// Hit via long-press context menu on any subject card. Sync never overwrites
// this field (issue vitaai-web#170 phase A).
//
// Submit rules:
//  - Non-empty text → PATCH /api/subjects/{id} {displayName: "..."}
//  - Empty text    → PATCH with null → resets to portal-canonical name
//  - Same as current → no-op (dismiss)

struct RenameSubjectSheet: View {
    let subjectId: String
    let currentName: String
    let initialDisplayName: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appData) private var appData
    @State private var value: String = ""
    @State private var saving = false
    @FocusState private var focused: Bool

    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.45) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Renomear matéria")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Text("Só aparece pra você. A sincronização do portal não mexe nesse nome.")
                    .font(.system(size: 12))
                    .foregroundStyle(textDim)
            }

            TextField(currentName, text: $value)
                .font(.system(size: 15))
                .foregroundStyle(VitaColors.textPrimary)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VitaColors.surfaceCard.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(VitaColors.textWarm.opacity(0.10), lineWidth: 0.5)
                )
                .focused($focused)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .onSubmit(save)

            HStack(spacing: 8) {
                if initialDisplayName != nil {
                    Button(role: .destructive) {
                        Task {
                            saving = true
                            await appData.renameSubject(id: subjectId, displayName: nil)
                            saving = false
                            dismiss()
                        }
                    } label: {
                        Text("Restaurar original")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(saving)
                }

                Spacer()

                Button("Cancelar", role: .cancel) { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(saving)

                Button(action: save) {
                    Text(saving ? "Salvando..." : "Salvar")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(saving || value.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            value = initialDisplayName ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focused = true
            }
        }
    }

    private func save() {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !saving else { return }
        saving = true
        Task {
            await appData.renameSubject(id: subjectId, displayName: trimmed.isEmpty ? nil : trimmed)
            saving = false
            dismiss()
        }
    }
}
