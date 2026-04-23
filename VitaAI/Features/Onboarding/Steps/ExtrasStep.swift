import SwiftUI

/// Onboarding step after the institutional portal: teaches the user that Vita
/// also works outside the university portal (WhatsApp, Drive, Calendar, Spotify).
///
/// All connections are optional — user can hit "Pular" at the bottom button row.
/// WhatsApp is the headline because it's already live end-to-end.
/// The other cards open the existing `/integrations/<provider>` OAuth flow.
struct ExtrasStep: View {
    let api: VitaAPI
    let onConnectWhatsApp: () -> Void
    let onConnectIntegration: (String) -> Void

    var body: some View {
        // Speech bubble is rendered by the parent VitaOnboarding shell
        // (via typeText on step transition). Duplicating it here was the
        // root cause of "two bubbles stacked" (incident 2026-04-23).
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 10) {
                extraCard(
                    letter: "W",
                    name: "WhatsApp",
                    subtitle: "Receba lembretes e fale com a VITA pelo zap",
                    color: Color(red: 0.15, green: 0.68, blue: 0.38),
                    badge: "DESTAQUE",
                    action: onConnectWhatsApp
                )
                extraCard(
                    letter: "D",
                    name: "Google Drive",
                    subtitle: "Vita lê e organiza seus PDFs do Drive",
                    color: Color(red: 0.25, green: 0.52, blue: 0.96),
                    badge: nil,
                    action: { onConnectIntegration("google_drive") }
                )
                extraCard(
                    letter: "C",
                    name: "Google Calendar",
                    subtitle: "Sincroniza provas, trabalhos e aulas",
                    color: Color(red: 0.96, green: 0.55, blue: 0.25),
                    badge: nil,
                    action: { onConnectIntegration("google_calendar") }
                )
                extraCard(
                    letter: "♫",
                    name: "Spotify",
                    subtitle: "Música de foco durante a transcrição",
                    color: Color(red: 0.11, green: 0.73, blue: 0.33),
                    badge: nil,
                    action: { onConnectIntegration("spotify") }
                )
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func extraCard(
        letter: String,
        name: String,
        subtitle: String,
        color: Color,
        badge: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Text(letter)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(VitaColors.accent)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(VitaColors.accent.opacity(0.14)))
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.30))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
