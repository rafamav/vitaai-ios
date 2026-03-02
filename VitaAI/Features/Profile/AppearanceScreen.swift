import SwiftUI

// MARK: - Theme Option Model

private struct ThemeOption: Identifiable {
    let id: String
    let label: String
    let description: String
    let icon: String            // SF Symbol name
    let colorScheme: ColorScheme?  // nil = system
}

private let themeOptions: [ThemeOption] = [
    ThemeOption(
        id: "light",
        label: "Claro",
        description: "Tema claro sempre ativo",
        icon: "sun.max.fill",
        colorScheme: .light
    ),
    ThemeOption(
        id: "dark",
        label: "Escuro",
        description: "Tema escuro sempre ativo",
        icon: "moon.fill",
        colorScheme: .dark
    ),
    ThemeOption(
        id: "system",
        label: "Sistema",
        description: "Seguir configuração do dispositivo",
        icon: "circle.lefthalf.filled",
        colorScheme: nil
    ),
]

// MARK: - AppearanceScreen

struct AppearanceScreen: View {
    @Environment(\.dismiss) private var dismiss

    /// Persisted preference key — matches AppRouter usage
    @AppStorage("vita_color_scheme") private var storedScheme: String = "system"

    // Stagger entrance
    @State private var rowOpacities: [Double] = [0, 0, 0]
    @State private var rowOffsets: [Double] = [16, 16, 16]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tema")
                    .font(VitaTypography.titleLarge)
                    .foregroundStyle(VitaColors.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                VitaGlassCard {
                    VStack(spacing: 0) {
                        ForEach(Array(themeOptions.enumerated()), id: \.element.id) { index, option in
                            ThemeRow(
                                option: option,
                                isSelected: storedScheme == option.id,
                                onSelect: {
                                    storedScheme = option.id
                                }
                            )
                            .opacity(rowOpacities[index])
                            .offset(y: rowOffsets[index])

                            if index < themeOptions.count - 1 {
                                Divider().background(VitaColors.glassBorder)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .navigationTitle("Aparência")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                }
            }
        }
        .onAppear {
            for i in themeOptions.indices {
                withAnimation(.easeOut(duration: 0.35).delay(Double(i) * 0.06)) {
                    rowOpacities[i] = 1
                    rowOffsets[i] = 0
                }
            }
        }
    }
}

// MARK: - ThemeRow

private struct ThemeRow: View {
    let option: ThemeOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: { onSelect() }) {
            HStack(spacing: 14) {
                Image(systemName: option.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(VitaTypography.bodyLarge)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(option.description)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer()

                // Radio-style indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? VitaColors.accent : VitaColors.textTertiary,
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(VitaColors.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - AppStorage Scheme Binding Helper
// Call this from AppRouter to actually apply the preference.
extension AppearanceScreen {
    /// Resolves the stored string key to a SwiftUI ColorScheme (nil = follow system).
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
