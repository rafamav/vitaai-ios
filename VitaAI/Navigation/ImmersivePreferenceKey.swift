import SwiftUI

/// Lets a descendant screen (e.g. PdfViewerScreen in fullscreen mode) ask the
/// AppRouter shell to hide the chrome (top bar, breadcrumb, tab bar, safe-area inset).
///
/// Descendant publishes via `.preference(key: ImmersivePreferenceKey.self, value: true)`.
/// AppRouter listens via `.onPreferenceChange(ImmersivePreferenceKey.self)` and
/// toggles `isImmersiveMode`, which gates the chrome in its body.
///
/// `reduce` ORs all descendants — any screen in the tree asking for immersive wins.
struct ImmersivePreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
