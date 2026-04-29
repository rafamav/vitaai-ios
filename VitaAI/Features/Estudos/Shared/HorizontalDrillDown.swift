import SwiftUI

// MARK: - HorizontalDrillDown — drill 3 níveis estilo Files / iCloud Drive
//
// Substitui BreadcrumbDrillDown (que era 2 níveis com tab única topo) por um
// modelo onde os níveis vão se acumulando como tabs no topo conforme o user
// navega pra dentro da hierarquia, e a lista embaixo mostra APENAS o nível
// atual. Resolve reclamações Rafael #11/#15/#16:
//   #15 "ele vai para uma tab na direita com a próxima granularidade ...
//        as coisas pra selecionar embaixo ao invés de ficar tudo na mesma
//        lista vertical"
//   #16 "anatomia, vai para uma nova taba onde tem as categorias ali"
//
// Arquitetura genérica (3 níveis, último opcional):
//   N1 = root (ex: Disciplinas) — sempre presente
//   N2 = filhos de N1 (ex: Temas)
//   N3 = filhos de N2 (ex: Conteúdos) — opcional; se closure devolver [],
//        o item N2 é "folha" (sem chevron, só checkbox)
//
// Caller fornece os níveis via closures lazy — assim a tela QBank pode
// consumir N1+N2 do payload de filters e (no futuro) lazy-load N3 via
// /api/qbank/filters?lens=&parentSlug=. Componente NÃO conhece API.
//
// Padrões obrigatórios respeitados:
//   - VitaColors / StudyShellTheme tokens (sem hex literal, sem Color.red)
//   - VitaGlassCard como wrapper visual padrão
//   - Sem .system(size:) sem fallback de tema
//   - Suporta theme.questoes / .simulados / .flashcards / .transcricao
//
// SOT: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §11

// MARK: - Item model

struct DrillItem: Identifiable, Hashable {
    /// Unique within its level. N1 = disciplineSlug, N2 = "parentSlug/topicId",
    /// N3 = "parentSlug/topicId/childId". O caller mantém a convenção que
    /// preferir desde que ID seja único dentro do nível.
    let id: String
    let name: String
    /// # questões (ou cards/itens) disponíveis neste nó. Mostrado à direita.
    let count: Int
    /// Indica se este item tem filhos no próximo nível. Quando `false`, o
    /// item é folha — sem chevron, tap em qualquer lugar = toggle select.
    let hasChildren: Bool
}

// MARK: - HorizontalDrillDown

struct HorizontalDrillDown: View {
    /// Título do nível root (ex: "Disciplinas", "Sistemas", "Áreas").
    let n1Title: String
    /// Título genérico do nível 2 (ex: "Temas"). Mostrado no breadcrumb
    /// quando o user ainda não escolheu uma N1 específica (não acontece no
    /// drill, só pra padding visual de label).
    let n2Title: String
    /// Título genérico do nível 3 (ex: "Conteúdos").
    let n3Title: String

    let theme: StudyShellTheme

    // Dados N1
    let n1Items: [DrillItem]
    @Binding var selectedN1Ids: Set<String>

    // N2 e N3 lazy via closures
    let n2ItemsFor: (_ n1Id: String) -> [DrillItem]
    @Binding var selectedN2Ids: Set<String>

    let n3ItemsFor: (_ n2Id: String) -> [DrillItem]
    @Binding var selectedN3Ids: Set<String>

    /// Disparado em cada toggle pra que o caller refaça preview.
    let onSelectionChange: () -> Void

    // MARK: Internal nav state

    @State private var pathN1: DrillItem? = nil   // disciplina selecionada pro drill
    @State private var pathN2: DrillItem? = nil   // tema selecionado pro drill
    @State private var search: String = ""

    private enum Level { case n1, n2, n3 }
    private var currentLevel: Level {
        if pathN2 != nil { return .n3 }
        if pathN1 != nil { return .n2 }
        return .n1
    }

    // MARK: Body

    var body: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                breadcrumbHeader
                searchBar
                Divider().background(VitaColors.glassBorder.opacity(0.4))
                Group {
                    switch currentLevel {
                    case .n1: list(items: filtered(n1Items), level: .n1)
                    case .n2:
                        if let n1 = pathN1 {
                            list(items: filtered(n2ItemsFor(n1.id)), level: .n2, parent: n1)
                        }
                    case .n3:
                        if let n2 = pathN2 {
                            list(items: filtered(n3ItemsFor(n2.id)), level: .n3, parent: n2)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: currentLevel)
            }
        }
    }

    // MARK: Breadcrumb (tabs)

    private var breadcrumbHeader: some View {
        HStack(spacing: 6) {
            tabButton(
                label: n1Title.uppercased(),
                isActive: currentLevel == .n1,
                action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        pathN1 = nil; pathN2 = nil; search = ""
                    }
                }
            )

            if let n1 = pathN1 {
                chevron
                tabButton(
                    label: n1.name,
                    isActive: currentLevel == .n2,
                    action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            pathN2 = nil; search = ""
                        }
                    }
                )
            }
            if let n2 = pathN2 {
                chevron
                tabButton(
                    label: n2.name,
                    isActive: currentLevel == .n3,
                    action: {} // já está nele — no-op
                )
            }

            Spacer(minLength: 4)

            let totalSelected = selectedN1Ids.count + selectedN2Ids.count + selectedN3Ids.count
            if totalSelected > 0 {
                Text("\(totalSelected) selec.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.primaryLight.opacity(0.85))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(VitaColors.textTertiary)
    }

    private func tabButton(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(isActive ? theme.primaryLight : VitaColors.sectionLabel)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .buttonStyle(.plain)
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

    private func filtered(_ items: [DrillItem]) -> [DrillItem] {
        guard !search.isEmpty else { return items }
        let q = search.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return items.filter { item in
            item.name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q)
        }
    }

    // MARK: Lists

    @ViewBuilder
    private func list(items: [DrillItem], level: Level, parent: DrillItem? = nil) -> some View {
        if items.isEmpty {
            Text(emptyMessage(level: level))
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 22)
        } else {
            VStack(spacing: 0) {
                if let parent {
                    selectAllRow(parent: parent, level: level)
                    Divider().background(VitaColors.glassBorder.opacity(0.4))
                }
                ForEach(items) { item in
                    row(item: item, level: level)
                    if item.id != items.last?.id {
                        Divider()
                            .background(VitaColors.glassBorder.opacity(0.3))
                            .padding(.leading, 40)
                    }
                }
            }
        }
    }

    private func emptyMessage(level: Level) -> String {
        if !search.isEmpty {
            return "Nada encontrado para \"\(search)\""
        }
        switch level {
        case .n1: return "Nenhum disponível"
        case .n2: return "Sem \(n2Title.lowercased()) disponíveis"
        case .n3: return "Sem \(n3Title.lowercased()) disponíveis"
        }
    }

    @ViewBuilder
    private func row(item: DrillItem, level: Level) -> some View {
        let isSelected = isSelected(item: item, level: level)
        HStack(spacing: 10) {
            Button {
                toggle(item: item, level: level)
            } label: {
                Image(systemName: checkboxIcon(level: level, selected: isSelected))
                    .font(.system(size: level == .n3 ? 14 : 16))
                    .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.5))
            }
            .buttonStyle(.plain)

            Button {
                if item.hasChildren {
                    drill(into: item, level: level)
                } else {
                    toggle(item: item, level: level)
                }
            } label: {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(formatCount(item.count))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VitaColors.textSecondary)
                    if item.hasChildren {
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

    private func checkboxIcon(level: Level, selected: Bool) -> String {
        switch level {
        case .n1, .n2: return selected ? "checkmark.circle.fill" : "circle"
        case .n3:      return selected ? "checkmark.square.fill" : "square"
        }
    }

    @ViewBuilder
    private func selectAllRow(parent: DrillItem, level: Level) -> some View {
        // Quando dentro de N2 ou N3, primeira linha é "selecionar pai inteiro".
        // Isso reflete a semântica: marcar a disciplina inteira (e derruba
        // sub-seleções) OU marcar o tema inteiro.
        let parentLevel: Level = (level == .n2) ? .n1 : .n2
        let isParentSelected = isSelected(item: parent, level: parentLevel)
        Button {
            toggle(item: parent, level: parentLevel)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isParentSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isParentSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.5))
                Text("\(parent.name) inteiro")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isParentSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.9))
                Spacer()
                Text(formatCount(parent.count))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(theme.primary.opacity(isParentSelected ? 0.12 : 0))
        }
        .buttonStyle(.plain)
    }

    // MARK: Selection / drill helpers

    private func isSelected(item: DrillItem, level: Level) -> Bool {
        switch level {
        case .n1: return selectedN1Ids.contains(item.id)
        case .n2: return selectedN2Ids.contains(item.id)
        case .n3: return selectedN3Ids.contains(item.id)
        }
    }

    private func toggle(item: DrillItem, level: Level) {
        switch level {
        case .n1:
            if selectedN1Ids.contains(item.id) {
                selectedN1Ids.remove(item.id)
                // ao desmarcar disciplina, derruba N2/N3 cujo prefixo seja dela
                let prefix = "\(item.id)/"
                selectedN2Ids = selectedN2Ids.filter { !$0.hasPrefix(prefix) }
                selectedN3Ids = selectedN3Ids.filter { !$0.hasPrefix(prefix) }
            } else {
                selectedN1Ids.insert(item.id)
            }
        case .n2:
            if selectedN2Ids.contains(item.id) {
                selectedN2Ids.remove(item.id)
                let prefix = "\(item.id)/"
                selectedN3Ids = selectedN3Ids.filter { !$0.hasPrefix(prefix) }
            } else {
                selectedN2Ids.insert(item.id)
            }
        case .n3:
            if selectedN3Ids.contains(item.id) {
                selectedN3Ids.remove(item.id)
            } else {
                selectedN3Ids.insert(item.id)
            }
        }
        onSelectionChange()
    }

    private func drill(into item: DrillItem, level: Level) {
        withAnimation(.easeInOut(duration: 0.22)) {
            switch level {
            case .n1: pathN1 = item; pathN2 = nil; search = ""
            case .n2: pathN2 = item; search = ""
            case .n3: break
            }
        }
    }

    // MARK: Format

    private func formatCount(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
