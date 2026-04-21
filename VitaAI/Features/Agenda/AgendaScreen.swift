import SwiftUI
import Sentry

// MARK: - AgendaScreen
//
// Tela própria de Agenda — antes o link "Agenda" do menu hambúrguer caía na
// tab Faculdade (rota fantasma). Agora navega aqui.
// Reaproveita MonthlyCalendarView (mesmo componente do widget MateriasAgenda).
// Sem background custom — shell ambient mostra através.

struct AgendaScreen: View {
    @Environment(\.appData) private var appData

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                MonthlyCalendarView(
                    schedule: appData.classSchedule,
                    evaluations: appData.academicEvaluations
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer().frame(height: 120)
            }
        }
        .background(Color.clear)
        .refreshable { await appData.forceRefresh() }
        .task { SentrySDK.reportFullyDisplayed() }
        .trackScreen("Agenda")
    }
}
