import SwiftUI

// MARK: - Discipline selection (progressive step)

struct QBankDisciplineContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 44, height: 44)
                }
                Text("Disciplinas")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                if !vm.state.selectedDisciplineIds.isEmpty {
                    Text("\(vm.state.selectedDisciplineIds.count) sel.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VitaColors.accent)
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Breadcrumb
            if vm.state.disciplineBreadcrumb.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(vm.state.disciplineBreadcrumb.enumerated()), id: \.offset) { index, label in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(VitaColors.textTertiary.opacity(0.5))
                            }
                            Button {
                                vm.goBackBreadcrumb(to: index - 1)
                            } label: {
                                Text(label)
                                    .font(.system(size: 11, weight: index == vm.state.disciplineBreadcrumb.count - 1 ? .bold : .regular))
                                    .foregroundStyle(index == vm.state.disciplineBreadcrumb.count - 1 ? VitaColors.accent : VitaColors.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }

            // Selected chips
            if !vm.state.selectedDisciplineIds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(vm.state.selectedDisciplineIds), id: \.self) { id in
                            let title = findDisciplineTitle(id: id, in: vm.state.filters.disciplines)
                            HStack(spacing: 4) {
                                Text(title)
                                    .font(.system(size: 10, weight: .medium))
                                Button { vm.toggleDisciplineSelection(id) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                            }
                            .foregroundStyle(VitaColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(VitaColors.accent.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(VitaColors.accent.opacity(0.2), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }

            if vm.state.filtersLoading {
                Spacer()
                ProgressView().tint(VitaColors.accent)
                Spacer()
            } else {
                // Search field (applies to both Suas + Outras)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textTertiary)
                    TextField(
                        "Buscar disciplina...",
                        text: Binding(
                            get: { vm.state.disciplineSearch },
                            set: { vm.setDisciplineSearch($0) }
                        )
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(VitaColors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    if !vm.state.disciplineSearch.isEmpty {
                        Button { vm.setDisciplineSearch("") } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassCard(cornerRadius: 10)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // Sections: Suas Disciplinas (enrolled) + Outras Disciplinas (catalog)
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if let filterError = vm.state.filterError {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.textTertiary)
                                Text(filterError)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.textSecondary)
                                Spacer()
                                Button { vm.retryLoadFilters() } label: {
                                    Text("Tentar novamente")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(VitaColors.accent)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(VitaColors.glassBg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Suas Disciplinas
                        let enrolled = vm.state.enrolledDisciplinesFiltered
                            .sorted { vm.vitaScore(forTitle: $0.title) > vm.vitaScore(forTitle: $1.title) }
                        if !enrolled.isEmpty {
                            disciplineSectionHeader(
                                title: "SUAS DISCIPLINAS",
                                subtitle: "\(enrolled.count) da sua faculdade"
                            )
                            ForEach(enrolled) { disc in
                                QBankDisciplineCard(
                                    discipline: disc,
                                    isSelected: vm.state.selectedDisciplineIds.contains(disc.id),
                                    onTap: { vm.toggleDisciplineSelection(disc.id) },
                                    onToggle: { vm.toggleDisciplineSelection(disc.id) }
                                )
                            }
                        }

                        // Outras Disciplinas
                        let others = vm.state.otherDisciplinesFiltered
                        if !others.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    vm.toggleOtherDisciplinesExpanded()
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("OUTRAS DISCIPLINAS")
                                            .font(.system(size: 11, weight: .bold))
                                            .tracking(0.8)
                                            .foregroundStyle(VitaColors.sectionLabel)
                                        Text("\(others.count) disponíveis no catálogo")
                                            .font(.system(size: 10))
                                            .foregroundStyle(VitaColors.textTertiary)
                                    }
                                    Spacer()
                                    Image(systemName: vm.state.otherDisciplinesExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(VitaColors.textTertiary)
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if vm.state.otherDisciplinesExpanded {
                                ForEach(others) { disc in
                                    QBankDisciplineCard(
                                        discipline: disc,
                                        isSelected: vm.state.selectedDisciplineIds.contains(disc.id),
                                        onTap: { vm.toggleDisciplineSelection(disc.id) },
                                        onToggle: { vm.toggleDisciplineSelection(disc.id) }
                                    )
                                }
                            }
                        }

                        if enrolled.isEmpty && others.isEmpty {
                            Text(vm.state.disciplineSearch.isEmpty ? "Nenhuma disciplina disponível" : "Nada encontrado para \"\(vm.state.disciplineSearch)\"")
                                .font(.system(size: 13))
                                .foregroundStyle(VitaColors.textTertiary)
                                .padding(.vertical, 24)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                // Bottom CTA
                VStack(spacing: 0) {
                    Divider().overlay(VitaColors.glassBorder)
                    HStack {
                        if vm.state.selectedDisciplineIds.isEmpty {
                            Text("Selecione ou pule para usar todas")
                                .font(.system(size: 11))
                                .foregroundStyle(VitaColors.textTertiary)
                        } else {
                            Text("\(vm.state.selectedDisciplineIds.count) selecionada\(vm.state.selectedDisciplineIds.count == 1 ? "" : "s")")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(VitaColors.textPrimary)
                        }
                        Spacer()
                        VitaButton(
                            text: vm.state.selectedDisciplineIds.isEmpty ? "Pular" : "Próximo",
                            action: { vm.proceedFromDisciplines() }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 60)
                }
                .background(VitaColors.surface)
            }
        }
        
    }

    @ViewBuilder
    private func disciplineSectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(VitaColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func findDisciplineTitle(id: Int, in nodes: [QBankDiscipline]) -> String {
        for node in nodes {
            if node.id == id { return node.title }
            let found = findDisciplineTitle(id: id, in: node.children)
            if found != "\(id)" { return found }
        }
        return "\(id)"
    }
}

// MARK: - Discipline Card

struct QBankDisciplineCard: View {
    let discipline: QBankDiscipline
    let isSelected: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox for leaf, dot for parent
                if discipline.children.isEmpty {
                    Button(action: onToggle) {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textTertiary.opacity(0.5))
                    }
                    .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(VitaColors.accent.opacity(0.2))
                        .frame(width: 8, height: 8)
                        .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(discipline.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textPrimary)
                        .lineLimit(2)

                    if discipline.questionCount > 0 {
                        Text("\(discipline.questionCount) questões")
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }

                Spacer()

                if !discipline.children.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(discipline.children.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VitaColors.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VitaColors.surfaceElevated.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VitaColors.textTertiary.opacity(0.5))
                    }
                }
            }
            .padding(14)
            .background(VitaColors.glassBg)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? VitaColors.accent.opacity(0.3) : VitaColors.glassBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityCardLabel)
        .accessibilityHint(discipline.children.isEmpty ? "Toque para selecionar" : "Toque para ver subdisciplinas")
        .accessibilityValue(isSelected ? "Selecionada" : "Não selecionada")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityCardLabel: String {
        var parts = [discipline.title]
        if discipline.questionCount > 0 {
            parts.append("\(discipline.questionCount) questões")
        }
        if !discipline.children.isEmpty {
            parts.append("\(discipline.children.count) subdisciplinas")
        }
        return parts.joined(separator: ", ")
    }
}
