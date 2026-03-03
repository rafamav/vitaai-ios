import SwiftUI

// MARK: - Rating option descriptor

private struct RatingOption {
    let rating: ReviewRating
    let label: String
    let icon: String              // SF Symbol name
    let color: Color
    let bgColor: Color
    let borderColor: Color
    var intervalLabel: String = ""
}

// MARK: - RatingButtonsView

/// Four rating buttons (Again / Hard / Good / Easy) matching Android / web design.
/// Each button shows a color-coded label, icon, and the SM-2 interval preview.
struct RatingButtonsView: View {

    let intervalPreviews: [ReviewRating: Int]
    var onRate: (ReviewRating) -> Void

    // Data colors — match Android RatingButtons.kt and web globals.css
    private let colorAgain = Color(hex: 0xF87171)   // --data-red   dark
    private let colorHard  = Color(hex: 0xFBBF24)   // --data-amber dark
    private let colorGood  = Color(hex: 0x4ADE80)   // --data-green dark
    private let colorEasy  = Color(hex: 0x60A5FA)   // --data-blue  dark

    private func options() -> [RatingOption] {
        let fmt = FsrsScheduler.formatInterval

        return [
            RatingOption(
                rating: .again,
                label: ReviewRating.again.label,
                icon: "arrow.counterclockwise",
                color: colorAgain,
                bgColor: colorAgain.opacity(0.08),
                borderColor: colorAgain.opacity(0.18),
                intervalLabel: fmt(intervalPreviews[.again] ?? 0)
            ),
            RatingOption(
                rating: .hard,
                label: ReviewRating.hard.label,
                icon: "chevron.down",
                color: colorHard,
                bgColor: colorHard.opacity(0.08),
                borderColor: colorHard.opacity(0.18),
                intervalLabel: fmt(intervalPreviews[.hard] ?? 1)
            ),
            RatingOption(
                rating: .good,
                label: ReviewRating.good.label,
                icon: "checkmark",
                color: colorGood,
                bgColor: colorGood.opacity(0.08),
                borderColor: colorGood.opacity(0.18),
                intervalLabel: fmt(intervalPreviews[.good] ?? 3)
            ),
            RatingOption(
                rating: .easy,
                label: ReviewRating.easy.label,
                icon: "bolt.fill",
                color: colorEasy,
                bgColor: colorEasy.opacity(0.08),
                borderColor: colorEasy.opacity(0.18),
                intervalLabel: fmt(intervalPreviews[.easy] ?? 7)
            ),
        ]
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options(), id: \.rating) { option in
                RatingButton(option: option) {
                    onRate(option.rating)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: intervalPreviews.count)
    }
}

// MARK: - Single Rating Button

private struct RatingButton: View {

    let option: RatingOption
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            triggerHaptic()
            onTap()
        }) {
            VStack(spacing: 2) {
                Image(systemName: option.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(option.color)

                Text(option.label)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(option.color)

                if !option.intervalLabel.isEmpty {
                    Text(option.intervalLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(option.color.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .background(option.bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(option.borderColor, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PressButtonStyle(isPressed: $isPressed))
        .accessibilityLabel("\(option.label), \(option.intervalLabel)")
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Custom Button Style for press tracking

private struct PressButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}
