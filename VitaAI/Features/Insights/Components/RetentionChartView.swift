import SwiftUI
import Charts

/// Line + area chart showing the Ebbinghaus forgetting curve for the user's flashcard retention.
/// Uses Swift Charts (iOS 16+). Data points at 0, 1, 7, 14, 30, 60, 90 days.
struct RetentionChartView: View {
    let points: [RetentionPoint]

    private let xValues: [Int] = [0, 1, 7, 14, 30, 60, 90]

    private func xLabel(for day: Int) -> String {
        switch day {
        case 0:  return "0"
        case 1:  return "1d"
        case 7:  return "7d"
        case 14: return "14d"
        case 30: return "30d"
        case 60: return "60d"
        case 90: return "90d"
        default: return "\(day)d"
        }
    }

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Curva de Retenção")
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)
                    Spacer()
                    Text("SM-2")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Chart(points) { point in
                    AreaMark(
                        x: .value("Dia", point.day),
                        yStart: .value("Base", 0),
                        yEnd: .value("Retenção", point.retention)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                VitaColors.accent.opacity(0.30),
                                VitaColors.accent.opacity(0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Dia", point.day),
                        y: .value("Retenção", point.retention)
                    )
                    .foregroundStyle(VitaColors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Dia", point.day),
                        y: .value("Retenção", point.retention)
                    )
                    .foregroundStyle(VitaColors.accent)
                    .symbolSize(18)
                }
                .chartXScale(domain: 0...90)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: xValues) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VitaColors.surfaceBorder)
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(xLabel(for: v))
                                    .font(.system(size: 8))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VitaColors.surfaceBorder)
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)%")
                                    .font(.system(size: 8))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 120)

                Text("Revise antes de esquecer para manter alta retenção.")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(14)
        }
    }
}
