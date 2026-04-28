import Foundation

// MARK: - JourneyType helpers (Onda 4 ATLAS, Rafael 2026-04-27)
//
// Source of truth do enum: `VitaAI/Generated/Models/JourneyType.swift`
// (gerado pelo openapi-generator a partir de `openapi.yaml`).
//
// Estes helpers (displayName + icon) ficam separados pra:
//   1. Não conflitar com o codegen (que sobrescreve o enum a cada sync).
//   2. Manter literais de UI versionados em Swift, próximos do app.

extension JourneyType {
    /// Texto curto pra exibir em headers/cards (sem locale por enquanto — i18n
    /// futuro usa Localizable se houver demanda).
    var displayName: String {
        switch self {
        case .faculdade: return "Faculdade"
        case .internato: return "Internato"
        case .enamed: return "ENAMED"
        case .residencia: return "Residência"
        case .revalida: return "Revalida"
        }
    }

    /// SF Symbol pra ilustrar a jornada nos empty states + chips.
    var icon: String {
        switch self {
        case .faculdade: return "graduationcap"
        case .internato: return "stethoscope"
        case .enamed: return "doc.text.fill"
        case .residencia: return "cross.case"
        case .revalida: return "globe.americas"
        }
    }
}

// MARK: - ContentOrganizationMode helpers (3 lentes — Onda 4)

extension ContentOrganizationMode {
    var displayName: String {
        switch self {
        case .tradicional: return "Tradicional"
        case .pbl: return "PBL"
        case .greatAreas: return "CNRM/Enare"
        }
    }

    var icon: String {
        switch self {
        case .tradicional: return "books.vertical"
        case .pbl: return "circle.hexagongrid"
        case .greatAreas: return "target"
        }
    }
}
