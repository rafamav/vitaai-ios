import Foundation

// MARK: - Flashcard Domain Models

/// A flashcard deck containing multiple cards
struct FlashcardDeck: Identifiable, Hashable {
    let id: String
    let title: String
    var cards: [FlashcardCard]
    var dueCount: Int { cards.filter { $0.isDue }.count }
}

/// A single flashcard with front/back content and FSRS-5 scheduling state.
/// Backward-compatible with SM-2 legacy fields from the API layer:
///   stability  ← easeFactor (SM-2) or stability (FSRS-5)
///   difficulty ← FSRS-5 difficulty 1–10 (0 = unmigrated legacy card)
///   state      ← FsrsCardStatus raw value (0=New,1=Learning,2=Review,3=Relearning)
struct FlashcardCard: Identifiable, Hashable {
    let id: String
    let front: String
    let back: String

    // FSRS-5 spaced repetition state
    var stability: Double = 2.5      // FSRS S (or SM-2 EF for legacy cards)
    var difficulty: Double = 0.0     // FSRS D 1–10 (0 = legacy card, will be migrated)
    var state: Int = 0               // FsrsCardStatus raw value
    var scheduledDays: Int = 0
    var nextReviewAt: Date?

    var isDue: Bool {
        guard let next = nextReviewAt else { return true }
        return next <= Date()
    }
}

/// Rating choices for spaced repetition (maps to FSRS/Anki standard)
enum ReviewRating: Int, CaseIterable {
    case again = 1   // Failed, show again soon
    case hard  = 2   // Difficult but recalled
    case good  = 3   // Recalled with effort
    case easy  = 4   // Recalled instantly

    var label: String {
        switch self {
        case .again: return "Erro"
        case .hard:  return "Difícil"
        case .good:  return "Bom"
        case .easy:  return "Fácil"
        }
    }

    var isCorrect: Bool { self.rawValue >= 3 }
}

/// Result of a completed review session
struct FlashcardSessionResult {
    let totalCards: Int
    let correctCount: Int
    let timeSpentMs: Int64
    let streakCount: Int

    var accuracy: Int {
        guard totalCards > 0 else { return 0 }
        return Int((Double(correctCount) / Double(totalCards)) * 100)
    }

    var isPerfect: Bool { accuracy == 100 && totalCards > 0 }

    var timeSpentSeconds: Int { Int(timeSpentMs / 1000) }

    func formattedDuration() -> String {
        let secs = timeSpentSeconds
        let m = secs / 60
        let s = secs % 60
        if m == 0 { return "\(s)s" }
        return "\(m)m \(String(format: "%02d", s))s"
    }
}

// MARK: - SM-2 Algorithm (LEGACY — kept for reference only)
//
// The active scheduler is now FsrsScheduler (FSRS-5), defined in FsrsScheduler.swift.
// SM2Scheduler is retained so existing code that calls it doesn't break during the
// transition. New code MUST use FsrsScheduler instead.

/// Legacy SM-2 scheduler — do NOT use for new flashcard sessions.
/// Use FsrsScheduler (FSRS-5) instead.
@available(*, deprecated, renamed: "FsrsScheduler")
enum SM2Scheduler {

    struct Output {
        let nextIntervalDays: Int
        let newEaseFactor: Double
    }

    /// Compute next review interval.
    /// - Parameters:
    ///   - rating: ReviewRating (1-4)
    ///   - easeFactor: current EF (minimum 1.3, default 2.5)
    ///   - repetitions: how many consecutive correct reviews
    ///   - currentInterval: days since last review (0 for new cards)
    static func compute(
        rating: ReviewRating,
        easeFactor: Double,
        repetitions: Int,
        currentInterval: Int
    ) -> Output {
        let ef = max(1.3, easeFactor)

        switch rating {
        case .again:
            // Reset to start of learning
            return Output(nextIntervalDays: 0, newEaseFactor: max(1.3, ef - 0.20))

        case .hard:
            // Short boost, reduce EF slightly
            let interval = max(1, Int(Double(currentInterval) * 1.2))
            return Output(nextIntervalDays: interval, newEaseFactor: max(1.3, ef - 0.15))

        case .good:
            let interval: Int
            if repetitions == 0 {
                interval = 1
            } else if repetitions == 1 {
                interval = 3
            } else {
                interval = max(1, Int(Double(currentInterval) * ef))
            }
            return Output(nextIntervalDays: interval, newEaseFactor: ef)

        case .easy:
            let interval: Int
            if repetitions == 0 {
                interval = 4
            } else {
                interval = max(1, Int(Double(currentInterval) * ef * 1.3))
            }
            return Output(nextIntervalDays: interval, newEaseFactor: min(2.5 + 0.10, ef + 0.10))
        }
    }

    /// Compute next intervals for all four ratings given current card state.
    /// Used to display interval previews on rating buttons.
    static func previewIntervals(easeFactor: Double, repetitions: Int, currentInterval: Int) -> [ReviewRating: Int] {
        var result: [ReviewRating: Int] = [:]
        for rating in ReviewRating.allCases {
            result[rating] = compute(
                rating: rating,
                easeFactor: easeFactor,
                repetitions: repetitions,
                currentInterval: currentInterval
            ).nextIntervalDays
        }
        return result
    }

    /// Format an interval (days) to a human-readable label.
    static func formatInterval(_ days: Int) -> String {
        switch days {
        case ..<1:    return "<10m"
        case 1:       return "1d"
        case 2...29:  return "\(days)d"
        case 30...364:
            let months = days / 30
            return "\(months)mo"
        default:
            let years = days / 365
            return "\(years)a"
        }
    }
}

// MARK: - API Request/Response (thin Codable wrappers for VitaAPI)

struct FlashcardReviewRequest: Codable {
    let rating: Int
    let responseTimeMs: Int64?
}

// MARK: - Domain mapping from API layer

extension FlashcardEntry {
    /// Maps the Codable API model to the domain model used by session logic.
    func toDomain() -> FlashcardCard {
        FlashcardCard(
            id: id,
            front: front.isEmpty ? "Frente não disponível" : front,
            back:  back.isEmpty  ? "Resposta não disponível" : back,
            stability:    easeFactor,
            difficulty:   0.0,
            state:        repetitions > 0 ? 2 : 0,
            scheduledDays: interval,
            nextReviewAt:  nextReviewAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        )
    }
}

// MARK: - Mock data for development / offline fallback

extension FlashcardDeck {
    static func mockDeck(id: String) -> FlashcardDeck {
        let topic: String
        switch true {
        case id.contains("_0"): topic = "Revisão Geral"
        case id.contains("_1"): topic = "Conceitos-Chave"
        default:                 topic = "Prática"
        }

        let cards = FlashcardCard.mockCardBank.shuffled().prefix(8).map { $0 }
        return FlashcardDeck(id: id, title: topic, cards: cards)
    }
}

extension FlashcardCard {
    static let mockCardBank: [FlashcardCard] = [
        FlashcardCard(id: "m1",
            front: "Qual nervo inerva o diafragma?",
            back: "Nervo frênico (C3-C5)"),
        FlashcardCard(id: "m2",
            front: "Qual a função do ciclo de Krebs?",
            back: "Oxidar acetil-CoA, gerando NADH, FADH₂ e GTP para a cadeia respiratória"),
        FlashcardCard(id: "m3",
            front: "O que é a Lei de Frank-Starling?",
            back: "Quanto maior o volume diastólico final, maior a força de contração ventricular"),
        FlashcardCard(id: "m4",
            front: "Quais são os sinais de Virchow?",
            back: "Tríade: estase venosa, lesão endotelial e hipercoagulabilidade"),
        FlashcardCard(id: "m5",
            front: "Qual a diferença entre apoptose e necrose?",
            back: "Apoptose: morte programada, sem inflamação. Necrose: morte patológica com inflamação"),
        FlashcardCard(id: "m6",
            front: "O que é o potencial de ação cardíaco fase 2 (platô)?",
            back: "Entrada lenta de Ca²⁺ pelos canais tipo L, equilibrada pela saída de K⁺"),
        FlashcardCard(id: "m7",
            front: "Qual antibiótico inibe a síntese de parede celular?",
            back: "Beta-lactâmicos (penicilinas, cefalosporinas) — inibem transpeptidases (PBPs)"),
        FlashcardCard(id: "m8",
            front: "O que é o clearance renal?",
            back: "Volume de plasma completamente depurado de uma substância por unidade de tempo (mL/min)"),
        FlashcardCard(id: "m9",
            front: "Quais os músculos da coifa dos rotadores?",
            back: "Supraespinhal, infraespinhal, redondo menor e subescapular (SITS)"),
        FlashcardCard(id: "m10",
            front: "O que caracteriza a síndrome nefrótica?",
            back: "Proteinúria >3,5g/dia, hipoalbuminemia, edema, hiperlipidemia e lipidúria"),
        FlashcardCard(id: "m11",
            front: "Qual a via de administração com maior biodisponibilidade?",
            back: "Intravenosa (100% de biodisponibilidade — sem efeito de primeira passagem)"),
        FlashcardCard(id: "m12",
            front: "O que é o reflexo de Cushing?",
            back: "Hipertensão + bradicardia + respiração irregular — sinal de aumento da PIC"),
    ]
}
