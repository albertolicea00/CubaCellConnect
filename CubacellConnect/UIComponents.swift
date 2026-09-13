import SwiftUI

// MARK: - Code Row

/// One row in the code list: title and description only — no raw dial code shown, since
/// iOS itself asks for confirmation before the call goes through when the row is tapped.
struct CodeRowView: View {
    let code: USSDCode

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(code.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appForeground)

                Text(code.details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: code.type == .call ? "phone.fill" : "number")
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.brandCyan, in: Circle())
        }
        .padding(.vertical, 8)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    CodeRowView(code: USSDCode(
        id: "main-balance",
        code: "*222#",
        title: "Saldo Principal",
        details: "Consulta tu saldo, minutos, SMS y datos.",
        category: "balance",
        type: .ussd,
        requiresInput: false,
        inputPlaceholder: nil,
        mnemonic: "328 = DAT (datos)"
    ))
    .padding()
}

// MARK: - Connection Status Banner

/// Warns when cellular signal is absent or weak, since USSD codes need voice-network
/// reachability and will silently fail to send without it.
struct ConnectionBannerView: View {
    @State private var monitor = CellularMonitor.shared

    private var statusText: String {
        guard monitor.hasService else { return "Sin señal — el USSD no funcionará" }
        switch monitor.signalQuality {
        case 3: return "Señal óptima (\(monitor.networkType))"
        case 2: return "Señal buena (\(monitor.networkType))"
        case 1: return "Señal débil (riesgo de fallo)"
        default: return "Buscando red..."
        }
    }

    private var statusColor: Color {
        guard monitor.hasService else { return .red }
        switch monitor.signalQuality {
        case 3: return .green
        case 2: return Color.brandCyan
        case 1: return .orange
        default: return .gray
        }
    }

    private var statusIcon: String {
        guard monitor.hasService else { return "antenna.radiowaves.left.and.right.slash" }
        return monitor.signalQuality == 1 ? "exclamationmark.triangle.fill" : "antenna.radiowaves.left.and.right"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .bold))
            Text(statusText)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(statusColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.15))
    }
}

#Preview {
    ConnectionBannerView()
}
