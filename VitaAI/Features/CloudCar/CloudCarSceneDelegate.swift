import Foundation
import CarPlay
import Combine

// MARK: - CloudCarSceneDelegate
//
// Bridges UIKit's CarPlay scene lifecycle into the CloudCar controller. iOS
// instantiates this class when the user plugs into a CarPlay-enabled head
// unit. We immediately stand up the root template and start the controller
// (which auto-connects to the agent gateway when configured to).
//
// IMPORTANT: CarPlay entitlements (`com.apple.developer.carplay-communication`
// or similar) require special approval from Apple. Without the entitlement,
// the scene will be created in development builds tied to the CarPlay
// Simulator, but production CarPlay activation will be blocked at runtime.

final class CloudCarSceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var rootBuilder: CloudCarTemplateBuilder?
    private var cancellables: Set<AnyCancellable> = []

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        Task { @MainActor in
            let controller = CloudCarController.shared
            controller.start()

            let builder = CloudCarTemplateBuilder(controller: controller)
            self.rootBuilder = builder

            let root = builder.makeRootTemplate()
            interfaceController.setRootTemplate(root, animated: false, completion: nil)

            // Refresh the root template when controller state changes so the
            // status row + voice button reflect the live link state.
            controller.$linkState
                .combineLatest(controller.$listening)
                .receive(on: RunLoop.main)
                .sink { [weak self] _, _ in
                    self?.refreshRoot()
                }
                .store(in: &self.cancellables)
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.rootBuilder = nil
        cancellables.removeAll()
        // Keep the WebSocket alive for a moment in case CarPlay reconnects
        // (common when switching head units / restarting the car). The
        // controller itself decides whether to actually drop the link.
    }

    @MainActor
    private func refreshRoot() {
        guard let interfaceController, let rootBuilder else { return }
        let updated = rootBuilder.makeRootTemplate()
        interfaceController.setRootTemplate(updated, animated: false, completion: nil)
    }
}
