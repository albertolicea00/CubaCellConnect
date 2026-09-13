import ContactsUI
import SwiftUI

// MARK: - Contact Picker

/// Wraps the system contact picker so picking a contact with several phone numbers drills down
/// to a single number automatically. Runs out-of-process — unlike reading `Contacts` directly,
/// this needs no `NSContactsUsageDescription` entry and never prompts for permission.
struct ContactPickerView: UIViewControllerRepresentable {
    /// Called with the picked number and whether it passed `CubanPhoneNumber.normalize` — when
    /// `false`, the string is just the raw digits (no country-code stripping applied), so the
    /// caller can still fill the field but should warn the number doesn't look Cuban.
    var onPick: (_ number: String, _ isValidCubanNumber: Bool) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (String, Bool) -> Void

        init(onPick: @escaping (String, Bool) -> Void) {
            self.onPick = onPick
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            guard let phoneNumber = contactProperty.value as? CNPhoneNumber else { return }
            let raw = phoneNumber.stringValue
            if let normalized = CubanPhoneNumber.normalize(raw) {
                onPick(normalized, true)
            } else {
                onPick(raw.filter { $0.isASCII && $0.isNumber }, false)
            }
        }
    }
}

// MARK: - Pin Reveal Field

/// A "Clave" field that masks itself with dots plus an eye toggle when `isMasked` is true (the
/// value came from a saved/system password — `TransferPinStore` or Apple Passwords autofill),
/// and shows plain text with no toggle when `isMasked` is false (the user is typing it in by
/// hand, so there's nothing to hide from them).
struct PinRevealField: View {
    let title: String
    @Binding var text: String
    var isMasked: Bool

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isMasked && !isRevealed {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .textContentType(.password)
            .keyboardType(.numberPad)

            if isMasked {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Code Row

/// One row in the code list: title, plus a trailing price when the code has one. A priced code's
/// title already says what it is (e.g. "Plan de 20 SMS"), so the description is skipped for it —
/// unpriced codes still show their description. No raw dial code shown either way, since iOS
/// itself asks for confirmation before the call goes through.
struct CodeRowView: View {
    let code: USSDCode

    @Environment(AccentColorStore.self) private var accentColorStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(code.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appForeground)

                if code.price == nil {
                    Text(code.details)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let price = code.price {
                Text(price)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.brandNavy)
            }

            Image(systemName: code.type == .call ? "phone.fill" : "number")
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(accentColorStore.color, in: Circle())
        }
        .padding(.vertical, 8)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    CodeRowView(code: USSDCode(
        id: "sms-bundle-20",
        code: "*133*2*1#",
        title: "Plan de 20 SMS",
        details: "20 SMS.",
        icon: nil,
        price: "$15.00",
        compact: nil,
        showsNumber: nil,
        type: .ussd,
        requiresInput: false,
        inputPlaceholder: nil
    ))
    .padding()
    .environment(AccentColorStore())
}

// MARK: - Contact Row

/// One row in a phone directory: icon, title + the actual number (unlike `CodeRowView`, which
/// hides the dial string), and a dedicated call button — tapping the row does the same thing.
struct ContactRowView: View {
    let code: USSDCode
    let onCall: () -> Void

    @Environment(AccentColorStore.self) private var accentColorStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: code.icon ?? "phone.fill")
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(accentColorStore.color, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(code.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appForeground)
                Text(code.code)
                    .font(AppTheme.codeFont(size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onCall) {
                Image(systemName: "phone.circle.fill")
                    .font(.title2)
                    .foregroundStyle(accentColorStore.color)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    ContactRowView(
        code: USSDCode(
            id: "emergency-police",
            code: "106",
            title: "Policía Nacional (PNR)",
            details: "Policía Nacional Revolucionaria.",
            icon: "shield.fill",
            price: nil,
            compact: nil,
            showsNumber: true,
            type: .call,
            requiresInput: false,
            inputPlaceholder: nil
        ),
        onCall: {}
    )
    .padding()
    .environment(AccentColorStore())
}

// MARK: - Connection Status Banner

/// Warns when cellular signal is absent or weak, since USSD codes need voice-network
/// reachability and will silently fail to send without it.
struct ConnectionBannerView: View {
    @State private var monitor = CellularMonitor.shared
    @Environment(AccentColorStore.self) private var accentColorStore

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
        case 2: return accentColorStore.color
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
        .environment(AccentColorStore())
}
