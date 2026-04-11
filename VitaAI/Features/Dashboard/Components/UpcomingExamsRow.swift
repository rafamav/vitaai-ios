import SwiftUI

struct UpcomingExamsRow: View {
    let exams: [UpcomingExam]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(exams) { exam in
                    VitaGlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exam.subject)
                                .font(VitaTypography.bodyMedium)
                                .fontWeight(.medium)
                                .foregroundStyle(VitaColors.textPrimary)
                                .lineLimit(1)

                            Text(exam.type)
                                .font(VitaTypography.bodySmall)
                                .foregroundStyle(VitaColors.textTertiary)

                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text("em \(exam.daysUntil) dias")
                                    .font(VitaTypography.labelSmall)
                            }
                            .foregroundStyle(exam.daysUntil <= 3 ? VitaColors.dataAmber : VitaColors.accent)
                        }
                        .padding(14)
                    }
                    .frame(width: 160)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
