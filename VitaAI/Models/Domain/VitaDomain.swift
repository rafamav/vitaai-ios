import Foundation

// MARK: - VitaDomain
// Source-of-truth namespace for gamification domain data.
// Badge definitions mirror server gamification.ts — keep in sync.

enum VitaDomain {

    // MARK: - Badge Definition (lightweight, no earned state)

    struct BadgeDef: Identifiable {
        let id: String
        let name: String
        let description: String
        let icon: String       // Material icon name (mapped to SF Symbol at usage site)
        let category: String   // "streak" | "cards" | "milestone" | "study" | "social"
    }

    // MARK: - Daily Study Goal

    struct DailyStudyGoal: Identifiable {
        let id: String
        let label: String
        let hours: Double
    }

    // MARK: - All Badges

    static let allBadges: [BadgeDef] = [
        // Streak
        BadgeDef(id: "streak_3",   name: "3 Dias Seguidos",   description: "Mantenha uma sequência de 3 dias",          icon: "local_fire_department", category: "streak"),
        BadgeDef(id: "streak_7",   name: "Semana Perfeita",   description: "Mantenha uma sequência de 7 dias",          icon: "local_fire_department", category: "streak"),
        BadgeDef(id: "streak_30",  name: "Mês de Fogo",       description: "Mantenha uma sequência de 30 dias",         icon: "whatshot",              category: "streak"),
        BadgeDef(id: "streak_100", name: "Centurião",         description: "Mantenha uma sequência de 100 dias",        icon: "military_tech",         category: "streak"),

        // Cards
        BadgeDef(id: "first_review", name: "Primeira Revisão", description: "Revise seu primeiro flashcard",            icon: "style",                 category: "cards"),
        BadgeDef(id: "cards_50",     name: "50 Cards",         description: "Revise 50 flashcards",                     icon: "style",                 category: "cards"),
        BadgeDef(id: "cards_500",    name: "500 Cards",        description: "Revise 500 flashcards",                    icon: "school",                category: "cards"),
        BadgeDef(id: "cards_2000",   name: "Mestre dos Cards", description: "Revise 2000 flashcards",                   icon: "auto_awesome",          category: "cards"),

        // Milestone
        BadgeDef(id: "level_5",    name: "Nível 5",           description: "Alcance o nível 5",                        icon: "emoji_events",          category: "milestone"),
        BadgeDef(id: "level_10",   name: "Nível 10",          description: "Alcance o nível 10",                       icon: "emoji_events",          category: "milestone"),
        BadgeDef(id: "level_25",   name: "Nível 25",          description: "Alcance o nível 25",                       icon: "workspace_premium",     category: "milestone"),
        BadgeDef(id: "xp_10000",   name: "10k XP",            description: "Acumule 10.000 pontos de experiência",     icon: "trending_up",           category: "milestone"),

        // Study
        BadgeDef(id: "first_note",     name: "Primeira Nota",     description: "Crie sua primeira anotação",           icon: "edit_note",             category: "study"),
        BadgeDef(id: "night_owl",      name: "Coruja Noturna",    description: "Estude depois das 23h",                icon: "dark_mode",             category: "study"),
        BadgeDef(id: "early_bird",     name: "Madrugador",        description: "Estude antes das 6h",                  icon: "wb_sunny",              category: "study"),
        BadgeDef(id: "simulado_first", name: "Primeiro Simulado", description: "Complete seu primeiro simulado",        icon: "menu_book",             category: "study"),

        // Social
        BadgeDef(id: "first_chat",  name: "Primeiro Chat",   description: "Envie sua primeira mensagem no chat IA",    icon: "chat",                  category: "social"),
        BadgeDef(id: "chat_100",    name: "Conversador",     description: "Envie 100 mensagens no chat IA",            icon: "chat",                  category: "social"),
        BadgeDef(id: "osce_first",  name: "Primeiro OSCE",   description: "Complete sua primeira estação OSCE",         icon: "sports_esports",        category: "social"),
    ]

    // MARK: - Badge XP Rewards

    static let badgeXp: [String: Int] = [
        "streak_3":       25,
        "streak_7":       50,
        "streak_30":     150,
        "streak_100":    500,
        "first_review":   10,
        "cards_50":       30,
        "cards_500":     100,
        "cards_2000":    300,
        "level_5":        50,
        "level_10":      100,
        "level_25":      250,
        "xp_10000":      200,
        "first_note":     10,
        "night_owl":      15,
        "early_bird":     15,
        "simulado_first": 30,
        "first_chat":     10,
        "chat_100":       50,
        "osce_first":     25,
    ]

    // MARK: - Daily Study Goals

    static let dailyStudyGoals: [DailyStudyGoal] = [
        DailyStudyGoal(id: "light",    label: "Leve",     hours: 1),
        DailyStudyGoal(id: "moderate", label: "Moderado", hours: 3),
        DailyStudyGoal(id: "intense",  label: "Intenso",  hours: 5),
        DailyStudyGoal(id: "extreme",  label: "Extremo",  hours: 8),
    ]
}
