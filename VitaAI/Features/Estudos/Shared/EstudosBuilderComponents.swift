import SwiftUI

// MARK: - Estudos Builder — components compartilhados (Fase 2 reescrita 3 paginas)
//
// SOT do spec: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md
//
// Cada page (Questoes/Simulados/Flashcards) compõe estes blocks no mesmo
// padrão visual. Diff é o conteúdo específico (qual seção colapsa, qual
// não tem cronômetro, qual tem mode selector). Layout geral compartilhado.

// MARK: - FilterChipsRow — tags removíveis dos filtros aplicados

/// Stack horizontal de chips removíveis ("🏷️ Cardio ✕ · ULBRA ✕ · 2024+ ✕").
/// Quando vazio, se esconde. Botão "Limpar" ao lado quando há ≥2 chips.
struct FilterChipsRow: View {
    struct Chip: Identifiable, Hashable {
        let id: String
        let label: String
        let onRemove: () -> Void

        static func == (a: Chip, b: Chip) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    let chips: [Chip]
    let theme: StudyShellTheme
    let onClearAll: (() -> Void)?

    var body: some View {
        if !chips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if chips.count >= 2, let onClearAll {
                    HStack {
                        Text("Filtros (\(chips.count))")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(VitaColors.sectionLabel)
                        Spacer()
                        Button("Limpar") { onClearAll() }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.primaryLight.opacity(0.85))
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(chips) { chip in
                            chipPill(chip: chip)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func chipPill(chip: Chip) -> some View {
        Button(action: chip.onRemove) {
            HStack(spacing: 5) {
                Text(chip.label)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(theme.primaryLight.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(theme.primary.opacity(0.20))
            )
            .overlay(
                Capsule()
                    .stroke(theme.primaryLight.opacity(0.30), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GroupRow — uma linha de grupo (disciplina/sistema/great-area) com count

/// Linha selecionável estilo MedEvo: bullet color + nome + count à direita.
/// Tap toggla seleção; multi-select.
struct GroupRow: View {
    let slug: String
    let name: String
    let count: Int
    let isSelected: Bool
    let theme: StudyShellTheme
    let action: () -> Void

    private var formattedCount: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.5))
                Text(name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Text(formattedCount)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SpecialtyMultiSelect — busca + lista expandível com count

/// Card glass que mostra os top-N grupos visíveis + campo de busca quando
/// expandido + botão "Mais ↓" pra ver toda a lista. Filtro principal das
/// 3 telas; muda label conforme lente (Disciplinas/Sistemas/Áreas).
struct SpecialtyMultiSelect: View {
    let title: String
    let groups: [QBankFiltersGroupsInner]
    @Binding var selectedSlugs: Set<String>
    let theme: StudyShellTheme

    @State private var search: String = ""
    @State private var expanded: Bool = false

    private var filtered: [QBankFiltersGroupsInner] {
        guard !search.isEmpty else { return groups }
        let q = search.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return groups.filter {
            ($0.name ?? "")
                .folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .contains(q)
        }
    }

    private var visible: [QBankFiltersGroupsInner] {
        if expanded || filtered.count <= 6 { return filtered }
        return Array(filtered.prefix(6))
    }

    var body: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                header
                if expanded { searchBar }
                Divider().background(VitaColors.glassBorder.opacity(0.4))
                rowsList
                if filtered.count > 6 { footerToggle }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            if !selectedSlugs.isEmpty {
                Text("· \(selectedSlugs.count) selec.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.primaryLight)
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.primaryLight.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textTertiary)
            TextField("Buscar...", text: $search)
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VitaColors.surfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var rowsList: some View {
        VStack(spacing: 0) {
            if visible.isEmpty {
                Text(search.isEmpty ? "Nenhum resultado disponível" : "Nada encontrado para \"\(search)\"")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(visible, id: \.slug) { group in
                    let slug = group.slug ?? ""
                    let isSelected = selectedSlugs.contains(slug)
                    GroupRow(
                        slug: slug,
                        name: group.name ?? slug,
                        count: group.count ?? 0,
                        isSelected: isSelected,
                        theme: theme,
                        action: {
                            if isSelected { selectedSlugs.remove(slug) }
                            else { selectedSlugs.insert(slug) }
                        }
                    )
                    if group.slug != visible.last?.slug {
                        Divider()
                            .background(VitaColors.glassBorder.opacity(0.3))
                            .padding(.leading, 40)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footerToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
        } label: {
            HStack {
                Text(expanded ? "Mostrar menos" : "Ver todos (\(filtered.count))")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(theme.primaryLight.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BreadcrumbDrillDown — navegação por níveis dentro do card

/// Substitui HierarchicalGroupSelect com navegação tipo Files app:
/// - Root: lista de groups (Sistemas / Disciplinas / Áreas)
/// - Tap em group com children → navega pra dentro (substitui card content)
/// - Dentro de um group: breadcrumb topo + lista de filhos + opção "Selecionar tudo"
/// - Voltar: tap no breadcrumb root
///
/// Decisão Rafael 2026-04-29: ao invés de expand vertical (lista interna
/// do card crescendo), card SOFRE drill-down — só uma lista por vez.
struct BreadcrumbDrillDown: View {
    let title: String
    let groups: [QBankGroup]
    @Binding var selectedGroupSlugs: Set<String>
    @Binding var selectedSubgroupIds: Set<String>
    let theme: StudyShellTheme

    @State private var navSlug: String? = nil
    @State private var search: String = ""

    private var currentNode: QBankGroup? {
        guard let slug = navSlug else { return nil }
        return groups.first(where: { $0.slug == slug })
    }

    private var filteredGroups: [QBankGroup] {
        guard !search.isEmpty else { return groups }
        let q = search.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return groups.filter { g in
            g.name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q)
        }
    }

    private var filteredChildren: [QBankGroupChild] {
        guard let node = currentNode else { return [] }
        guard !search.isEmpty else { return node.children }
        let q = search.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return node.children.filter { c in
            c.name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q)
        }
    }

    var body: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                breadcrumbHeader
                searchBar
                Divider().background(VitaColors.glassBorder.opacity(0.4))
                if currentNode == nil {
                    rootList
                } else {
                    childList
                }
            }
        }
    }

    // MARK: Breadcrumb

    private var breadcrumbHeader: some View {
        HStack(spacing: 6) {
            // Root tab — sempre presente
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    navSlug = nil
                    search = ""
                }
            } label: {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(navSlug == nil ? theme.primaryLight : VitaColors.sectionLabel)
            }
            .buttonStyle(.plain)

            if let node = currentNode {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(VitaColors.textTertiary)
                Text(node.name)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(theme.primaryLight)
                    .lineLimit(1)
            }

            Spacer()

            if !selectedGroupSlugs.isEmpty || !selectedSubgroupIds.isEmpty {
                Text("\(selectedGroupSlugs.count + selectedSubgroupIds.count) selec.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.primaryLight.opacity(0.85))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textTertiary)
            TextField("Buscar...", text: $search)
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VitaColors.surfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: Root list (sistemas/disciplinas/áreas)

    @ViewBuilder
    private var rootList: some View {
        if filteredGroups.isEmpty {
            Text(search.isEmpty ? "Nenhum disponível" : "Nada encontrado para \"\(search)\"")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        } else {
            VStack(spacing: 0) {
                ForEach(filteredGroups) { group in
                    let isSelected = selectedGroupSlugs.contains(group.slug)
                    let hasChildren = !group.children.isEmpty
                    rootRow(group: group, isSelected: isSelected, hasChildren: hasChildren)
                    if group.slug != filteredGroups.last?.slug {
                        Divider()
                            .background(VitaColors.glassBorder.opacity(0.3))
                            .padding(.leading, 40)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rootRow(group: QBankGroup, isSelected: Bool, hasChildren: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                if isSelected {
                    selectedGroupSlugs.remove(group.slug)
                    selectedSubgroupIds = selectedSubgroupIds.filter { !$0.hasPrefix("\(group.slug)/") }
                } else {
                    selectedGroupSlugs.insert(group.slug)
                }
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.5))
            }
            .buttonStyle(.plain)

            // Tap no nome → navega pra dentro (se tem children) OU seleciona (se folha)
            Button {
                if hasChildren {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        navSlug = group.slug
                        search = ""
                    }
                } else {
                    if isSelected { selectedGroupSlugs.remove(group.slug) }
                    else { selectedGroupSlugs.insert(group.slug) }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(group.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(formatCount(group.count))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VitaColors.textSecondary)
                    if hasChildren {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: Child list (clusters/topics)

    @ViewBuilder
    private var childList: some View {
        if let node = currentNode {
            VStack(spacing: 0) {
                // "Selecionar [pai] inteiro" como primeira opção
                let parentSelected = selectedGroupSlugs.contains(node.slug)
                Button {
                    if parentSelected {
                        selectedGroupSlugs.remove(node.slug)
                        selectedSubgroupIds = selectedSubgroupIds.filter { !$0.hasPrefix("\(node.slug)/") }
                    } else {
                        selectedGroupSlugs.insert(node.slug)
                        selectedSubgroupIds = selectedSubgroupIds.filter { !$0.hasPrefix("\(node.slug)/") }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: parentSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(parentSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.5))
                        Text("\(node.name) inteiro")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(parentSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.9))
                        Spacer()
                        Text(formatCount(node.count))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(theme.primary.opacity(parentSelected ? 0.12 : 0))
                }
                .buttonStyle(.plain)

                Divider().background(VitaColors.glassBorder.opacity(0.4))

                if filteredChildren.isEmpty {
                    Text(search.isEmpty ? "Sem subgranularidade disponível" : "Nada encontrado para \"\(search)\"")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ForEach(filteredChildren) { child in
                        let id = child.id
                        let childSelected = selectedSubgroupIds.contains(id)
                        Button {
                            if childSelected {
                                selectedSubgroupIds.remove(id)
                            } else {
                                selectedSubgroupIds.insert(id)
                                selectedGroupSlugs.insert(child.parentSlug)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: childSelected ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 14))
                                    .foregroundStyle(childSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.5))
                                Text(child.name)
                                    .font(.system(size: 13, weight: childSelected ? .semibold : .regular))
                                    .foregroundStyle(childSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.85))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Text(formatCount(child.count))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(VitaColors.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if child.id != filteredChildren.last?.id {
                            Divider()
                                .background(VitaColors.glassBorder.opacity(0.3))
                                .padding(.leading, 40)
                        }
                    }
                }
            }
        }
    }

    private func formatCount(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - HierarchicalGroupSelect — DEPRECATED, mantido por compat (usar BreadcrumbDrillDown)
struct HierarchicalGroupSelect: View {
    let title: String
    let groups: [QBankGroup]
    @Binding var selectedGroupSlugs: Set<String>
    @Binding var selectedSubgroupIds: Set<String>  // "parent/child"
    @Binding var expandedSlugs: Set<String>
    let theme: StudyShellTheme

    @State private var search: String = ""
    @State private var searchFocused: Bool = false

    private var filtered: [QBankGroup] {
        guard !search.isEmpty else { return groups }
        let q = search.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return groups.filter { g in
            let n = g.name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            if n.contains(q) { return true }
            return g.children.contains { c in
                c.name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q)
            }
        }
    }

    var body: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                header
                if searchFocused { searchBar }
                Divider().background(VitaColors.glassBorder.opacity(0.4))
                rowsList
            }
        }
    }

    private var header: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            if !selectedGroupSlugs.isEmpty {
                Text("· \(selectedGroupSlugs.count) selec.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.primaryLight)
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { searchFocused.toggle() }
            } label: {
                Image(systemName: searchFocused ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.primaryLight.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textTertiary)
            TextField("Buscar...", text: $search)
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VitaColors.surfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var rowsList: some View {
        if filtered.isEmpty {
            Text(search.isEmpty ? "Nenhum disponível" : "Nada encontrado para \"\(search)\"")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        } else {
            VStack(spacing: 0) {
                ForEach(filtered) { group in
                    GroupTreeRow(
                        group: group,
                        isSelected: selectedGroupSlugs.contains(group.slug),
                        isExpanded: expandedSlugs.contains(group.slug),
                        selectedSubgroupIds: $selectedSubgroupIds,
                        theme: theme,
                        onToggleSelect: {
                            if selectedGroupSlugs.contains(group.slug) {
                                selectedGroupSlugs.remove(group.slug)
                                // Limpa subgroups daquele pai
                                selectedSubgroupIds = selectedSubgroupIds.filter {
                                    !$0.hasPrefix("\(group.slug)/")
                                }
                            } else {
                                selectedGroupSlugs.insert(group.slug)
                            }
                        },
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                if expandedSlugs.contains(group.slug) {
                                    expandedSlugs.remove(group.slug)
                                } else {
                                    expandedSlugs.insert(group.slug)
                                }
                            }
                        }
                    )
                    if group.slug != filtered.last?.slug {
                        Divider()
                            .background(VitaColors.glassBorder.opacity(0.3))
                            .padding(.leading, 40)
                    }
                }
            }
        }
    }
}

private struct GroupTreeRow: View {
    let group: QBankGroup
    let isSelected: Bool
    let isExpanded: Bool
    @Binding var selectedSubgroupIds: Set<String>
    let theme: StudyShellTheme
    let onToggleSelect: () -> Void
    let onToggleExpand: () -> Void

    private var formattedCount: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: group.count)) ?? "\(group.count)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onToggleSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.5))
                }
                .buttonStyle(.plain)

                Button(action: onToggleSelect) {
                    Text(group.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Text(formattedCount)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.textSecondary)

                if !group.children.isEmpty {
                    Button(action: onToggleExpand) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(VitaColors.textTertiary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 24)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if isExpanded && !group.children.isEmpty {
                VStack(spacing: 0) {
                    ForEach(group.children) { child in
                        let id = child.id
                        let childSelected = selectedSubgroupIds.contains(id)
                        Button {
                            if childSelected {
                                selectedSubgroupIds.remove(id)
                            } else {
                                selectedSubgroupIds.insert(id)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: childSelected ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 13))
                                    .foregroundStyle(childSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.5))
                                Text(child.name)
                                    .font(.system(size: 12, weight: childSelected ? .semibold : .regular))
                                    .foregroundStyle(childSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.85))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Text(NumberFormatter.localizedString(from: NSNumber(value: child.count), number: .decimal))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(VitaColors.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .padding(.leading, 26)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(VitaColors.surfaceElevated.opacity(0.25))
                .transition(.opacity)
            }
        }
    }
}

// MARK: - FormatPills — chips de formato (Objetivas/Discursivas/c/Imagem)

struct FormatPills: View {
    @Binding var selected: Set<String>  // 'objective' | 'discursive' | 'withImage'
    let theme: StudyShellTheme

    private let options: [(slug: String, label: String, icon: String)] = [
        ("objective", "Objetivas", "list.bullet"),
        ("discursive", "Discursivas", "text.alignleft"),
        ("withImage", "Com Imagem", "photo"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FORMATO")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            HStack(spacing: 6) {
                ForEach(options, id: \.slug) { opt in
                    let isSelected = selected.contains(opt.slug)
                    Button {
                        if isSelected { selected.remove(opt.slug) }
                        else { selected.insert(opt.slug) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: opt.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(opt.label)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? theme.primaryLight.opacity(0.98) : VitaColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isSelected ? theme.primary.opacity(0.22) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(isSelected ? theme.primaryLight.opacity(0.32) : VitaColors.glassBorder, lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - AdvancedSection — collapsible group de toggles

struct AdvancedToggleItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String?
    let isOn: Bool
    let action: () -> Void
}

struct AdvancedSection: View {
    let items: [AdvancedToggleItem]
    let theme: StudyShellTheme

    @State private var expanded: Bool = false

    var body: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.primaryLight.opacity(0.9))
                        Text("AVANÇADAS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(VitaColors.sectionLabel)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    Divider().background(VitaColors.glassBorder.opacity(0.4))
                    VStack(spacing: 6) {
                        ForEach(items) { item in
                            QBankConfigToggleRow(
                                icon: item.icon,
                                title: item.title,
                                description: item.description ?? "",
                                isOn: item.isOn,
                                action: item.action
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - StickyBottomCTA — count vivo + botão "Iniciar"
//
// Usado via `.safeAreaInset(edge: .bottom)` no ScrollView. Isso garante:
// 1. Conteúdo do scroll respeita automaticamente a altura do CTA
//    (sem precisar de Spacer(minLength:) ou padding fake).
// 2. CTA fica grudado acima da custom tab bar (VitaTabBar mora em overlay
//    fora do safe area do sistema, então reservamos os ~94px manualmente
//    via `tabBarReserve` abaixo).
// 3. Background gradient se mistura naturalmente sobre o conteúdo do scroll
//    sem cobrir nem ser coberto pelo tab bar.
//
// Bug fix 2026-04-28: antes usava ZStack(alignment:.bottom) com padding
// .bottom 140 fixo, mas como AppRouter aplica `.ignoresSafeArea(.container,
// edges: .bottom)` no activeTabView, o CTA renderizava em coordenada fora
// da viewport útil. Rafael cobrou 5x, agora usa o pattern canônico SwiftUI.
struct StickyBottomCTA: View {
    let title: String
    let count: Int
    let isLoading: Bool
    let isCreating: Bool
    let theme: StudyShellTheme
    let action: () -> Void

    /// Altura visual do VitaTabBar custom (54) + safe area bottom típico
    /// iPhone moderno (~34) + folga visual (6) = 94. Tab bar mora em
    /// overlay no AppRouter, então não conta no safeAreaInset do sistema.
    private let tabBarReserve: CGFloat = 94

    private var formattedCount: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    var body: some View {
        VStack(spacing: 6) {
            if isCreating {
                HStack(spacing: 8) {
                    ProgressView().tint(theme.primaryLight)
                    Text("Montando sessão...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.primaryLight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                StudyShellCTA(
                    title: title,
                    theme: theme,
                    action: action,
                    systemImage: "play.fill"
                )
                .opacity(count > 0 ? 1.0 : 0.4)
                .disabled(count == 0)
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, tabBarReserve)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: VitaColors.surface.opacity(0.92), location: 0.25),
                    .init(color: VitaColors.surface, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }
}

// MARK: - ModePills — variantes "modo" pra Simulado e Flashcard

/// Selector de "modo" tipo segmented control gold-glass. Usado em:
/// - Simulado: [Template · Custom]
/// - Flashcard: [Revisão · Específico · Novos]
struct ModePills<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String
    let icon: (T) -> String
    let theme: StudyShellTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODO")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            HStack(spacing: 6) {
                ForEach(options) { opt in
                    let isSelected = selection == opt
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = opt }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: icon(opt))
                                .font(.system(size: 14, weight: .semibold))
                            Text(label(opt))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? theme.primaryLight.opacity(0.98) : VitaColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(isSelected ? theme.primary.opacity(0.22) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(isSelected ? theme.primaryLight.opacity(0.32) : VitaColors.glassBorder, lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
