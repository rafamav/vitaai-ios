import Foundation
import CarPlay
import UIKit

// MARK: - CloudCarTemplateBuilder
//
// Constructs the CarPlay template tree. CarPlay imposes a hard constraint:
// only Apple-approved templates (CPListTemplate, CPGridTemplate, CPVoice
// ControlTemplate, etc.) may render — no custom views. We keep the UI
// deliberately spartan: a status row, a "Falar com agente" button, and a
// recent-activity list. The driver should never need more than a glance.

@MainActor
final class CloudCarTemplateBuilder {

    private let controller: CloudCarController

    init(controller: CloudCarController) {
        self.controller = controller
    }

    // MARK: - Root list

    func makeRootTemplate() -> CPListTemplate {
        let statusItem = CPListItem(
            text: "Status",
            detailText: controller.linkState.label
        )
        statusItem.handler = { [weak self] _, completion in
            self?.controller.connect()
            completion()
        }

        let talkItem = CPListItem(
            text: talkButtonTitle(),
            detailText: talkButtonSubtitle()
        )
        talkItem.handler = { [weak self] _, completion in
            self?.handleTalkTap()
            completion()
        }

        let stopItem = CPListItem(
            text: "Interromper",
            detailText: "Para a resposta atual do agente"
        )
        stopItem.handler = { [weak self] _, completion in
            self?.controller.interrupt()
            completion()
        }

        let recentItem = CPListItem(
            text: "Últimas ações",
            detailText: latestTurnPreview()
        )
        recentItem.accessoryType = .disclosureIndicator
        recentItem.handler = { [weak self] _, completion in
            self?.pushRecentTemplate()
            completion()
        }

        let primarySection = CPListSection(
            items: [statusItem, talkItem, stopItem],
            header: "CloudCar",
            sectionIndexTitle: nil
        )
        let recentSection = CPListSection(
            items: [recentItem],
            header: "Histórico",
            sectionIndexTitle: nil
        )

        let template = CPListTemplate(
            title: "CloudCar",
            sections: [primarySection, recentSection]
        )
        return template
    }

    // MARK: - Talk button

    private func talkButtonTitle() -> String {
        switch controller.listening {
        case .listening: return "Parar de falar"
        case .thinking:  return "Aguardando resposta..."
        case .speaking:  return "Tocando resposta..."
        case .idle:      return "Falar com agente"
        }
    }

    private func talkButtonSubtitle() -> String {
        switch controller.listening {
        case .listening: return "Toque novamente para enviar"
        case .thinking:  return "O agente está pensando"
        case .speaking:  return "Toque para interromper"
        case .idle:      return "Mantenha o foco na direção"
        }
    }

    private func handleTalkTap() {
        switch controller.listening {
        case .speaking:
            controller.interrupt()
        case .listening, .idle, .thinking:
            controller.togglePushToTalk()
        }
    }

    // MARK: - Recent activity

    private func latestTurnPreview() -> String {
        guard let last = controller.transcript.last else {
            return "Nada por aqui ainda"
        }
        let prefix: String
        switch last.role {
        case .user:   prefix = "Você"
        case .agent:  prefix = "Agente"
        case .system: prefix = "Sistema"
        }
        return "\(prefix): \(last.text)"
    }

    private func pushRecentTemplate() {
        let items: [CPListItem] = controller.transcript.suffix(20).reversed().map { turn in
            let title: String
            switch turn.role {
            case .user:   title = "Você"
            case .agent:  title = "Agente"
            case .system: title = "Sistema"
            }
            return CPListItem(text: title, detailText: turn.text)
        }
        let section = CPListSection(items: items.isEmpty
            ? [CPListItem(text: "Nada por aqui ainda", detailText: nil)]
            : items)
        let template = CPListTemplate(title: "Últimas ações", sections: [section])
        // Find the live interface controller by walking the connected scenes.
        if let icc = activeInterfaceController() {
            icc.pushTemplate(template, animated: true, completion: nil)
        }
    }

    private func activeInterfaceController() -> CPInterfaceController? {
        for scene in UIApplication.shared.connectedScenes {
            guard let templateScene = scene as? CPTemplateApplicationScene else { continue }
            return templateScene.interfaceController
        }
        return nil
    }
}
