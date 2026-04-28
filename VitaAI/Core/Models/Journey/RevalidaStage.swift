import Foundation

/// Etapa do REVALIDA-INEP capturada no onboarding (Slice 1 Onda 5b, Rafael 2026-04-27).
///
/// Standalone porque é usado direto pelo OnboardingViewModel/RevalidaStageStep antes
/// de virar payload (vira `currentStage` no `OnboardingV2Request` e em `JourneyConfig.CurrentStage`).
///
/// - PRIMEIRA: prova teórica (90 questões objetivas + redação + 5 discursivas).
/// - SEGUNDA: habilidades clínicas (estações OSCE).
enum RevalidaStage: String, Codable, CaseIterable {
    case primeira = "PRIMEIRA"
    case segunda = "SEGUNDA"
}
