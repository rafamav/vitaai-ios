import SwiftUI

// MARK: - VitaSpeakingMascot
//
// Mascote contextual estilo Duolingo. Wrappa OrbMascot existente (não toca o
// orb base, retrocompat 7 callsites) + adiciona:
//   • Balão de fala apontando pro orb (OrbSpeechBubble) com tail
//   • Prop contextual (livro, lápis, ampulheta, lâmpada, coração, etc)
//   • Personas (.idle / .guiding / .cheering / .studying / .focusing /
//     .resting / .thinking / .celebrating / .empathetic) mapeadas pra
//     VitaMascotState do orb base
//   • Personalização via {name} placeholder no texto
//
// Padrão Duolingo (analisado em IMG_6453-6462): mascote SEMPRE presente em
// cada step educativo, expressão muda conforme ação, balão acima centrado
// com tail apontando, copy curta personalizada com nome do user.
// Shell §5.2 — sub-telas educativas devem ter persona contextual em vez de
// ProgressView/ícone genérico.

// MARK: - Persona + Prop

enum MascotPersona: Equatable {
    case idle                                    // neutro, respiração suave
    case guiding                                 // explicando, atento
    case cheering                                // sparkle eyes, sorriso largo
    case studying(prop: MascotProp = .book)      // segurando livro/lápis
    case focusing(timeLeft: TimeInterval? = nil) // ampulheta, olhar sério
    case resting                                 // olhos fechados, "Z"
    case thinking                                // lâmpada, refletindo
    case celebrating(badge: String? = nil)       // confete, conquista
    case empathetic                              // coração ao lado, gentil

    fileprivate var orbState: VitaMascotState {
        switch self {
        case .idle:                       return .awake
        case .guiding:                    return .thinking
        case .cheering, .celebrating:     return .happy
        case .studying, .focusing:        return .thinking
        case .resting:                    return .sleeping
        case .thinking:                   return .thinking
        case .empathetic:                 return .thinking
        }
    }

    fileprivate var prop: MascotProp? {
        switch self {
        case .idle, .guiding, .resting, .cheering: return nil
        case .studying(let p):                     return p
        case .focusing:                            return .hourglass
        case .thinking:                            return .lamp
        case .celebrating:                         return .confetti
        case .empathetic:                          return .heart
        }
    }
}

enum MascotProp: Equatable {
    case book, pencil, hourglass, lamp, heart, confetti, sparkle

    fileprivate var systemName: String {
        switch self {
        case .book:     return "book.fill"
        case .pencil:   return "pencil.tip"
        case .hourglass: return "hourglass.bottomhalf.filled"
        case .lamp:     return "lightbulb.fill"
        case .heart:    return "heart.fill"
        case .confetti: return "party.popper.fill"
        case .sparkle:  return "sparkles"
        }
    }

    fileprivate var color: Color {
        switch self {
        case .book:     return Color(red: 0.95, green: 0.78, blue: 0.42) // gold
        case .pencil:   return Color(red: 1.00, green: 0.82, blue: 0.52)
        case .hourglass: return Color(red: 0.78, green: 0.86, blue: 1.00) // azulado
        case .lamp:     return Color(red: 1.00, green: 0.86, blue: 0.45)
        case .heart:    return Color(red: 0.96, green: 0.42, blue: 0.45) // soft red
        case .confetti: return Color(red: 1.00, green: 0.78, blue: 0.36)
        case .sparkle:  return Color(red: 1.00, green: 0.86, blue: 0.55)
        }
    }
}

// MARK: - Speaking Mascot

struct VitaSpeakingMascot: View {
    var persona: MascotPersona = .idle
    var size: CGFloat = 96
    /// Texto do balão. Placeholder `{name}` é substituído por `userName` se passado.
    /// Ex: "Bons estudos, {name}!" + userName="Rafael" → "Bons estudos, Rafael!"
    var speech: String? = nil
    var userName: String? = nil
    /// Quando true, balão e prop animam entrance (fade + scale 0.92→1).
    var animatesEntrance: Bool = true

    @State private var entranceProgress: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            if let speech, !speech.isEmpty {
                OrbSpeechBubble(text: resolved(speech))
                    .opacity(entranceProgress)
                    .scaleEffect(0.92 + 0.08 * entranceProgress, anchor: .bottom)
            }

            ZStack(alignment: .bottomLeading) {
                OrbMascot(
                    palette: .vita,
                    state: persona.orbState,
                    size: size,
                    bounceEnabled: persona == .idle || persona == .cheering
                )

                if let prop = persona.prop {
                    propBadge(for: prop)
                        .offset(x: -size * 0.10, y: size * 0.05)
                        .opacity(entranceProgress)
                        .scaleEffect(entranceProgress, anchor: .bottomLeading)
                }
            }
        }
        .onAppear {
            if animatesEntrance {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    entranceProgress = 1
                }
            } else {
                entranceProgress = 1
            }
        }
    }

    private func resolved(_ text: String) -> String {
        guard let userName, !userName.isEmpty else {
            return text.replacingOccurrences(of: "{name}", with: "")
                       .replacingOccurrences(of: ", !", with: "!")
        }
        // Pega só o primeiro nome — copy fica natural ("Rafael" vs "Rafael Loureiro")
        let first = userName.split(separator: " ").first.map(String.init) ?? userName
        return text.replacingOccurrences(of: "{name}", with: first)
    }

    @ViewBuilder
    private func propBadge(for prop: MascotProp) -> some View {
        let badgeSize = size * 0.36
        ZStack {
            Circle()
                .fill(VitaColors.surface.opacity(0.92))
                .overlay(
                    Circle().stroke(prop.color.opacity(0.30), lineWidth: 1.5)
                )
                .frame(width: badgeSize, height: badgeSize)
                .shadow(color: prop.color.opacity(0.30), radius: 6, y: 2)

            Image(systemName: prop.systemName)
                .font(.system(size: badgeSize * 0.55, weight: .semibold))
                .foregroundStyle(prop.color)
        }
    }
}

// MARK: - Speech bubble

/// Balão de fala apontando pra baixo (pro orb que fica embaixo dele).
/// Estilo Duolingo: borda 1.5px sutil, fundo escuro semi-transparente,
/// tail centrada na borda inferior.
struct OrbSpeechBubble: View {
    let text: String
    var maxWidth: CGFloat = 280

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(VitaColors.textPrimary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: maxWidth)
            .background(
                BubbleShape()
                    .fill(VitaColors.glassInnerLight.opacity(0.10))
                    .overlay(
                        BubbleShape()
                            .stroke(VitaColors.accentHover.opacity(0.22), lineWidth: 1.2)
                    )
                    .shadow(color: .black.opacity(0.30), radius: 8, y: 4)
            )
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// RoundedRect com tail triangular saindo do meio da borda inferior.
private struct BubbleShape: Shape {
    var cornerRadius: CGFloat = 16
    var tailWidth: CGFloat = 18
    var tailHeight: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let bodyHeight = rect.height - tailHeight
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: bodyHeight)
        let tailMidX = rect.midX

        var path = Path()
        // Top edge
        path.move(to: CGPoint(x: body.minX + cornerRadius, y: body.minY))
        path.addLine(to: CGPoint(x: body.maxX - cornerRadius, y: body.minY))
        path.addArc(
            center: CGPoint(x: body.maxX - cornerRadius, y: body.minY + cornerRadius),
            radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        // Right edge
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - cornerRadius))
        path.addArc(
            center: CGPoint(x: body.maxX - cornerRadius, y: body.maxY - cornerRadius),
            radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        // Bottom edge with tail
        path.addLine(to: CGPoint(x: tailMidX + tailWidth / 2, y: body.maxY))
        path.addLine(to: CGPoint(x: tailMidX, y: body.maxY + tailHeight))
        path.addLine(to: CGPoint(x: tailMidX - tailWidth / 2, y: body.maxY))
        path.addLine(to: CGPoint(x: body.minX + cornerRadius, y: body.maxY))
        path.addArc(
            center: CGPoint(x: body.minX + cornerRadius, y: body.maxY - cornerRadius),
            radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        // Left edge
        path.addLine(to: CGPoint(x: body.minX, y: body.minY + cornerRadius))
        path.addArc(
            center: CGPoint(x: body.minX + cornerRadius, y: body.minY + cornerRadius),
            radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview("Personas") {
    ScrollView {
        VStack(spacing: 32) {
            VitaSpeakingMascot(persona: .cheering, speech: "Bons estudos, {name}!", userName: "Rafael")
            VitaSpeakingMascot(persona: .focusing(timeLeft: 1500), speech: "Foco — 25 min", userName: nil)
            VitaSpeakingMascot(persona: .studying(prop: .book), speech: "Que disciplina hoje?")
            VitaSpeakingMascot(persona: .empathetic, speech: "Algo deu errado. Tenta de novo em 1 minuto.")
            VitaSpeakingMascot(persona: .thinking, speech: "Hmm, deixa eu pensar...")
            VitaSpeakingMascot(persona: .celebrating(badge: "🏆"), speech: "Você desbloqueou: Top 10!")
            VitaSpeakingMascot(persona: .resting, speech: "Boa noite — silencioso até 7h")
        }
        .padding()
    }
    .background(VitaColors.surface)
}
