import SwiftUI
import Sentry

// MARK: - AppearanceScreen
// Matches aparência-mobile-v1.html mockup.
// Sections: Preview, Theme (Sistema/Escuro/Claro), Color Accent, Font Size Slider.

struct AppearanceScreen: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("vita_color_scheme") private var storedScheme: String = "dark"
    @AppStorage("vita_accent_color") private var storedAccent: String = "gold"
    @AppStorage("vita_font_size") private var fontSizeValue: Double = 0.5

    // Gold mockup colors
    private let goldText = VitaColors.accentLight
    private let subtleText = VitaColors.textWarm

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: - Header (custom, matches mockup topnav)
                headerBar
                    .padding(.top, 8)

                // MARK: - Preview Frame
                previewFrame
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                // MARK: - Theme Selector
                sectionLabel("Tema")
                    .padding(.top, 20)
                themeSelector
                    .padding(.horizontal, 14)

                // MARK: - Color Accent
                sectionLabel("Cor de destaque")
                    .padding(.top, 22)
                colorAccentSelector
                    .padding(.horizontal, 14)

                // MARK: - Font Size
                sectionLabel("Tamanho da fonte")
                    .padding(.top, 22)
                fontSizeSection
                    .padding(.horizontal, 14)

                Spacer().frame(height: 120)
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .trackScreen("Appearance")
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(subtleText.opacity(0.75))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("Aparência")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                Text("Personalize a interface")
                    .font(.system(size: 11))
                    .foregroundStyle(subtleText.opacity(0.40))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    // MARK: - Preview Frame

    private var previewFrame: some View {
        VitaGlassCard {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 180, height: 8)
                    Spacer().frame(height: 4)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                        .frame(height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(subtleText.opacity(0.04), lineWidth: 1)
                        )
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                        .frame(height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(subtleText.opacity(0.04), lineWidth: 1)
                        )
                    Spacer().frame(height: 4)
                    // Accent bar
                    RoundedRectangle(cornerRadius: 999)
                        .fill(
                            LinearGradient(
                                colors: [accentColorForPreview.opacity(0.50), accentColorForPreview.opacity(0.30)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 120, height: 8)
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 220, height: 8)
                }
                .padding(14)

                Text("Dark Mode - Ativo")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(subtleText.opacity(0.25))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.trailing, 10)
                    .padding(.bottom, 8)
            }
            .frame(height: 160)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.047, green: 0.035, blue: 0.027).opacity(0.95),
                        Color(red: 0.031, green: 0.024, blue: 0.039)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(red: 1.0, green: 0.78, blue: 0.47).opacity(0.10), lineWidth: 1)
            )
        }
    }

    // MARK: - Theme Selector (3 buttons: Sistema, Escuro, Claro)

    private var themeSelector: some View {
        HStack(spacing: 8) {
            themeOption(id: "system", icon: "display", label: "Sistema")
            themeOption(id: "dark", icon: "moon", label: "Escuro")
            themeOption(id: "light", icon: "sun.max", label: "Claro")
        }
    }

    private func themeOption(id: String, icon: String, label: String) -> some View {
        let isActive = storedScheme == id

        return Button(action: { storedScheme = id }) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            isActive
                                ? VitaColors.accentHover.opacity(0.10)
                                : Color.white.opacity(0.04)
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isActive
                                        ? Color(red: 1.0, green: 0.78, blue: 0.47).opacity(0.14)
                                        : subtleText.opacity(0.06),
                                    lineWidth: 1
                                )
                        )
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            isActive
                                ? goldText.opacity(0.95)
                                : goldText.opacity(0.70)
                        )
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        isActive
                            ? goldText.opacity(0.90)
                            : Color.white.opacity(0.70)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(isActive ? 0 : 0.02))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isActive
                            ? Color(red: 1.0, green: 0.78, blue: 0.47).opacity(0.22)
                            : subtleText.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Color Accent Selector

    private let accentOptions: [(id: String, label: String, colors: [Color])] = [
        ("gold", "Gold", [Color(red: 0.78, green: 0.63, blue: 0.27), Color(red: 1.0, green: 0.78, blue: 0.47)]),
        ("purple", "Purple", [Color(red: 0.545, green: 0.361, blue: 0.965), Color(red: 0.753, green: 0.518, blue: 0.988)]),
        ("teal", "Teal", [Color(red: 0.078, green: 0.722, blue: 0.651), Color(red: 0.369, green: 0.918, blue: 0.831)]),
        ("blue", "Blue", [Color(red: 0.231, green: 0.510, blue: 0.965), Color(red: 0.576, green: 0.773, blue: 0.992)]),
    ]

    private var accentColorForPreview: Color {
        switch storedAccent {
        case "purple": return Color(red: 0.545, green: 0.361, blue: 0.965)
        case "teal": return Color(red: 0.078, green: 0.722, blue: 0.651)
        case "blue": return Color(red: 0.231, green: 0.510, blue: 0.965)
        default: return Color(red: 0.78, green: 0.63, blue: 0.31)
        }
    }

    private var colorAccentSelector: some View {
        VitaGlassCard {
            HStack(spacing: 10) {
                ForEach(accentOptions, id: \.id) { option in
                    let isActive = storedAccent == option.id

                    VStack(spacing: 4) {
                        Button(action: { storedAccent = option.id }) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: option.colors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            isActive ? Color.white.opacity(0.30) : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        Text(option.label)
                            .font(.system(size: 9))
                            .foregroundStyle(
                                isActive
                                    ? goldText.opacity(0.70)
                                    : subtleText.opacity(0.35)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
        }
    }

    // MARK: - Font Size Slider

    private var fontSizeSection: some View {
        VitaGlassCard {
            VStack(spacing: 0) {
                // A / A labels
                HStack {
                    Text("A")
                        .font(.system(size: 11))
                        .foregroundStyle(subtleText.opacity(0.35))
                    Spacer()
                    Text("A")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(subtleText.opacity(0.35))
                }

                // Slider track
                GeometryReader { geo in
                    let trackWidth = geo.size.width
                    let fillWidth = trackWidth * fontSizeValue
                    let thumbX = fillWidth

                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 4)

                        // Fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.78, green: 0.63, blue: 0.31).opacity(0.60),
                                        Color(red: 1.0, green: 0.78, blue: 0.47).opacity(0.40)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: fillWidth, height: 4)

                        // Thumb
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        goldText.opacity(0.90),
                                        VitaColors.accentHover.opacity(0.80)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().stroke(Color(red: 1.0, green: 0.94, blue: 0.82).opacity(0.30), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.40), radius: 4, y: 2)
                            .shadow(color: Color(red: 0.78, green: 0.63, blue: 0.31).opacity(0.20), radius: 6)
                            .offset(x: thumbX - 10)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let newVal = value.location.x / trackWidth
                                        fontSizeValue = min(max(newVal, 0), 1)
                                    }
                            )
                    }
                }
                .frame(height: 20)
                .padding(.top, 10)

                // Preview text
                Text("Texto de exemplo - Tamanho \(fontSizeLabel)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.70))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            }
            .padding(16)
        }
    }

    private var fontSizeLabel: String {
        if fontSizeValue < 0.25 { return "pequeno" }
        if fontSizeValue < 0.75 { return "médio" }
        return "grande"
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(subtleText.opacity(0.35))
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
    }
}

// MARK: - AppStorage Scheme Binding Helper

extension AppearanceScreen {
    static func resolveColorScheme(from stored: String) -> ColorScheme? {
        switch stored {
        case "light":  return .light
        case "dark":   return .dark
        default:       return nil
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceScreen()
    }
    .preferredColorScheme(.dark)
}
