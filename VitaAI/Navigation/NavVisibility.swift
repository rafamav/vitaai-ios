import SwiftUI

/// Observable state que controla visibilidade da VitaTopBar e do breadcrumb
/// em auto-hide estilo Safari/Twitter:
///
/// - Scroll pra baixo (conteúdo descendo, dedo subindo) → esconde
/// - Scroll pra cima (conteúdo subindo, dedo descendo) → mostra
/// - Troca de tab/tela → sempre volta a mostrar
///
/// Uso: injetar uma instância no shell (`AppRouter`) via `.environment(\.navVisibility, ...)`,
/// consumir no `VitaTopBar` com `.offset(y:)` + `.opacity()`, e aplicar o modifier
/// `.trackedScroll()` em cada `ScrollView` das telas principais.
@MainActor
@Observable
final class NavVisibility {
    var isVisible: Bool = true

    /// Threshold em pontos — quanto scroll acumulado pra trigger hide/show.
    /// Pequeno demais = flicker ao rolar devagar. Grande demais = UX "dura".
    /// 40pt ≈ altura de meio card.
    private let threshold: CGFloat = 40

    private var lastOffset: CGFloat = 0
    private var accumulated: CGFloat = 0

    /// Chamado pelo modifier `.trackedScroll()`.
    /// `offset` = valor positivo crescente conforme o usuário rola pra baixo
    /// (conteúdo sai pra cima). Convencionado com sinal flipado do `minY`.
    func update(offset: CGFloat) {
        let delta = offset - lastOffset
        lastOffset = offset

        // Ignora micro-deltas (inércia residual, bounce)
        guard abs(delta) > 0.5 else { return }

        // Inverteu direção? zera acumulador
        if (delta > 0) != (accumulated > 0) {
            accumulated = 0
        }
        accumulated += delta

        if accumulated > threshold, isVisible {
            withAnimation(.easeOut(duration: 0.25)) { isVisible = false }
        } else if accumulated < -threshold, !isVisible {
            withAnimation(.easeOut(duration: 0.25)) { isVisible = true }
        }

        // Sempre mostra quando está no topo
        if offset <= 0, !isVisible {
            withAnimation(.easeOut(duration: 0.25)) { isVisible = true }
        }
    }

    /// Resetar ao trocar de tab ou abrir tela nova.
    func reset() {
        lastOffset = 0
        accumulated = 0
        if !isVisible {
            withAnimation(.easeOut(duration: 0.25)) { isVisible = true }
        }
    }
}

// MARK: - Environment key

private struct NavVisibilityKey: EnvironmentKey {
    @MainActor static let defaultValue: NavVisibility = NavVisibility()
}

extension EnvironmentValues {
    var navVisibility: NavVisibility {
        get { self[NavVisibilityKey.self] }
        set { self[NavVisibilityKey.self] = newValue }
    }
}

// MARK: - Scroll offset tracking

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Coordinate space nomeada — cada ScrollView que quer auto-hide deve usar
/// `.coordinateSpace(name: NavVisibility.scrollSpace)` ou o modifier
/// `.trackedScroll()` que faz isso automaticamente.
extension NavVisibility {
    static let scrollSpace = "vitaTrackedScroll"
}

/// Modifier pra aplicar numa `ScrollView`. Registra o coordinate space,
/// mede o offset via GeometryReader + PreferenceKey, e empurra pro `NavVisibility`.
///
/// ```swift
/// ScrollView { ... }
///     .trackedScroll()
/// ```
struct TrackedScrollModifier: ViewModifier {
    @Environment(\.navVisibility) private var nav

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -geo.frame(in: .named(NavVisibility.scrollSpace)).minY
                    )
                }
            )
            .coordinateSpace(name: NavVisibility.scrollSpace)
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                Task { @MainActor in
                    nav.update(offset: offset)
                }
            }
    }
}

extension View {
    /// Auto-hide da TopBar/Breadcrumb ao scrollar. Aplica em cada `ScrollView`
    /// das telas principais. Ver `NavVisibility`.
    func trackedScroll() -> some View {
        modifier(TrackedScrollModifier())
    }
}
