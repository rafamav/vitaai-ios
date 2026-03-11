import SwiftUI

struct WeekAgendaSection: View {
    let days: [WeekDay]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days) { day in
                    VStack(spacing: 6) {
                        Text(day.label)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(day.isToday ? VitaColors.accent : VitaColors.textTertiary)

                        Text("\(day.date.dayOfMonth)")
                            .font(VitaTypography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundStyle(day.isToday ? VitaColors.white : VitaColors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(day.isToday ? VitaColors.accent.opacity(0.2) : .clear)
                            .clipShape(Circle())

                        VStack(spacing: 2) {
                            ForEach(day.events.prefix(2), id: \.self) { event in
                                Text(event)
                                    .font(.system(size: 9))
                                    .foregroundStyle(VitaColors.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(height: 24)
                    }
                    .frame(width: 70)
                    .padding(.vertical, 12)
                    .glassCard(cornerRadius: 12)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
