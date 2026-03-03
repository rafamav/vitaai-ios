import Foundation

// MARK: - FSRS-5 Card States

/// Mirrors Android `CardStatus` enum.
enum FsrsCardStatus: Int, Codable {
    case new        = 0
    case learning   = 1
    case review     = 2
    case relearning = 3
}

// MARK: - FSRS-5 Card State

/// Immutable snapshot of a card's FSRS-5 scheduling state.
/// Mirrors Android `CardState` data class.
struct FsrsCardState: Equatable {
    var stability: Double       = 0.0
    var difficulty: Double      = 0.0
    var elapsedDays: Int        = 0
    var scheduledDays: Int      = 0
    var reps: Int               = 0
    var lapses: Int             = 0
    var status: FsrsCardStatus  = .new
    var lastReviewDate: Date?

    // MARK: - Backward-compatible migration from SM-2 fields
    //
    // When a card was stored with SM-2 fields (easeFactor / interval),
    // map them into FSRS-5 state so existing card data is not lost.
    //
    // easeFactor → stability  (SM-2 EF is a reasonable proxy for FSRS S)
    // interval   → scheduledDays (identical semantics)
    // repetitions > 0 → .review state
    static func migratedFromSM2(
        easeFactor: Double,
        repetitions: Int,
        interval: Int,
        lastReviewDate: Date? = nil
    ) -> FsrsCardState {
        let status: FsrsCardStatus = repetitions > 0 ? .review : .new
        // Clamp EF into a plausible FSRS stability range (0.1 – 100 days)
        let stability = max(0.1, min(easeFactor, 100.0))
        return FsrsCardState(
            stability: stability,
            difficulty: 5.0,         // neutral difficulty (midpoint of 1–10)
            elapsedDays: 0,
            scheduledDays: interval,
            reps: repetitions,
            lapses: 0,
            status: status,
            lastReviewDate: lastReviewDate
        )
    }
}

// MARK: - Schedule Result

/// Output of a single scheduling decision.
/// Mirrors Android `ScheduleResult`.
struct FsrsScheduleResult {
    let card: FsrsCardState
    let intervalDays: Int
}

// MARK: - Schedule Preview

/// Predicted intervals for all four rating buttons shown to the user.
/// Mirrors Android `SchedulePreview`.
struct FsrsSchedulePreview {
    let again: Int
    let hard:  Int
    let good:  Int
    let easy:  Int

    func interval(for rating: ReviewRating) -> Int {
        switch rating {
        case .again: return again
        case .hard:  return hard
        case .good:  return good
        case .easy:  return easy
        }
    }
}

// MARK: - FSRS Parameters

/// FSRS-5 weight vector and hyperparameters.
/// Default values mirror Android `FsrsParameters` (open-spaced-repetition v5 defaults).
struct FsrsParameters {
    /// w[0..3]  — initial stability per rating (Again, Hard, Good, Easy)
    /// w[4..6]  — difficulty initialisation and mean-reversion
    /// w[7..10] — stability after successful recall
    /// w[11..14]— stability after lapse (forgetting)
    /// w[15]    — hard penalty
    /// w[16]    — easy bonus
    /// w[17]    — short-term stability exponent
    let w: [Double]
    let requestedRetention: Double
    let maximumInterval: Int

    init(
        w: [Double] = [
            0.4072, 1.1829, 3.1262, 15.4722,  // w[0..3]
            7.2102, 0.5316, 1.0651,             // w[4..6]
            0.0589, 1.5330, 0.1059, 1.0027,    // w[7..10]
            2.0316, 0.0169, 0.3536,             // w[11..13]
            0.3261,                             // w[14]
            0.2783,                             // w[15] hard penalty
            2.8982,                             // w[16] easy bonus
            0.5281,                             // w[17] short-term stability
        ],
        requestedRetention: Double = 0.9,
        maximumInterval: Int = 36500
    ) {
        precondition(w.count >= 18, "FSRS-5 requires at least 18 weights")
        self.w = w
        self.requestedRetention = requestedRetention
        self.maximumInterval = maximumInterval
    }
}

// MARK: - FsrsScheduler

/// FSRS-5 spaced-repetition scheduler — pure functions, no side effects.
///
/// Reference: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
/// Mirrors Android `FsrsScheduler` class 1:1.
struct FsrsScheduler {

    // MARK: Constants (mirrors Android companion object)
    static let decay:  Double = -0.5
    static let factor: Double = 19.0 / 81.0   // ≈ 0.2346

    private static let minDifficulty: Double = 1.0
    private static let maxDifficulty: Double = 10.0

    let params: FsrsParameters

    init(params: FsrsParameters = FsrsParameters()) {
        self.params = params
    }

    // MARK: - Public API

    /// Schedule a card after a review with the given rating.
    /// `now` defaults to the current date.
    func schedule(
        card: FsrsCardState,
        rating: ReviewRating,
        now: Date = Date()
    ) -> FsrsScheduleResult {
        let elapsedDays: Int
        if let last = card.lastReviewDate {
            let rawDays = now.timeIntervalSince(last) / 86_400
            elapsedDays = max(0, Int(rawDays.rounded()))
        } else {
            elapsedDays = 0
        }

        var current = card
        current.elapsedDays = elapsedDays

        switch current.status {
        case .new:
            return scheduleNew(card: current, rating: rating, now: now)
        case .learning, .relearning:
            return scheduleLearning(card: current, rating: rating, now: now)
        case .review:
            return scheduleReview(card: current, rating: rating, now: now)
        }
    }

    /// Preview intervals for all four ratings without mutating state.
    func preview(card: FsrsCardState, now: Date = Date()) -> FsrsSchedulePreview {
        FsrsSchedulePreview(
            again: schedule(card: card, rating: .again, now: now).intervalDays,
            hard:  schedule(card: card, rating: .hard,  now: now).intervalDays,
            good:  schedule(card: card, rating: .good,  now: now).intervalDays,
            easy:  schedule(card: card, rating: .easy,  now: now).intervalDays
        )
    }

    // MARK: - New Cards

    private func scheduleNew(card: FsrsCardState, rating: ReviewRating, now: Date) -> FsrsScheduleResult {
        let s = initStability(rating: rating)
        let d = initDifficulty(rating: rating)
        let interval = nextInterval(stability: s)

        let nextStatus: FsrsCardStatus
        let scheduledDays: Int

        switch rating {
        case .again, .hard:
            nextStatus    = .learning
            scheduledDays = 0
        case .good, .easy:
            nextStatus    = .review
            scheduledDays = interval
        }

        var newCard = card
        newCard.stability     = s
        newCard.difficulty    = d
        newCard.scheduledDays = scheduledDays
        newCard.reps          = card.reps + 1
        newCard.status        = nextStatus
        newCard.lastReviewDate = now

        return FsrsScheduleResult(card: newCard, intervalDays: scheduledDays)
    }

    // MARK: - Learning / Relearning

    private func scheduleLearning(card: FsrsCardState, rating: ReviewRating, now: Date) -> FsrsScheduleResult {
        let d = nextDifficulty(d: card.difficulty, rating: rating)
        let s = shortTermStability(s: card.stability, rating: rating)
        let interval = nextInterval(stability: s)

        let nextStatus: FsrsCardStatus
        let scheduledDays: Int

        switch rating {
        case .again, .hard:
            nextStatus    = .learning
            scheduledDays = 0
        case .good, .easy:
            nextStatus    = .review
            scheduledDays = interval
        }

        var newCard = card
        newCard.stability      = s
        newCard.difficulty     = d
        newCard.scheduledDays  = scheduledDays
        newCard.reps           = card.reps + 1
        newCard.status         = nextStatus
        newCard.lastReviewDate = now

        return FsrsScheduleResult(card: newCard, intervalDays: scheduledDays)
    }

    // MARK: - Review Cards

    private func scheduleReview(card: FsrsCardState, rating: ReviewRating, now: Date) -> FsrsScheduleResult {
        let elapsed = card.elapsedDays
        let r = retrievability(elapsedDays: elapsed, stability: card.stability)
        let d = nextDifficulty(d: card.difficulty, rating: rating)

        if rating == .again {
            // Lapse: card forgotten
            let s = nextForgetStability(d: card.difficulty, s: card.stability, r: r)

            var newCard = card
            newCard.stability      = s
            newCard.difficulty     = d
            newCard.scheduledDays  = 0
            newCard.reps           = card.reps + 1
            newCard.lapses         = card.lapses + 1
            newCard.status         = .relearning
            newCard.lastReviewDate = now

            return FsrsScheduleResult(card: newCard, intervalDays: 0)
        } else {
            // Successful recall
            let hardPenalty: Double = rating == .hard ? params.w[15] : 1.0
            let easyBonus:   Double = rating == .easy ? params.w[16] : 1.0
            let s = nextRecallStability(d: card.difficulty, s: card.stability, r: r,
                                        hardPenalty: hardPenalty, easyBonus: easyBonus)
            let interval = nextInterval(stability: s)

            var newCard = card
            newCard.stability      = s
            newCard.difficulty     = d
            newCard.scheduledDays  = interval
            newCard.reps           = card.reps + 1
            newCard.status         = .review
            newCard.lastReviewDate = now

            return FsrsScheduleResult(card: newCard, intervalDays: interval)
        }
    }

    // MARK: - FSRS-5 Formulas (mirrors Android 1:1)

    /// S0(G) — initial stability for rating G.
    func initStability(rating: ReviewRating) -> Double {
        max(0.1, params.w[rating.rawValue - 1])
    }

    /// D0(G) — initial difficulty for rating G.
    func initDifficulty(rating: ReviewRating) -> Double {
        let d = params.w[4] - exp(params.w[5] * Double(rating.rawValue - 1)) + 1
        return clampDifficulty(d)
    }

    /// D'(D, G) — next difficulty after a review.
    func nextDifficulty(d: Double, rating: ReviewRating) -> Double {
        let d0 = initDifficulty(rating: .good)
        let delta = d - params.w[6] * Double(rating.rawValue - 3)
        let nextD = params.w[7] * d0 + (1 - params.w[7]) * delta
        return clampDifficulty(nextD)
    }

    /// S'r — stability after a successful recall.
    func nextRecallStability(d: Double, s: Double, r: Double,
                             hardPenalty: Double = 1.0,
                             easyBonus: Double = 1.0) -> Double {
        let factor = exp(params.w[8])
            * (11 - d)
            * pow(s, -params.w[9])
            * (exp(params.w[10] * (1 - r)) - 1)
            * hardPenalty
            * easyBonus
            + 1
        return max(0.1, s * factor)
    }

    /// S'f — stability after forgetting (lapse).
    func nextForgetStability(d: Double, s: Double, r: Double) -> Double {
        let sf = params.w[11]
            * pow(d, -params.w[12])
            * (pow(s + 1, params.w[13]) - 1)
            * exp(params.w[14] * (1 - r))
        return max(0.1, min(sf, s))
    }

    /// Short-term stability for learning/relearning steps.
    func shortTermStability(s: Double, rating: ReviewRating) -> Double {
        max(0.1, s * exp(params.w[17] * Double(rating.rawValue - 3)))
    }

    /// R(t, S) — retrievability at time t (days) with stability S.
    func retrievability(elapsedDays: Int, stability: Double) -> Double {
        guard stability > 0 else { return 0.0 }
        return pow(1 + Self.factor * Double(elapsedDays) / stability, Self.decay)
    }

    /// I(S) — next interval in days for the current stability and desired retention.
    func nextInterval(stability: Double) -> Int {
        let r = params.requestedRetention
        let rawInterval = stability / Self.factor * (pow(r, 1.0 / Self.decay) - 1)
        let clamped = max(1, min(Int(rawInterval.rounded()), params.maximumInterval))
        return clamped
    }

    // MARK: - Helpers

    private func clampDifficulty(_ d: Double) -> Double {
        min(max(d, Self.minDifficulty), Self.maxDifficulty)
    }
}

// MARK: - Interval Formatting

extension FsrsScheduler {
    /// Format an interval (days) to a human-readable label.
    /// Matches SM2Scheduler.formatInterval for UI consistency.
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
