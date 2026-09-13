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
                        Image(systemName: category.icon)
                            .accessibilityLabel(category.name)
                    }
            }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                        .accessibilityLabel("Ajustes")
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

    @AppStorage("showNetworkStatus") private var showNetworkStatus = false
    @State private var pendingInputCode: USSDCode?
    @State private var inputText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showNetworkStatus {
                    ConnectionBannerView()
                }

                List {
                    ForEach(category.groups) { group in
                        Section {
                            ForEach(group.codes) { code in
                                CodeRowView(code: code)
                                    .contentShape(Rectangle())
                                    .onTapGesture { select(code) }
                            }
                        } header: {
                            if let name = group.name {
                                Text(name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.brandCyan)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
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
                TextField(code.inputPlaceholder ?? "Dato", text: $inputText)
                    .keyboardType(.phonePad)
                Button("Marcar") { dial(code, input: inputText) }
                Button("Cancelar", role: .cancel) {}
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

/// Settings tab: appearance, list display, connection warning, how USSD works, about and links.
struct SettingsView: View {
    @AppStorage("darkModePreference") private var darkMode: Int = 0
    @AppStorage("showNetworkStatus") private var showNetworkStatus = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Apariencia") {
                    Picker("Tema", selection: $darkMode) {
                        Text("Predeterminado del sistema").tag(0)
                        Text("Claro").tag(1)
                        Text("Oscuro").tag(2)
                    }
                }

                Section {
                    Toggle("Aviso de señal celular", isOn: $showNetworkStatus)
                } header: {
                    Text("General")
                } footer: {
                    Text("Muestra un aviso cuando no hay señal celular o es débil. El USSD necesita señal de voz, no datos ni Wi-Fi.")
                }

                Section("Cómo Funciona el USSD") {
                    SettingsInfoRow(
                        title: "¿Qué es el USSD?",
                        text: "El USSD es un protocolo telefónico que te permite interactuar con tu operadora marcando códigos especiales como *222#. Necesita señal celular, no datos ni Wi-Fi. Toca cualquier código de la lista y el marcador del sistema se abre listo para enviarlo — el propio iOS te pide confirmar antes de que la llamada se realice."
                    )
                    SettingsInfoRow(
                        title: "Códigos que piden un dato",
                        text: "Algunos códigos, como recargar con tarjeta, necesitan un número adicional (p. ej. *662*{tarjeta}#). Al tocarlos, primero se pide ese dato y luego se marca el código completo."
                    )
                }

                Section("Acerca de") {
                    Text("CubaCell Connect da acceso rápido a los códigos USSD de servicio de ETECSA (Cubacel): saldo, compras, transferencias y otras utilidades, todo desde una app sin conexión y sin dependencias.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label("No está afiliada, avalada ni patrocinada por ETECSA. Los códigos pueden cambiar en cualquier momento a discreción del operador.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Enlaces") {
                    Link(destination: URL(string: "https://github.com/albertolicea00/cubacell-connect")!) {
                        Label("Código fuente en GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: URL(string: "https://github.com/albertolicea00/MyUSSDCodes-collection")!) {
                        Label("Fuente de la verdad de los códigos USSD", systemImage: "checkmark.seal")
                    }
                    Link(destination: URL(string: "https://www.linkedin.com/in/albertolicea00")!) {
                        Label("Alberto Licea (Desarrollador)", systemImage: "person.circle")
                    }
                }

                Section {
                    Text("Versión \(AppVersion) (\(AppBuild))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Ajustes")
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
