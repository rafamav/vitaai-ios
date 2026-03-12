import Foundation
import SwiftUI

enum MockData {
    static func dashboardProgress() -> DashboardProgress {
        DashboardProgress(
            progressPercent: 0.68,
            streak: 5,
            flashcardsDue: 23,
            accuracy: 0.82,
            studyMinutes: 145
        )
    }

    static func upcomingExams() -> [UpcomingExam] {
        let today = Date()
        let cal = Calendar.current
        return [
            UpcomingExam(id: "e1", subject: "Anatomia Humana II", type: "P2", date: cal.date(byAdding: .day, value: 2, to: today)!, daysUntil: 2),
            UpcomingExam(id: "e2", subject: "Bioquímica Clínica", type: "Prova Final", date: cal.date(byAdding: .day, value: 5, to: today)!, daysUntil: 5),
            UpcomingExam(id: "e3", subject: "Fisiologia Médica", type: "Simulado", date: cal.date(byAdding: .day, value: 8, to: today)!, daysUntil: 8),
            UpcomingExam(id: "e4", subject: "Farmacologia I", type: "P1", date: cal.date(byAdding: .day, value: 12, to: today)!, daysUntil: 12),
        ]
    }

    static func weekDays() -> [WeekDay] {
        let today = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: today)
        let monday = cal.date(byAdding: .day, value: -(weekday - 2), to: today)!

        let events: [[String]] = [
            ["Anatomia 8h", "Lab Bioquímica 14h"],
            ["Fisiologia 10h"],
            ["Farmacologia 8h", "Seminário 16h"],
            ["Patologia 10h", "Monitoria 14h"],
            ["Semiologia 8h"],
            [],
            [],
        ]

        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: monday)!
            return WeekDay(
                date: date,
                label: date.shortWeekday,
                events: events[offset],
                isToday: cal.isDateInToday(date)
            )
        }
    }

    static func studyModules() -> [StudyModule] {
        [
            StudyModule(name: "Questoes",   icon: "doc.text.fill",         count: 120, color: VitaColors.accent),
            StudyModule(name: "Flashcards", icon: "rectangle.stack.fill",  count: 23,  color: VitaColors.accent),
            StudyModule(name: "Simulados",  icon: "list.bullet.clipboard", count: 5,   color: VitaColors.accent),
            StudyModule(name: "Atlas 3D",   icon: "staroflife.fill",       count: 0,   color: VitaColors.accent),
        ]
    }

    static func vitaSuggestions() -> [VitaSuggestion] {
        [
            VitaSuggestion(label: "Plano de estudo", prompt: "Crie um plano de estudo para minhas provas das próximas 2 semanas"),
            VitaSuggestion(label: "Revisar flashcards", prompt: "Me ajude a revisar os flashcards pendentes de Anatomia"),
            VitaSuggestion(label: "Resumo do dia", prompt: "Faça um resumo do que preciso estudar hoje"),
            VitaSuggestion(label: "Dicas de estudo", prompt: "Quais técnicas de estudo são mais eficazes para memorização?"),
        ]
    }

    static func todayAgendaEvents() -> [AgendaEvent] {
        [
            AgendaEvent(title: NSLocalizedString("Medicina Legal, Deontologia e Etica", comment: ""), time: "09:00", colorTag: .green),
            AgendaEvent(title: NSLocalizedString("Praticas Interprofissionais", comment: ""), time: "14:00", colorTag: .blue),
        ]
    }

    static func miniPlayer() -> MiniPlayerData {
        MiniPlayerData(subject: "Anatomia", tool: "Flashcards", completed: 34, total: 50)
    }

    static func weakSubjects() -> [WeakSubject] {
        [
            WeakSubject(name: "Bioquimica",   score: 0.64),
            WeakSubject(name: "Farmacologia", score: 0.68),
            WeakSubject(name: "Histologia",   score: 0.71),
        ]
    }

    static func studyTip() -> String {
        let tips = [
            "Técnica Pomodoro: 25min de foco, 5min de pausa. Após 4 ciclos, 15min de pausa longa.",
            "Revise os flashcards antes de dormir — o sono consolida memórias recém-formadas.",
            "Ensine o conteúdo a alguém (ou finja). Explicar ativa a retrieval practice.",
            "Intercale disciplinas diferentes no mesmo bloco de estudo para fortalecer conexões.",
            "Antes da prova, faça simulados em vez de reler. Testar > reler.",
        ]
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return tips[dayIndex % tips.count]
    }

    // MARK: - Gamification

    static func userProgress() -> UserProgress {
        let now = Date()
        return UserProgress(
            totalXp: 1_250,
            level: 5,
            currentLevelXp: 400,
            xpToNextLevel: 450,
            currentStreak: 7,
            longestStreak: 14,
            streakFreezes: 1,
            badges: badges(),
            totalCardsReviewed: 245,
            totalChatMessages: 18,
            totalNotesCreated: 6,
            dailyXp: 35,
            dailyGoal: 50,
            dailyLoginClaimed: true
        )
    }

    static func badges() -> [VitaBadge] {
        let now = Date()
        let cal = Calendar.current
        return [
            VitaBadge(id: "first_review",  name: "Primeira Revisão",   description: "Complete sua primeira sessão de flashcards.",    icon: "rectangle.stack.fill",  earnedAt: cal.date(byAdding: .day, value: -10, to: now), category: .cards),
            VitaBadge(id: "streak_3",      name: "3 Dias Seguidos",    description: "Mantenha uma sequência de 3 dias.",              icon: "flame.fill",            earnedAt: cal.date(byAdding: .day, value: -4, to: now),  category: .streak),
            VitaBadge(id: "streak_7",      name: "Semana Perfeita",    description: "Mantenha uma sequência de 7 dias.",              icon: "flame.fill",            earnedAt: now,                                           category: .streak),
            VitaBadge(id: "streak_30",     name: "Mês Dedicado",       description: "Mantenha uma sequência de 30 dias.",             icon: "flame.fill",            earnedAt: nil,                                           category: .streak),
            VitaBadge(id: "cards_100",     name: "Centurião",          description: "Revise 100 flashcards.",                        icon: "100.circle.fill",       earnedAt: cal.date(byAdding: .day, value: -2, to: now),  category: .cards),
            VitaBadge(id: "cards_500",     name: "Mestre dos Cards",   description: "Revise 500 flashcards.",                        icon: "star.circle.fill",      earnedAt: nil,                                           category: .cards),
            VitaBadge(id: "cards_1000",    name: "Lenda",              description: "Revise 1000 flashcards.",                       icon: "trophy.fill",           earnedAt: nil,                                           category: .cards),
            VitaBadge(id: "level_5",       name: "Estudante Dedicado", description: "Alcance o nível 5.",                            icon: "graduationcap.fill",    earnedAt: now,                                           category: .milestone),
            VitaBadge(id: "level_10",      name: "Residente",          description: "Alcance o nível 10.",                           icon: "cross.case.fill",       earnedAt: nil,                                           category: .milestone),
            VitaBadge(id: "first_note",    name: "Anotador",           description: "Crie sua primeira nota.",                       icon: "note.text",             earnedAt: cal.date(byAdding: .day, value: -6, to: now),  category: .study),
            VitaBadge(id: "first_chat",    name: "Curioso",            description: "Envie sua primeira mensagem para Vita.",        icon: "bubble.left.fill",      earnedAt: cal.date(byAdding: .day, value: -8, to: now),  category: .social),
            VitaBadge(id: "night_owl",     name: "Coruja",             description: "Estude após as 22h.",                           icon: "moon.fill",             earnedAt: nil,                                           category: .study),
            VitaBadge(id: "early_bird",    name: "Madrugador",         description: "Estude antes das 7h.",                          icon: "sunrise.fill",          earnedAt: nil,                                           category: .study),
        ]
    }
}
