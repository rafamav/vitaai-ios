import SwiftUI

// MARK: - ConnectorCard
// Shared card used by ConnectionsScreen, Onboarding ConnectStep, and any future connector entry point.
// Mirrors Android's ConnectorCard composable and web's connector-card component.
//
// Gold Standard — 4 estados:
// 1. Conectado + dados frescos (<12h): 🟢 "Conectado" | "56min atrás · 4172 notas" | [Desconectar]
// 2. Conectado + dados velhos (>12h):  🟡 "Conectado" | "⚠ Dados 14h" + "⚡ Token vivo 3min" | [Desconectar]
// 3. Expirado:                         🔴 "Expirado"  | "⚠ Expirado · dados 56min" (sem token vivo) | [Reconectar]
// 4. Desconectado:                     ⚪ "Disponível" | — | [Conectar]

struct ConnectorCard: View {
    let letter: String
    let name: String
    let status: ConnectionItemStatus
    let color: Color
    var subtitle: String?            // email, phone, or account info shown under name
    var lastSync: String?
    var lastPing: String?           // "sessao viva ha Xmin" — so quando status==connected e divergir do lastSync
    var isStale: Bool = false        // conectado mas dados > 12h → dot e texto ficam ambar
    var stats: [(value: Int, label: String)] = []
    var isPrimary: Bool = false
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?
    var onTapConnected: (() -> Void)?

    // Design tokens (gold palette)
    private let goldSubtle = VitaColors.accentLight
    private let borderColor = VitaColors.glassBorder
    private let cardBg = VitaColors.glassBg

    // State-derived colors
    private var dotColor: Color {
        switch status {
        case .connected:
            return Color(red: 0.510, green: 0.784, blue: 0.549).opacity(0.75)
        case .expired:
            return Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.75)
        default:
            return Color.white.opacity(0.12)
        }
    }

    private var dotGlow: Color {
        switch status {
        case .connected:
            return Color(red: 0.510, green: 0.784, blue: 0.549).opacity(0.30)
        case .expired:
            return Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.30)
        default:
            return .clear
        }
    }

    var body: some View {
        let isActive = status == .connected || status == .expired

        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    letterIcon
                    nameAndStatus
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isActive { onTapConnected?() }
                }
                actionButton
            }
            .padding(14)

            // Meta row
            if hasMetaData {
                metaRow
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isActive { onTapConnected?() }
                    }
            }
        }
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Letter Icon

    private var letterIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.22))
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.18), lineWidth: 1)
                )
            Text(letter)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color.opacity(0.90))
        }
    }

    // MARK: - Name + Status

    private var nameAndStatus: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 1.0, green: 0.988, blue: 0.973).opacity(0.90))

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.50))
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: dotGlow, radius: 3)
                Text(statusLabel)
                    .font(.system(size: 10.5))
                    .foregroundColor(statusLabelColor)
            }
        }
    }

    private var statusLabel: String {
        switch status {
        case .connected: "Conectado"
        case .expired: "Expirado"
        case .disconnected: isPrimary ? "Detectado" : "Disponível"
        case .loading: "Carregando..."
        }
    }

    private var statusLabelColor: Color {
        switch status {
        case .connected: Color(red: 0.510, green: 0.784, blue: 0.549).opacity(0.65)
        case .expired: Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.65)
        default: isPrimary ? color.opacity(0.8) : goldSubtle.opacity(0.35)
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button {
            switch status {
            case .connected:
                onDisconnect?()
            case .expired:
                onConnect?()  // Reconectar
            default:
                onConnect?()
            }
        } label: {
            Text(buttonLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(buttonFgColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(buttonBgColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(buttonBorderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var buttonLabel: String {
        switch status {
        case .connected: "Desconectar"
        case .expired: "Reconectar"
        default: "Conectar"
        }
    }

    private var buttonFgColor: Color {
        switch status {
        case .connected:
            return Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.70)
        case .expired:
            return VitaColors.dataAmber.opacity(0.80)
        default:
            return isPrimary ? color : Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.80)
        }
    }

    private var buttonBgColor: Color {
        switch status {
        case .connected:
            return Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.06)
        case .expired:
            return VitaColors.dataAmber.opacity(0.10)
        default:
            return (isPrimary ? color : VitaColors.glassInnerLight).opacity(0.12)
        }
    }

    private var buttonBorderColor: Color {
        switch status {
        case .connected:
            return Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.12)
        case .expired:
            return VitaColors.dataAmber.opacity(0.16)
        default:
            return (isPrimary ? color : Color(red: 1.0, green: 0.784, blue: 0.471)).opacity(0.16)
        }
    }

    // MARK: - Meta Row

    private var hasMetaData: Bool {
        lastSync != nil || stats.contains(where: { $0.value > 0 })
    }

    private var syncTextColor: Color {
        if status == .expired { return VitaColors.dataAmber.opacity(0.75) }
        return Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.55)
    }

    private var syncIconName: String {
        status == .expired ? "exclamationmark.triangle.fill" : "clock"
    }

    private var syncIconColor: Color {
        status == .expired
            ? VitaColors.dataAmber.opacity(0.50)
            : goldSubtle.opacity(0.25)
    }

    private var syncPrefix: String {
        status == .expired ? "Expirado · dados " : ""
    }

    private var metaRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(goldSubtle.opacity(0.04))
                .frame(height: 1)

            // Line 1: sync time + stats
            HStack(spacing: 6) {
                if let sync = lastSync {
                    Image(systemName: syncIconName)
                        .font(.system(size: 8))
                        .foregroundColor(syncIconColor)
                    Text("\(syncPrefix)\(sync)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(syncTextColor)
                }

                if lastSync != nil && stats.contains(where: { $0.value > 0 }) {
                    Circle()
                        .fill(goldSubtle.opacity(0.20))
                        .frame(width: 3, height: 3)
                }

                ForEach(stats.indices, id: \.self) { i in
                    if stats[i].value > 0 {
                        HStack(spacing: 2) {
                            Text("\(stats[i].value)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.55))
                            Text(stats[i].label)
                                .font(.system(size: 10))
                                .foregroundColor(goldSubtle.opacity(0.30))
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            // Line 2: "Token vivo" — ONLY when connected and ping differs from sync
            // NEVER when expired (token is dead, showing "vivo" is a lie)
            if let ping = lastPing, status == .connected {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7))
                        .foregroundColor(Color(red: 0.510, green: 0.784, blue: 0.549).opacity(0.55))
                    Text("Token vivo · verificado \(ping)")
                        .font(.system(size: 9))
                        .foregroundColor(Color(red: 0.510, green: 0.784, blue: 0.549).opacity(0.55))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            } else {
                Spacer().frame(height: 8)
            }
        }
    }
}
