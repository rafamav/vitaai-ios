import SwiftUI

// MARK: - AgendaScreen

struct AgendaScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: AgendaViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                agendaContent(vm: vm)
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
            }
        }
        .vitaScreenBg()
        .onAppear {
            if viewModel == nil {
                viewModel = AgendaViewModel(api: container.api)
                Task { await viewModel?.load() }
            }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func agendaContent(vm: AgendaViewModel) -> some View {
        Group {
            if vm.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(VitaColors.accent)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        weekDaySelector(vm: vm)
                        dayHeader(vm: vm)
                        timelineSection(vm: vm)
                        aiPlanButton(vm: vm)
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 8)
                }
                .refreshable { await vm.load() }
            }
        }
        .sheet(isPresented: Binding(
            get: { vm.showCreateModal },
            set: { vm.showCreateModal = $0 }
        )) {
            createModal(vm: vm)
        }
    }

    // MARK: - Week day selector

    @ViewBuilder
    private func weekDaySelector(vm: AgendaViewModel) -> some View {
        let abbrs = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
        let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1

        // Build date numbers for this week
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let weekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today

        HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { i in
                let isSelected = vm.selectedDayIndex == i
                let isToday = i == todayIndex
                let dayDate = calendar.date(byAdding: .day, value: i, to: weekStart) ?? weekStart
                let dayNum = String(calendar.component(.day, from: dayDate))

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.selectedDayIndex = i
                    }
                } label: {
                    VStack(spacing: 3) {
                        Text(abbrs[i])
                            .font(VitaTypography.labelSmall)
                        Text(dayNum)
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        isSelected
                            ? Color.white
                            : (isToday ? VitaColors.accent.opacity(0.08) : VitaColors.glassBg)
                    )
                    .foregroundStyle(
                        isSelected
                            ? VitaColors.surface
                            : (isToday ? VitaColors.accent : VitaColors.textSecondary)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isToday && !isSelected
                                    ? VitaColors.accent.opacity(0.3)
                                    : VitaColors.glassBorder,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Day header

    @ViewBuilder
    private func dayHeader(vm: AgendaViewModel) -> some View {
        let fullNames = [
            "Domingo", "Segunda-feira", "Terça-feira",
            "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"
        ]
        let dayName = fullNames[vm.selectedDayIndex]
        let summary = vm.selectedDaySummary

        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayName)
                    .font(VitaTypography.titleLarge)
                    .foregroundStyle(VitaColors.textPrimary)

                if !summary.isEmpty {
                    Text(summary)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }

            Spacer()

            Button {
                vm.showCreateModal = true
            } label: {
                ZStack {
                    Circle()
                        .fill(VitaColors.accent)
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.surface)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Timeline section

    @ViewBuilder
    private func timelineSection(vm: AgendaViewModel) -> some View {
        let studyItems = vm.selectedDayStudyItems
        let classes = vm.selectedDayClasses
        let events = vm.selectedDayEvents

        let hasContent = !studyItems.isEmpty || !classes.isEmpty || !events.isEmpty

        if !hasContent {
            emptyDayState()
        } else {
            // Interleave all items sorted by time key
            let allRows = buildTimeline(studyItems: studyItems, classes: classes, events: events)

            VStack(spacing: 8) {
                ForEach(allRows) { row in
                    switch row.kind {
                    case .study(let item):
                        studyItemRow(item: item, vm: vm)
                    case .classBlock(let cls):
                        classRow(cls: cls)
                    case .event(let event):
                        eventRow(event: event)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func emptyDayState() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(VitaColors.textTertiary)

            Text("Nenhuma atividade programada")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textSecondary)

            Text("Toque em + para adicionar uma atividade de estudo")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
    }

    // MARK: - Study item row

    @ViewBuilder
    private func studyItemRow(item: LocalStudyItem, vm: AgendaViewModel) -> some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                Text(item.time)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, alignment: .leading)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(VitaColors.surfaceElevated)
                        .frame(width: 34, height: 34)
                    Image(systemName: item.completed ? "checkmark.circle.fill" : iconFor(item.title))
                        .font(.system(size: 14))
                        .foregroundStyle(item.completed ? Color.green : VitaColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .strikethrough(item.completed, color: VitaColors.textTertiary)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(item.durationLabel)
                            .font(VitaTypography.labelSmall)
                        if let subject = item.subject {
                            Text("·")
                                .font(VitaTypography.labelSmall)
                            Text(subject)
                                .font(VitaTypography.labelSmall)
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer()

                // Completion toggle hint
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(item.completed ? Color.green.opacity(0.8) : VitaColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .opacity(item.completed ? 0.6 : 1.0)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                vm.toggleItem(item)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Class row

    @ViewBuilder
    private func classRow(cls: ClassScheduleItem) -> some View {
        HStack(spacing: 0) {
            // Left accent border
            Rectangle()
                .fill(Color.blue.opacity(0.7))
                .frame(width: 3)

            HStack(spacing: 12) {
                Text(cls.startTime)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.blue.opacity(0.8))
                    .frame(width: 36, alignment: .leading)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.08))
                        .frame(width: 34, height: 34)
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.blue.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(cls.subjectName ?? "")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)

                    let detail = ["\(cls.startTime) - \(cls.endTime)", cls.room]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                    Text(detail)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.blue.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Event row

    @ViewBuilder
    private func eventRow(event: StudyEventEntry) -> some View {
        let startTime = extractTime(from: event.startAt)
        let isExam = event.eventType.uppercased() == "EXAM"
        let accentColor = isExam ? Color.orange : VitaColors.accent

        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor.opacity(0.7))
                .frame(width: 3)

            HStack(spacing: 12) {
                Text(startTime)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(accentColor.opacity(0.8))
                    .frame(width: 36, alignment: .leading)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.08))
                        .frame(width: 34, height: 34)
                    Image(systemName: isExam ? "pencil.and.list.clipboard" : "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)

                    if let course = event.courseName {
                        Text(course)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(accentColor.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - AI Plan button

    @ViewBuilder
    private func aiPlanButton(vm: AgendaViewModel) -> some View {
        Button {
            // Phase 2: open AI plan generation flow
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(VitaColors.accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Gerar Plano com IA")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("Deixa a VitaAI montar sua semana de estudos")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [
                        VitaColors.accent.opacity(0.08),
                        VitaColors.glassBg
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(VitaColors.accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Create modal

    @ViewBuilder
    private func createModal(vm: AgendaViewModel) -> some View {
        VStack(spacing: 0) {
            // Handle indicator
            Capsule()
                .fill(VitaColors.textTertiary)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Header
            HStack {
                Text("Nova Atividade")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                Button("Cancelar") {
                    vm.showCreateModal = false
                }
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Fields
            VStack(spacing: 12) {
                GlassTextField(
                    placeholder: "Título *",
                    text: Binding(
                        get: { vm.newTitle },
                        set: { vm.newTitle = $0 }
                    ),
                    icon: "pencil"
                )

                GlassTextField(
                    placeholder: "Matéria (opcional)",
                    text: Binding(
                        get: { vm.newSubject },
                        set: { vm.newSubject = $0 }
                    ),
                    icon: "book"
                )

                GlassTextField(
                    placeholder: "Horário (09:00)",
                    text: Binding(
                        get: { vm.newTime },
                        set: { vm.newTime = $0 }
                    ),
                    icon: "clock"
                )
                .keyboardType(.numbersAndPunctuation)

                // Duration stepper
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duração")
                            .font(VitaTypography.labelMedium)
                            .foregroundStyle(VitaColors.textSecondary)
                        Text(durationLabel(vm.newDuration))
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.accent)
                    }

                    Spacer()

                    Stepper(
                        "",
                        value: Binding(
                            get: { vm.newDuration },
                            set: { vm.newDuration = $0 }
                        ),
                        in: 5...480,
                        step: 15
                    )
                    .labelsHidden()
                    .tint(VitaColors.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(VitaColors.glassBg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            // Save button
            Button(action: { vm.createItem() }) {
                Text("Salvar")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.surface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        vm.newTitle.isEmpty
                            ? VitaColors.accent.opacity(0.35)
                            : VitaColors.accent
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(vm.newTitle.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(VitaColors.surfaceElevated.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden) // We draw our own handle above
    }

    // MARK: - Helpers

    private func iconFor(_ title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("flashcard") || lower.contains("revis") { return "brain.fill" }
        if lower.contains("simulado") || lower.contains("quest") { return "checkmark.rectangle.fill" }
        if lower.contains("pdf") || lower.contains("leitura") { return "doc.text.fill" }
        if lower.contains("video") || lower.contains("aula") { return "play.circle.fill" }
        if lower.contains("exerc") || lower.contains("lista") { return "list.bullet.clipboard.fill" }
        return "book.fill"
    }

    private static let iso8601Parser = ISO8601DateFormatter()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone.current
        return f
    }()

    private func extractTime(from isoString: String) -> String {
        guard let date = Self.iso8601Parser.date(from: isoString) else { return "--:--" }
        return Self.timeFormatter.string(from: date)
    }

    private func durationLabel(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)min" : "\(h)h"
        }
        return "\(minutes) min"
    }

    // MARK: - Timeline builder

    private func buildTimeline(
        studyItems: [LocalStudyItem],
        classes: [ClassScheduleItem],
        events: [StudyEventEntry]
    ) -> [TimelineRow] {
        var rows: [TimelineRow] = []

        for item in studyItems {
            rows.append(TimelineRow(sortKey: item.time, kind: .study(item)))
        }
        for cls in classes {
            rows.append(TimelineRow(sortKey: cls.startTime, kind: .classBlock(cls)))
        }
        for event in events {
            let time = extractTime(from: event.startAt)
            rows.append(TimelineRow(sortKey: time, kind: .event(event)))
        }

        return rows.sorted { $0.sortKey < $1.sortKey }
    }
}

// MARK: - Timeline row model

private struct TimelineRow: Identifiable {
    let id = UUID()
    let sortKey: String
    let kind: TimelineRowKind
}

private enum TimelineRowKind {
    case study(LocalStudyItem)
    case classBlock(ClassScheduleItem)
    case event(StudyEventEntry)
}
