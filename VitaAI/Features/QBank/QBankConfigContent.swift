import SwiftUI

// MARK: - Config content (Android parity: status, count, year range, institution/topic sheets)

struct QBankConfigContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void

    @State private var showInstitutionSheet = false
    @State private var showCustomSlider = false

    private let presetCounts = [10, 20, 30, 50]

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
                .accessibilityIdentifier("backButton")
                Text("Configurar Sessão")
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
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // [M] Mode toggle (Prática / Simulado)
                        modeToggleSection

                        // [0] Selected disciplines summary
                        if !vm.state.selectedDisciplineIds.isEmpty {
                            selectedDisciplinesSummary
                        }

                        // [1] Available count banner
                        availableCountBanner

                        // [2] Question count
                        questionCountSection

                        // [3] Difficulty
                        if !vm.state.filters.difficulties.isEmpty {
                            difficultySection
                        }

                        // [4] Quality filters (Rafael 2026-04-27 — A5 UI-SHIPPER)
                        qualitySection

                        // [5] Year range
                        if !vm.state.filters.years.isEmpty {
                            yearRangeSection
                        }

                        // [6] Institution picker
                        if !vm.state.filters.institutions.isEmpty {
                            filterPickerCard(
                                title: "INSTITUICAO",
                                selectedCount: vm.state.selectedInstitutionIds.count,
                                totalCount: vm.state.filters.institutions.count,
                                selectedPreview: vm.state.filters.institutions
                                    .filter { vm.state.selectedInstitutionIds.contains($0.id) }
                                    .prefix(3)
                                    .map(\.name)
                                    .joined(separator: ", ")
                            ) {
                                showInstitutionSheet = true
                            }
                        }

                        // [7] Topic expandable section
                        if !vm.state.filters.topics.isEmpty {
                            topicExpandableSection
                        }

                        // Filter error
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
                            .glassCard(cornerRadius: 10)
                        }

                        // Error
                        if let error = vm.state.error {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.dataRed)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }

                // Bottom CTA
                bottomCTA
            }
        }
        .background(Color.clear)
        .sheet(isPresented: $showInstitutionSheet) {
            VitaSheet(title: "Instituição") {
                QBankInstitutionSheet(vm: vm)
            }
        }
    }

    // MARK: - Sections

    private var selectedDisciplinesSummary: some View {
        VitaGlassCard(cornerRadius: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DISCIPLINAS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(VitaColors.sectionLabel)
                    Text(vm.state.selectedDisciplineSummary)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.accentLight)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(vm.state.selectedTopicIds.count) temas")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var availableCountBanner: some View {
        VitaGlassCard(cornerRadius: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(VitaColors.accent)
                if vm.state.isLoadingCount {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .scaleEffect(0.7)
                    Text("Calculando...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VitaColors.textSecondary)
                } else {
                    Text("\(formatNumber(vm.state.displayAvailableCount)) questões disponíveis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.accentLight)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var questionCountSection: some View {
        configGlassSection(title: "NÚMERO DE QUESTOES") {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presetCounts, id: \.self) { count in
                            QBankChip(
                                label: "\(count)",
                                isSelected: vm.state.questionCount == count && !showCustomSlider
                            ) {
                                vm.setQuestionCount(count)
                                showCustomSlider = false
                            }
                        }
                        QBankChip(
                            label: "Personalizado",
                            isSelected: showCustomSlider
                        ) {
                            showCustomSlider = true
                        }
                    }
                }

                if showCustomSlider {
                    Text("\(vm.state.questionCount) questões")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VitaColors.accentLight)
                        .padding(.top, 4)

                    Slider(
                        value: Binding(
                            get: { Double(vm.state.questionCount) },
                            set: { vm.setQuestionCount(Int($0)) }
                        ),
                        in: 5...100,
                        step: 5
                    )
                    .tint(VitaColors.accent)

                    HStack {
                        Text("5")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textTertiary)
                        Spacer()
                        Text("100")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            }
        }
        .onAppear {
            showCustomSlider = !presetCounts.contains(vm.state.questionCount)
        }
    }

    private var difficultySection: some View {
        configGlassSection(title: "DIFICULDADE") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.state.filters.difficulties) { dc in
                        let label = "\(dc.displayLabel) (\(dc.count))"
                        let color: Color = {
                            switch dc.difficulty {
                            case "easy":  return VitaColors.dataGreen
                            case "hard":  return VitaColors.dataRed
                            default:      return VitaColors.dataAmber
                            }
                        }()
                        QBankStatusChip(
                            label: label,
                            isSelected: vm.state.selectedDifficulties.contains(dc.difficulty),
                            color: color
                        ) {
                            vm.toggleDifficulty(dc.difficulty)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var yearRangeSection: some View {
        let years = vm.state.filters.years.sorted()
        let yearMin = years.first ?? 1995
        let yearMax = years.last ?? 2026

        if yearMin < yearMax {
            configGlassSection(title: "ANO") {
                VStack(alignment: .leading, spacing: 8) {
                    let hasFilter = !vm.state.selectedYears.isEmpty
                    let rangeStart = vm.state.selectedYears.min() ?? yearMin
                    let rangeEnd = vm.state.selectedYears.max() ?? yearMax

                    HStack {
                        Text(hasFilter ? "De \(rangeStart)" : "Todos os anos")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(hasFilter ? VitaColors.accentLight : VitaColors.textSecondary)
                        Spacer()
                        if hasFilter {
                            Text("Ate \(rangeEnd)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VitaColors.accentLight)
                        }
                    }

                    QBankYearRangeSlider(
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd,
                        yearMin: yearMin,
                        yearMax: yearMax,
                        onChange: { start, end in
                            vm.setYearRange(start: start, end: end)
                        }
                    )

                    HStack {
                        Text("\(yearMin)")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textTertiary)
                        Spacer()
                        Text("\(yearMax)")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Filter Picker Card (opens sheet)

    private func filterPickerCard(
        title: String,
        selectedCount: Int,
        totalCount: Int,
        selectedPreview: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VitaGlassCard(cornerRadius: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(VitaColors.sectionLabel)
                        if selectedCount > 0 {
                            Text(selectedPreview)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(VitaColors.accentLight)
                                .lineLimit(1)
                        } else {
                            Text("Todos (\(totalCount))")
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.textSecondary)
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        if selectedCount > 0 {
                            Text("\(selectedCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(VitaColors.accent)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
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
                // Count + themed CTA (matches Home "Nova Sessão" glass amber)
                HStack {
                    if vm.state.isLoadingCount {
                        ProgressView()
                            .tint(VitaColors.accent)
                            .scaleEffect(0.6)
                    } else {
                        Text("\(formatNumber(vm.state.displayAvailableCount)) disponíveis")
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                StudyShellCTA(
                    title: "Iniciar Sessão (\(vm.state.questionCount) questões)",
                    theme: .questoes,
                    action: { vm.createSession() },
                    systemImage: "play.fill"
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 80)
        .padding(.top, 8)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: VitaColors.surface.opacity(0.95), location: 0.3),
                    .init(color: VitaColors.surface, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Mode toggle (Prática vs Simulado)

    private var modeToggleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MODO")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)

            HStack(spacing: 0) {
                ForEach(QBankMode.allCases, id: \.self) { mode in
                    let isSelected = vm.state.mode == mode
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.setMode(mode) }
                    } label: {
                        VStack(spacing: 2) {
                            Text(mode.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                            Text(mode == .pratica ? "feedback a cada questão" : "igual prova, gabarito no final")
                                .font(.system(size: 9))
                                .foregroundStyle(isSelected ? VitaColors.accent.opacity(0.7) : VitaColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? VitaColors.accent.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? VitaColors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassCard(cornerRadius: 14)
        }
    }

    // MARK: - Quality filters (Rafael 2026-04-27)
    //
    // Por padrão app só mostra questões com gabarito substancial e oficiais.
    // Usuário pode relaxar pra incluir bancos sintéticos / sem comentário.

    private var qualitySection: some View {
        configGlassSection(title: "QUALIDADE") {
            VStack(spacing: 8) {
                QBankConfigToggleRow(
                    icon: "checkmark.seal.fill",
                    title: "Apenas com gabarito",
                    description: "Pula questões sem comentário detalhado",
                    isOn: vm.state.excludeNoExplanation,
                    action: { vm.setExcludeNoExplanation(!vm.state.excludeNoExplanation) }
                )
                .accessibilityLabel("Apenas com gabarito")
                .accessibilityHint("Quando ligado, só inclui questões que têm comentário detalhado")
                .accessibilityValue(vm.state.excludeNoExplanation ? "Ligado" : "Desligado")
                .accessibilityAddTraits(.isButton)

                QBankConfigToggleRow(
                    icon: "rosette",
                    title: "Apenas oficiais",
                    description: "Exclui questões geradas por IA",
                    isOn: vm.state.onlyOfficial,
                    action: { vm.setOnlyOfficial(!vm.state.onlyOfficial) }
                )
                .accessibilityLabel("Apenas oficiais")
                .accessibilityHint("Quando ligado, só inclui questões de provas reais — exclui sintéticas")
                .accessibilityValue(vm.state.onlyOfficial ? "Ligado" : "Desligado")
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    // MARK: - Topic expandable section (inline search + checkbox list)

    private var topicExpandableSection: some View {
        let topics = vm.state.filters.topics
        let selectedCount = vm.state.selectedTopicIds.count
        let totalCount = topics.count

        return VStack(alignment: .leading, spacing: 0) {
            // Header row — tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { vm.toggleThemeExpanded() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TEMA")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(VitaColors.sectionLabel)
                        if selectedCount > 0 {
                            Text("\(selectedCount) de \(totalCount) selecionados")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(VitaColors.accentLight)
                        } else {
                            Text("Todos (\(totalCount))")
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.textSecondary)
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        if selectedCount > 0 {
                            Text("\(selectedCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(VitaColors.accent)
                        }
                        Image(systemName: vm.state.themeExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded body
            if vm.state.themeExpanded {
                VStack(spacing: 10) {
                    // Search
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.textTertiary)
                        TextField(
                            "Buscar tema...",
                            text: Binding(
                                get: { vm.state.topicSearch },
                                set: { vm.setTopicSearch($0) }
                            )
                        )
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        if !vm.state.topicSearch.isEmpty {
                            Button { vm.setTopicSearch("") } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(VitaColors.surfaceElevated.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Quick actions
                    HStack(spacing: 8) {
                        Button { vm.selectAllTopics() } label: {
                            Text("Todos")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(VitaColors.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(VitaColors.accent.opacity(0.1))
                                .overlay(Capsule().stroke(VitaColors.accent.opacity(0.3), lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Button { vm.deselectAllTopics() } label: {
                            Text("Nenhum")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(VitaColors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(VitaColors.glassBg)
                                .overlay(Capsule().stroke(VitaColors.glassBorder, lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text("\(selectedCount)/\(totalCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(VitaColors.textTertiary)
                    }

                    // Checkbox list (capped height, scroll inside)
                    let filteredTopics = vm.state.filteredTopics
                    if filteredTopics.isEmpty {
                        Text(vm.state.topicSearch.isEmpty ? "Nenhum tema disponível" : "Nada encontrado para \"\(vm.state.topicSearch)\"")
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(filteredTopics) { topic in
                                    let isSelected = vm.state.selectedTopicIds.contains(topic.id)
                                    Button { vm.toggleTopic(topic.id) } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                                .font(.system(size: 16))
                                                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textTertiary.opacity(0.5))
                                            Text(topic.displayTitle)
                                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                                .foregroundStyle(isSelected ? VitaColors.accentLight : VitaColors.textPrimary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if topic.id != filteredTopics.last?.id {
                                        Rectangle()
                                            .fill(VitaColors.glassBorder.opacity(0.4))
                                            .frame(height: 1)
                                            .padding(.leading, 26)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 280)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
        .background(VitaColors.glassBg)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(vm.state.themeExpanded ? VitaColors.accent.opacity(0.2) : VitaColors.glassBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func configGlassSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(VitaColors.sectionLabel)
                content()
            }
            .padding(14)
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Status Chip (with custom color)

private struct QBankStatusChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? color : VitaColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? color.opacity(0.12) : VitaColors.glassBg)
                .overlay(
                    Capsule().stroke(
                        isSelected ? color.opacity(0.3) : VitaColors.glassBorder,
                        lineWidth: 1
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Year Range Slider (two-thumb approximation using two Sliders)

private struct QBankYearRangeSlider: View {
    let rangeStart: Int
    let rangeEnd: Int
    let yearMin: Int
    let yearMax: Int
    let onChange: (Int, Int) -> Void

    @State private var lowValue: Double = 0
    @State private var highValue: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            // Low bound slider
            HStack(spacing: 8) {
                Text("De")
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(width: 20)
                Slider(
                    value: $lowValue,
                    in: Double(yearMin)...Double(yearMax),
                    step: 1,
                    onEditingChanged: { editing in
                        if !editing {
                            let clamped = min(Int(lowValue), Int(highValue))
                            onChange(clamped, Int(highValue))
                        }
                    }
                )
                .tint(VitaColors.accent)
            }
            // High bound slider
            HStack(spacing: 8) {
                Text("Ate")
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(width: 20)
                Slider(
                    value: $highValue,
                    in: Double(yearMin)...Double(yearMax),
                    step: 1,
                    onEditingChanged: { editing in
                        if !editing {
                            let clamped = max(Int(lowValue), Int(highValue))
                            onChange(Int(lowValue), clamped)
                        }
                    }
                )
                .tint(VitaColors.accent)
            }
        }
        .onAppear {
            lowValue = Double(rangeStart)
            highValue = Double(rangeEnd)
        }
        .onChange(of: rangeStart) { _, new in lowValue = Double(new) }
        .onChange(of: rangeEnd) { _, new in highValue = Double(new) }
    }
}

// MARK: - Institution Bottom Sheet

private struct QBankInstitutionSheet: View {
    @Bindable var vm: QBankViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Instituicoes")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                if !vm.state.selectedInstitutionIds.isEmpty {
                    Button("Limpar") {
                        vm.state.selectedInstitutionIds = []
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VitaColors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(VitaColors.textTertiary)
                TextField("Buscar instituicao...", text: Binding(
                    get: { vm.state.institutionSearch },
                    set: { vm.setInstitutionSearch($0) }
                ))
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 10)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.state.filteredInstitutions) { inst in
                        let isSelected = vm.state.selectedInstitutionIds.contains(inst.id)
                        Button {
                            vm.toggleInstitution(inst.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 18))
                                    .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textTertiary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(inst.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(VitaColors.textPrimary)
                                        .lineLimit(1)
                                    if let state = inst.state, !state.isEmpty {
                                        Text(state)
                                            .font(.system(size: 11))
                                            .foregroundStyle(VitaColors.textTertiary)
                                    }
                                }
                                Spacer()
                                if inst.isResidence {
                                    QBankBadge(text: "Residência", color: VitaColors.accent)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if inst.id != vm.state.filteredInstitutions.last?.id {
                            Rectangle()
                                .fill(VitaColors.glassBorder)
                                .frame(height: 1)
                                .padding(.leading, 46)
                        }
                    }
                }
            }

            // Done button
            VitaButton(text: "Confirmar (\(vm.state.selectedInstitutionIds.count) selecionadas)") {
                dismiss()
            }
            .padding(16)
        }
        .background(VitaColors.surface)
    }
}

