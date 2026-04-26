import Foundation

// MARK: - Route breadcrumb labels
//
// Defines the human-readable label each Route shows in the global breadcrumb
// bar (VitaBreadcrumb). Returns nil for routes that should NOT appear in the
// breadcrumb:
//   - Root tabs (they're represented by TabItem, not a pushed route)
//   - Auth flows (login, onboarding) — rendered outside the shell
//   - Modal-like screens (settings, paywall, portalConnect, vitaChat)
//   - Legacy aliases (redirect to portalConnect internally)
//
// Dynamic routes with a name parameter (e.g. disciplineDetail) use the
// passed-in name instead of a generic label, so the breadcrumb reads
// "Home > Estudos > Farmacologia" instead of "Home > Estudos > Disciplina".

extension Route {
    var breadcrumbLabel: String? {
        switch self {
        // MARK: - Faculdade
        case .faculdadeDisciplinas: return "Disciplinas"
        case .faculdadeMaterias:    return "Matérias"
        case .faculdadeDocumentos:  return "Documentos"
        case .faculdadeProfessores: return "Professores"
        case .materialFolderDetail(_, let folderName, _): return folderName
        case .provas:              return "Provas"
        case .trabalhos:           return "Trabalhos"
        case .trabalhoDetail:      return "Trabalho"

        // MARK: - Estudos
        case .flashcardHome:       return "Flashcards"
        case .flashcardTopics(_, let title): return title
        case .flashcardSession:    return "Sessão"
        case .flashcardSettings:   return "Configurações"
        case .flashcardStats:      return "Estatísticas"
        case .qbank:               return "Questões"
        case .simuladoHome:        return "Simulados"
        case .simuladoConfig:      return "Configurar"
        case .simuladoSession:     return "Sessão"
        case .simuladoResult:      return "Resultado"
        case .simuladoReview:      return "Revisão"
        case .simuladoDiagnostics: return "Diagnóstico"
        case .transcricao:         return "Transcrição"
        case .mindMapList:         return "Mind Maps"
        case .mindMapEditor:       return "Mapa"
        case .notebookList:        return "Notebooks"
        case .notebookEditor:      return "Nota"
        case .osce:                return "OSCE"
        case .atlas3D:             return "Atlas 3D"
        case .courseDetail:        return "Curso"
        case .disciplineDetail(_, let name): return name
        case .pdfViewer:           return "PDF"

        // MARK: - Progresso
        case .profile:             return "Perfil"
        case .achievements:        return "Conquistas"
        case .insights:            return "Insights"
        case .activityFeed:        return "Atividade"
        case .leaderboard:         return "Ranking"
        case .planner:             return "Planner"

        // MARK: - Páginas reais acessadas via menu popout
        case .paywall:             return "Assinatura"
        case .about:               return "Sobre"
        case .appearance:          return "Aparência"
        case .notifications:       return "Notificações"
        case .connections:         return "Conexões"
        case .configuracoes:       return "Configurações"
        case .disciplinasConfig:   return "Disciplinas"
        case .privacyDocuments:    return "Privacidade de documentos"
        case .exportData:          return "Exportar meus dados"

        // MARK: - Fora do breadcrumb
        // Root tabs (represented by TabItem, not path)
        case .home, .estudos, .faculdade, .progresso, .agenda:
            return nil
        // Auth flows (outside shell)
        case .login, .onboarding:
            return nil
        // True modals/overlays (sheets, não push)
        case .vitaChat, .portalConnect, .toolManager:
            return nil
        // Legacy aliases (all redirect to portalConnect)
        case .canvasConnect, .webalunoConnect, .googleCalendarConnect, .googleDriveConnect:
            return nil
        }
    }
}
