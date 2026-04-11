import SwiftUI

// MARK: - OnboardingStep Enum

enum OnboardingStep: Int, CaseIterable {
    case sleep = 0
    case welcome = 1
    case connect = 2
    case syncing = 3
    case subjects = 4
    case notifications = 5
    case trial = 6
    case done = 7
}

// MARK: - Speech Bubble

struct OnboardingSpeechBubble: View {
    let text: String
    var isTyping: Bool = false

    var body: some View {
        HStack(alignment: .bottom) {
            (Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.90))
            + Text(isTyping ? "\u{258D}" : "")
                .font(.system(size: 14))
                .foregroundColor(VitaColors.accent.opacity(0.7)))
            .lineSpacing(6)

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [VitaColors.accent.opacity(0.12), VitaColors.accent.opacity(0.04)],
                        startPoint: UnitPoint(x: 0.15, y: 0.15),
                        endPoint: UnitPoint(x: 0.85, y: 0.85)
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(VitaColors.accent.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: VitaColors.accent.opacity(0.10), radius: 20, x: 0, y: 0)
                .shadow(color: .black.opacity(0.20), radius: 16, x: 0, y: 8)
        )
    }
}

// MARK: - Progress Dots

struct OnboardingProgressDots: View {
    var currentStep: Int
    var totalDots: Int = 5

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalDots, id: \.self) { i in
                Circle()
                    .fill(i <= currentStep ? VitaColors.accent.opacity(0.7) : Color.white.opacity(0.08))
                    .frame(width: 8, height: 8)
                    .shadow(color: i <= currentStep ? VitaColors.accent.opacity(0.3) : .clear, radius: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }
}

// MARK: - Starfield (enhanced with nebula)

struct OnboardingStarfieldLayer: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Nebula glow (subtle teal/gold)
            RadialGradient(
                colors: [
                    Color(red: 0.15, green: 0.85, blue: 0.75).opacity(0.03),
                    VitaColors.accent.opacity(0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.3, y: 0.3),
                startRadius: 50,
                endRadius: 400
            )

            // Stars
            Canvas { context, size in
                for i in 0..<50 {
                    let x = CGFloat((i * 31 + 11) % 100) / 100.0 * size.width
                    let y = CGFloat((i * 23 + 7) % 100) / 100.0 * size.height
                    let r = CGFloat(1 + (i * 7) % 3) * (i % 5 == 0 ? 0.8 : 0.4)
                    let opacity = 0.15 + (i % 4 == 0 ? 0.15 : 0.0)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(VitaColors.accent.opacity(opacity))
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - ENAMED Badge (reusable)

struct ENAMEDBadge: View {
    let score: Int

    private var badgeColor: Color {
        score >= 4 ? VitaColors.dataGreen : score >= 3 ? VitaColors.accent : .white.opacity(0.4)
    }

    var body: some View {
        HStack(spacing: 2) {
            Text("ENAMED")
                .font(.system(size: 7, weight: .bold))
            Text("\(score)")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.08))
        )
    }
}
