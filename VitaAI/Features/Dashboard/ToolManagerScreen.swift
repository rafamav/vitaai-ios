import SwiftUI
import Sentry

// MARK: - Tool Entry Model

struct ToolEntry: Identifiable, Hashable {
    let id: String
    let label: LocalizedStringKey
    let iconName: String // SF Symbol name
    let route: Route

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ToolEntry, rhs: ToolEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - All Available Tools

private let allTools: [ToolEntry] = [
    ToolEntry(
        id: "qbank",
        label: LocalizedStringKey("tool_manager_questoes"),
        iconName: "questionmark.circle",
        route: .qbank
    ),
    ToolEntry(
        id: "flashcards",
        label: LocalizedStringKey("tool_manager_flashcards"),
        iconName: "rectangle.on.rectangle.angled",
        route: .flashcardStats
    ),
    ToolEntry(
        id: "simulados",
        label: LocalizedStringKey("tool_manager_simulados"),
        iconName: "doc.text",
        route: .simuladoHome
    ),
    ToolEntry(
        id: "atlas",
        label: LocalizedStringKey("tool_manager_atlas"),
        iconName: "atom",
        route: .atlas3D
    ),
    ToolEntry(
        id: "resumos",
        label: LocalizedStringKey("tool_manager_resumos"),
        iconName: "doc.plaintext",
        route: .notebookList
    ),
    ToolEntry(
        id: "mapas",
        label: LocalizedStringKey("tool_manager_mapas"),
        iconName: "brain.head.profile",
        route: .mindMapList
    ),
    ToolEntry(
        id: "osce",
        label: LocalizedStringKey("tool_manager_osce"),
        iconName: "stethoscope",
        route: .osce
    ),
    ToolEntry(
        id: "trabalhos",
        label: LocalizedStringKey("tool_manager_trabalhos"),
        iconName: "tray.full",
        route: .trabalhos
    ),
    ToolEntry(
        id: "transcrição",
        label: LocalizedStringKey("tool_manager_transcricao"),
        iconName: "mic",
        route: .transcricao
    ),
    ToolEntry(
        id: "agenda",
        label: LocalizedStringKey("tool_manager_agenda"),
        iconName: "calendar",
        route: .agenda
    ),
    ToolEntry(
        id: "provas",
        label: LocalizedStringKey("tool_manager_provas"),
        iconName: "graduationcap",
        route: .provas
    ),
    ToolEntry(
        id: "cadernos",
        label: LocalizedStringKey("tool_manager_cadernos"),
        iconName: "book",
        route: .notebookList
    ),
]

// MARK: - Default Tool IDs

let defaultToolIds: Set<String> = [
    "qbank", "flashcards", "simulados", "atlas", "resumos", "mapas", "osce",
]

// MARK: - UserDefaults Key (scoped to user)

private func toolManagerKey(for userEmail: String?) -> String {
    let scope = userEmail ?? "default"
    return "vita_tool_manager_selected_ids_\(scope)"
}

// MARK: - Persistence Helpers

func loadSelectedToolIds(userEmail: String? = nil) -> Set<String> {
    let key = toolManagerKey(for: userEmail)
    guard let stored = UserDefaults.standard.array(forKey: key) as? [String] else {
        return defaultToolIds
    }
    return Set(stored)
}

func saveSelectedToolIds(_ ids: Set<String>, userEmail: String? = nil) {
    let key = toolManagerKey(for: userEmail)
    UserDefaults.standard.set(Array(ids), forKey: key)
}

// MARK: - ToolManagerScreen

struct ToolManagerScreen: View {
    let onBack: () -> Void
    let onSave: (Set<String>) -> Void

    @Environment(\.appContainer) private var container
    @State private var selectedIds: Set<String>

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    init(onBack: @escaping () -> Void, onSave: @escaping (Set<String>) -> Void) {
        self.onBack = onBack
        self.onSave = onSave
        _selectedIds = State(initialValue: defaultToolIds)
    }

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top Bar
                topBar

                // MARK: - Selected Counter Pill
                counterPill
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                Spacer().frame(height: 16)

                // MARK: - Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(allTools) { tool in
                            ToolGridItem(
                                tool: tool,
                                isSelected: selectedIds.contains(tool.id),
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if selectedIds.contains(tool.id) {
                                            selectedIds.remove(tool.id)
                                        } else {
                                            selectedIds.insert(tool.id)
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // MARK: - Save Button
                saveButton
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            selectedIds = loadSelectedToolIds(userEmail: container.authManager.userEmail)
            SentrySDK.reportFullyDisplayed()
        }
        .trackScreen("ToolManager")
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(VitaColors.textPrimary)
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("tool_manager_title"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(VitaColors.textPrimary)

                Text(LocalizedStringKey("tool_manager_subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(VitaColors.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
    }

    // MARK: - Counter Pill

    private var counterPill: some View {
        HStack {
            Text(String(format: NSLocalizedString("tool_manager_selected_count", comment: ""), selectedIds.count))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(VitaColors.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(VitaColors.accent.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(VitaColors.accent.opacity(0.25), lineWidth: 1)
                        )
                )

            Spacer()
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: {
            saveSelectedToolIds(selectedIds, userEmail: container.authManager.userEmail)
            onSave(selectedIds)
        }) {
            Text(LocalizedStringKey("tool_manager_save"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(VitaColors.surface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(VitaColors.accent)
                )
        }
    }
}

// MARK: - ToolGridItem

private struct ToolGridItem: View {
    let tool: ToolEntry
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                // Icon container with checkbox overlay
                ZStack(alignment: .topTrailing) {
                    // Icon background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isSelected
                                ? VitaColors.accent.opacity(0.15)
                                : VitaColors.surfaceElevated.opacity(0.5)
                        )
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: tool.iconName)
                                .font(.system(size: 20))
                                .foregroundColor(
                                    isSelected ? VitaColors.accent : VitaColors.textSecondary
                                )
                        }

                    // Checkbox indicator (top-right)
                    if isSelected {
                        Circle()
                            .fill(VitaColors.accent)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(VitaColors.surface)
                            }
                            .offset(x: 4, y: -4)
                    }
                }
                .frame(width: 52, height: 52)

                // Label
                Text(tool.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(
                        isSelected ? VitaColors.textPrimary : VitaColors.textSecondary
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? VitaColors.accent.opacity(0.10) : VitaColors.glassBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? VitaColors.accent.opacity(0.5) : VitaColors.glassBorder,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
