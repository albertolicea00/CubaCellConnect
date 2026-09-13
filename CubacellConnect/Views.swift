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
/// Tapping a row dials it directly — iOS itself confirms before the call is placed.
/// Codes that need an extra value (card number, phone number, ...) prompt for it first via an alert.
struct CategoryListView: View {
    let category: USSDCategory

    @Environment(USSDCodeStore.self) private var store
    @State private var pendingInputCode: USSDCode?
    @State private var inputText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.codes(in: category)) { code in
                    CodeRowView(code: code)
                        .contentShape(Rectangle())
                        .onTapGesture { select(code) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(category.name)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert(
                pendingInputCode?.title ?? "",
                isPresented: Binding(
                    get: { pendingInputCode != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingInputCode = nil
                            inputText = ""
                        }
                    }
                ),
                presenting: pendingInputCode
            ) { code in
                TextField(code.inputPlaceholder ?? "Input", text: $inputText)
                    .keyboardType(.phonePad)
                Button("Dial") { dial(code, input: inputText) }
                Button("Cancel", role: .cancel) {}
            } message: { code in
                Text(code.details)
            }
        }
    }

    private func select(_ code: USSDCode) {
        if code.requiresInput {
            inputText = ""
            pendingInputCode = code
        } else {
            DialService.dial(code.code)
        }
    }

    private func dial(_ code: USSDCode, input: String) {
        DialService.dial(code.resolvedCode(input: input))
    }
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
                        text: "USSD is a phone protocol that lets you interact with your carrier by dialing special codes like *222#. It needs cellular signal, not data or Wi-Fi. Tap any code in the list and the system dialer opens with it ready to send — iOS itself asks you to confirm before the call actually goes through."
                    )
                    SettingsInfoRow(
                        title: "Codes that need input",
                        text: "A few codes, like recharging with a card, need an extra number (e.g. *662*{card}#). Tapping one of those first asks for that value, then dials the completed code."
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
