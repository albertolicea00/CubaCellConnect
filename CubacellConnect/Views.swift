import SwiftUI

// MARK: - Home Screen

/// Root screen: one tab per catalog category, plus a Settings/Help tab.
struct HomeView: View {
    @Environment(USSDCodeStore.self) private var store

    var body: some View {
        TabView {
            ForEach(store.categories) { category in
                CategoryListView(category: category)
                    .tabItem {
                        Label(category.name, systemImage: category.icon)
                    }
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.brandCyan)
    }
}

#Preview {
    HomeView()
        .environment(USSDCodeStore())
}

// MARK: - Category Screen

/// One tab's content: the codes belonging to a single category.
struct CategoryListView: View {
    let category: USSDCategory

    @Environment(USSDCodeStore.self) private var store
    @State private var selectedCode: USSDCode?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.codes(in: category)) { code in
                    CodeRowView(code: code)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedCode = code }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(category.name)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedCode) { code in
                CodeDetailView(code: code)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Code Detail Sheet

/// Detail sheet for a code: description, optional input field, copy and dial actions.
struct CodeDetailView: View {
    let code: USSDCode

    @State private var input = ""
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    private var resolvedCode: String {
        code.resolvedCode(input: input.trimmingCharacters(in: .whitespaces))
    }

    private var isDialDisabled: Bool {
        code.requiresInput && input.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Text(code.details)
                .font(.body)
                .foregroundStyle(Color.appForeground)

            if let mnemonic = code.mnemonic {
                Label(mnemonic, systemImage: "lightbulb.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.brandCyan)
            }

            if code.requiresInput {
                TextField(code.inputPlaceholder ?? "Input", text: $input)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTheme.codeFont(size: 16))
            }

            Spacer()

            actions
        }
        .padding(24)
        .background(Color.appBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(code.title)
                .font(.title2.bold())
                .foregroundStyle(Color.brandNavy)
            Text(resolvedCode)
                .font(AppTheme.codeFont(size: 22))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.brandNavy, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = resolvedCode
                copied = true
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.brandNavy)

            Button {
                DialService.dial(resolvedCode)
                dismiss()
            } label: {
                Label(code.type == .call ? "Call" : "Dial", systemImage: "phone.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandCyan)
            .disabled(isDialDisabled)
        }
        .controlSize(.large)
    }
}

#Preview {
    CodeDetailView(code: USSDCode(
        id: "recharge-card",
        code: "*662*{input}#",
        title: "Recharge with Card",
        details: "Manually recharge your balance with a scratch card.",
        category: "purchase",
        type: .ussd,
        requiresInput: true,
        inputPlaceholder: "Card number",
        mnemonic: nil
    ))
}

// MARK: - Settings / Help Screen

/// Settings tab: appearance, how USSD works, about and links.
struct SettingsView: View {
    @AppStorage("darkModePreference") private var darkMode: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $darkMode) {
                        Text("System Default").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                }

                Section("How USSD Works") {
                    SettingsInfoRow(
                        title: "What is USSD?",
                        text: "USSD is a phone protocol that lets you interact with your carrier by dialing special codes like *222#. It needs cellular signal, not data or Wi-Fi. Tap a code in the app and the system dialer opens with it ready to send — just confirm the call."
                    )
                    SettingsInfoRow(
                        title: "Codes that need input",
                        text: "Some codes, like recharging with a card, ask for extra digits (e.g. *662*{card}#). The app shows a field for that value and fills it into the code before dialing."
                    )
                    SettingsInfoRow(
                        title: "Copy vs. Dial",
                        text: "Copy puts the resolved code on the clipboard so you can paste it elsewhere. Dial hands it straight to the system dialer, which asks you to confirm before it actually places the call."
                    )
                    SettingsInfoRow(
                        title: "Mnemonics",
                        text: "Some codes show a keypad mnemonic, e.g. 328 = DAT, 266 = BON, 869 = VOZ — the digits spell the service name on a phone keypad, as a memory aid."
                    )
                }

                Section("About") {
                    Text("CubaCell Connect gives quick access to ETECSA (Cubacel) USSD service codes: balance, purchases, transfers and other utilities, all from one offline, dependency-free app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label("Not affiliated with, endorsed by, or sponsored by ETECSA. Codes may change at any time at the carrier's discretion.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Links") {
                    Link(destination: URL(string: "https://github.com/albertolicea00/cubacell-connect")!) {
                        Label("Source Code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: URL(string: "https://github.com/albertolicea00/MyUSSDCodes-collection")!) {
                        Label("USSD Codes Source of Truth", systemImage: "checkmark.seal")
                    }
                    Link(destination: URL(string: "https://www.linkedin.com/in/albertolicea00")!) {
                        Label("Alberto Licea (Developer)", systemImage: "person.circle")
                    }
                }

                Section("Code Sources") {
                    Link("galixpay.com/recargas-a-cuba", destination: URL(string: "https://galixpay.com/recargas-a-cuba/")!)
                    Link("fonoma.com/blog/codigos-ussd-cuba", destination: URL(string: "https://www.fonoma.com/blog/codigos-ussd-cuba")!)
                    Link("etecsa.cu", destination: URL(string: "https://www.etecsa.cu/es/taxonomy/term/1445")!)
                }

                Section {
                    Text("Version \(AppVersion) (\(AppBuild))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

/// One title + body row inside a Settings section.
private struct SettingsInfoRow: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandCyan)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView()
}
