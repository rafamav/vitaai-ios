import SwiftUI

// MARK: - Config content

struct QBankConfigContent: View {
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
                Text("Nova Sessão")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                if vm.state.hasActiveFilters {
                    Button("Limpar") { vm.clearFilters() }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VitaColors.accent)
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            if vm.state.filtersLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView().tint(VitaColors.accent)
                    Text("Carregando filtros...")
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        QBankSectionTitle("Número de Questões")
                        HStack(spacing: 8) {
                            ForEach([10, 20, 30, 50, 100], id: \.self) { count in
                                QBankChip(label: "\(count)", isSelected: vm.state.questionCount == count) {
                                    vm.setQuestionCount(count)
                                }
                            }
                        }

                        QBankSectionTitle("Dificuldade")
                        HStack(spacing: 8) {
                            ForEach([("easy","Fácil"),("medium","Médio"),("hard","Difícil")], id: \.0) { key, label in
                                QBankChip(label: label, isSelected: vm.state.selectedDifficulties.contains(key)) {
                                    vm.toggleDifficulty(key)
                                }
                            }
                        }

                        if !vm.state.filters.institutions.isEmpty {
                            QBankSectionTitle("Bancas / Instituições")
                            QBankFlowLayout(spacing: 8) {
                                ForEach(vm.state.filters.institutions) { inst in
                                    QBankChip(label: inst.name, isSelected: vm.state.selectedInstitutionIds.contains(inst.id)) {
                                        vm.toggleInstitution(inst.id)
                                    }
                                }
                            }
                        }

                        if !vm.state.filters.years.isEmpty {
                            QBankSectionTitle("Ano")
                            let sortedYears = vm.state.filters.years.sorted(by: >)
                            QBankFlowLayout(spacing: 8) {
                                ForEach(sortedYears, id: \.self) { year in
                                    QBankChip(label: "\(year)", isSelected: vm.state.selectedYears.contains(year)) {
                                        vm.toggleYear(year)
                                    }
                                }
                            }
                        }

                        if !vm.state.filters.topics.isEmpty {
                            QBankSectionTitle("Tópicos")
                            QBankFlowLayout(spacing: 8) {
                                ForEach(vm.state.filters.topics) { topic in
                                    QBankChip(label: topic.title, isSelected: vm.state.selectedTopicIds.contains(topic.id)) {
                                        vm.toggleTopic(topic.id)
                                    }
                                }
                            }
                        }

                        QBankSectionTitle("Opções")
                        VStack(spacing: 10) {
                            QBankConfigToggleRow(
                                icon: "graduationcap",
                                title: "Apenas Residência Médica",
                                description: "Filtra somente questões de prova de residência",
                                isOn: vm.state.onlyResidence
                            ) { vm.setOnlyResidence(!vm.state.onlyResidence) }

                            QBankConfigToggleRow(
                                icon: "circle.dotted",
                                title: "Apenas Não Respondidas",
                                description: "Exclui questões que você já respondeu",
                                isOn: vm.state.onlyUnanswered
                            ) { vm.setOnlyUnanswered(!vm.state.onlyUnanswered) }
                        }

                        if let filterError = vm.state.filterError {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.textTertiary)
                                Text(filterError)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.textSecondary)
                                Spacer()
                                Button {
                                    vm.retryLoadFilters()
                                } label: {
                                    Text("Tentar")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(VitaColors.accent)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(VitaColors.glassBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(VitaColors.glassBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        if let error = vm.state.error {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.dataRed)
                        }
                    }
                    .padding(16)
                }

                VStack(spacing: 8) {
                    if vm.state.sessionLoading {
                        VStack(spacing: 10) {
                            ProgressView().tint(VitaColors.accent)
                            Text("Montando sua sessão...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(VitaColors.accent)
                        }
                        .padding(.vertical, 12)
                    } else {
                        VitaButton(
                            text: "Iniciar Sessão (\(vm.state.questionCount) questões)",
                            action: { vm.createSession() }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .vitaScreenBg()
    }
}
