import SwiftUI
import UIKit

// Re-enables the native iOS swipe-back gesture inside NavigationStack pages
// that use `.toolbar(.hidden, for: .navigationBar)` or similar.
//
// Why this is necessary:
// In iOS 17+ (NavigationStack on UIKit underneath), hiding the nav bar
// disables the system `interactivePopGestureRecognizer`. Just setting
// `delegate = nil` works on iOS 16 but NOT on iOS 17+ — the system
// re-installs its own delegate that asks for a back button to enable
// the gesture. We install our own delegate that always returns true
// when there's something to pop.
//
// Setup is global: a single `.enableSwipeBack()` on the NavigationStack
// in AppRouter wires every pushed screen.

final class AlwaysAllowPopDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only allow when there's a screen to pop back to.
        (navigationController?.viewControllers.count ?? 0) > 1
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // Don't conflict with PDFKit pan, SceneKit camera control, scroll, etc.
        // The edge-pan recognizer fires only on the leading edge; other gestures
        // operate in the content area, so simultaneous recognition is safe.
        true
    }
}

struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> AlwaysAllowPopDelegate { AlwaysAllowPopDelegate() }

    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackHostController(delegate: context.coordinator)
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {
        (vc as? SwipeBackHostController)?.refresh()
    }
}

private final class SwipeBackHostController: UIViewController {
    private let popDelegate: AlwaysAllowPopDelegate

    init(delegate: AlwaysAllowPopDelegate) {
        self.popDelegate = delegate
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        wireUp()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        wireUp()
    }

    func refresh() { wireUp() }

    private func wireUp() {
        guard let nav = navigationController else { return }
        popDelegate.navigationController = nav
        nav.interactivePopGestureRecognizer?.isEnabled = true
        nav.interactivePopGestureRecognizer?.delegate = popDelegate
    }
}

extension View {
    /// Re-enables the system swipe-back gesture for every screen in the
    /// containing NavigationStack — even when the nav bar is hidden.
    /// Apply once on the NavigationStack root (or on the page itself).
    func enableSwipeBack() -> some View {
        background(SwipeBackGestureEnabler().frame(width: 0, height: 0))
    }
}
