import SwiftUI

/// Top-level coordinator that owns the single QBankViewModel instance and routes
/// between the home / config / session / result sub-screens based on vm.state.activeScreen.
/// This is the entry point registered in Route + AppRouter.
///
/// Sub-screens live in separate files:
///   - QBankHomeContent.swift       (home + background + hero + cards)
///   - QBankDisciplineContent.swift  (discipline tree selection)
///   - QBankConfigContent.swift      (session config: filters, difficulty, institutions)
///   - QBankSessionContent.swift     (active question + alternatives + timer)
///   - QBankResultContent.swift      (score ring + stats + review)
///   - QBankExplanationSheet.swift   (answer explanation + statistics)
///   - QBankShared.swift             (Badge, HTMLText, Chip, FlowLayout, helpers)
struct QBankCoordinatorScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: QBankViewModel?
    let onBack: () -> Void

    var body: some View {
        Group {
            if let vm {
                coordinator(vm: vm)
            } else {
                ProgressView().tint(VitaColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .vitaScreenBg()
            }
        }
        .onAppear {
            if vm == nil {
                vm = QBankViewModel(api: container.api)
                vm?.loadHomeData()
                // Filters are loaded on-demand when user navigates to disciplines/config
            }
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func coordinator(vm: QBankViewModel) -> some View {
        switch vm.state.activeScreen {
        case .home:
            QBankHomeContent(vm: vm, onBack: onBack)

        case .disciplines:
            QBankDisciplineContent(vm: vm, onBack: {
                vm.goBackDiscipline()
            })

        case .config:
            QBankConfigContent(vm: vm, onBack: {
                vm.state.activeScreen = .disciplines
            })

        case .session:
            QBankSessionContent(vm: vm, onBack: {
                vm.goToHome()
            })

        case .result:
            QBankResultContent(vm: vm, onBack: onBack, onNewSession: {
                vm.startNewSession()
            })
        }
    }
}
