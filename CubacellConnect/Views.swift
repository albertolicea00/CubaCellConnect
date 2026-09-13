import SwiftUI

// MARK: - Home Screen

/// Root screen. Tab order is explicit (not a generic `ForEach` over every category) since Home
/// must sit in the middle, flanked by Contactos/Líneas de Ayuda on one side and Compras on the
/// other: Líneas de Ayuda, Contactos, Home, Compras, Ajustes.
struct HomeView: View {
    @Environment(USSDCodeStore.self) private var store
    @AppStorage("defaultTab") private var defaultTab = HomeTab.home.rawValue
    @State private var selectedTab = HomeTab.home.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            if let helplines = store.tabCategories.first(where: { $0.id == "helplines" }) {
                CategoryListView(category: helplines)
                    .tabItem {
                        Image(systemName: helplines.icon)
                            .accessibilityLabel(helplines.name)
                    }
                    .tag(HomeTab.helplines.rawValue)
            }

            ContactsListView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                        .accessibilityLabel("Contactos")
                }
                .tag(HomeTab.contacts.rawValue)

            HomeQuickActionsView()
                .tabItem {
                    Image(systemName: "house.fill")
                        .accessibilityLabel("Home")
                }
                .tag(HomeTab.home.rawValue)

            if let purchase = store.tabCategories.first(where: { $0.id == "purchase" }) {
                CategoryListView(category: purchase)
                    .tabItem {
                        Image(systemName: purchase.icon)
                            .accessibilityLabel(purchase.name)
                    }
                    .tag(HomeTab.purchase.rawValue)
            }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                        .accessibilityLabel("Ajustes")
                }
                .tag(HomeTab.settings.rawValue)
        }
        .tint(.brandCyan)
        .onAppear { selectedTab = defaultTab }
    }
}

/// The 5 tabs, keyed by a stable string so it can be stored in `@AppStorage` (as "Pestaña
/// inicial" in Ajustes › Preferencias) and used as the `TabView` selection tag.
enum HomeTab: String, CaseIterable, Identifiable {
    case helplines, contacts, home, purchase, settings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .helplines: return "Líneas de Ayuda"
        case .contacts: return "Contactos"
        case .home: return "Home"
        case .purchase: return "Compras"
        case .settings: return "Ajustes"
        }
    }
}

#Preview {
    HomeView()
        .environment(USSDCodeStore())
}

/// How the Contactos row's call button behaves — configurable in Ajustes › Preferencias.
enum ContactCallMode: String, CaseIterable, Identifiable {
    case separateButtons, collectDefault, anonymousDefault

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .separateButtons: return "Dos botones separados"
        case .collectDefault: return "Llamar con 99 directo"
        case .anonymousDefault: return "Llamar Anónimo directo"
        }
    }
}

// MARK: - Home Quick Actions

/// The Home tab: one system `List` (same `.insetGrouped` style as every other tab), with
/// "Consultar Todo" and the balance shortcuts sharing a single "Saldo y Planes" section,
/// plus a "Transferir" and a "Recargar" section whose fields are plain rows, not a custom card.
struct HomeQuickActionsView: View {
    @Environment(USSDCodeStore.self) private var store
    @AppStorage("showNetworkStatus") private var showNetworkStatus = false

    @State private var phoneNumber = ""
    @State private var pin = ""
    @State private var amount = ""
    @State private var cardNumber = ""
    @State private var showingContactPicker = false

    private var isTransferDisabled: Bool {
        phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
            || pin.trimmingCharacters(in: .whitespaces).isEmpty
            || amount.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isRechargeDisabled: Bool {
        cardNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showNetworkStatus {
                    ConnectionBannerView()
                }

                List {
                    Section("Saldo y Planes") {}
                    .listSectionSpacing(6)

                    Section {
                        GeometryReader { geometry in
                            let tiles = [
                                ("Saldo", "creditcard.fill", "main-balance"),
                                ("Bonos", "gift.fill", "bonus-usd-plans"),
                                ("Datos", "antenna.radiowaves.left.and.right", "data-plan"),
                                ("Deuda", "creditcard.trianglebadge.exclamationmark", "postpaid-balance"),
                            ]
                            let gap: CGFloat = 20
                            let rawSize = (geometry.size.width - gap * CGFloat(tiles.count - 1)) / CGFloat(tiles.count)
                            let tileSize = min(max(rawSize, 44), 84)

                            HStack(spacing: gap) {
                                ForEach(tiles, id: \.2) { title, icon, codeId in
                                    QuickActionTile(title: title, systemImage: icon, size: tileSize) {
                                        dial(codeId: codeId)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: 96)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    }
                    .listSectionSpacing(6)

                    Section {
                        Button {
                            dial(codeId: "postpaid-balance")
                        } label: {
                            Label("Saldo Pospago o Institucional", systemImage: "building.2.fill")
                        }
                    }
                    .listSectionSpacing(6)

                    Section {
                        Button {
                            dial(codeId: "friends-plan")
                        } label: {
                            Label("Estado del Plan Amigos", systemImage: "person.2.fill")
                        }
                    }
                    .listSectionSpacing(6)

                    Section {
                        HStack(spacing: 12) {
                            Button {
                                showingContactPicker = true
                            } label: {
                                Image(systemName: "person.crop.circle")
                                    .foregroundStyle(.secondary)
                            }

                            TextField("Número (+53 ...)", text: $phoneNumber)
                                .keyboardType(.numberPad)
                        }

                        HStack(spacing: 12) {
                            TextField("Clave", text: $pin)
                                .keyboardType(.numberPad)
                            Divider()
                            TextField("Monto", text: $amount)
                                .keyboardType(.numberPad)
                        }

                        Button {
                            dialTransfer()
                        } label: {
                            HStack(spacing: 6) {
                                Spacer()
                                Text("Transferir")
                                Image(systemName: "arrow.right")
                            }
                        }
                        .disabled(isTransferDisabled)
                    } header: {
                        Text("Transferir")
                    }

                    Section("Recargar") {
                        Button {
                            dial(codeId: "recharge-call")
                        } label: {
                            Label("Recargar por Llamada", systemImage: "phone.fill")
                        }
                    }
                    .listSectionSpacing(6)

                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Escanear (próximamente)")

                            TextField("Código de recarga", text: $cardNumber)
                                .keyboardType(.numberPad)
                        }

                        Button {
                            dialRechargeCard()
                        } label: {
                            HStack(spacing: 6) {
                                Spacer()
                                Text("Recargar con Tarjeta")
                                Image(systemName: "arrow.right")
                            }
                        }
                        .disabled(isRechargeDisabled)
                    }
                    .listSectionSpacing(6)

                    if let advanceBalanceGroup = store.group(named: "Servicio Adelanta Saldo") {
                        Section(advanceBalanceGroup.name ?? "") {
                            HStack(spacing: 12) {
                                ForEach(advanceBalanceGroup.codes) { code in
                                    Button {
                                        DialService.dial(code.code)
                                    } label: {
                                        Text(code.price ?? code.title)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(OutlineButtonStyle())
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .tint(.brandCyan)
                .sheet(isPresented: $showingContactPicker) {
                    ContactPickerView { number in
                        phoneNumber = number
                    }
                    .ignoresSafeArea()
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func dial(codeId: String) {
        if let code = store.code(withId: codeId) {
            DialService.dial(code.code)
        }
    }

    /// Composes `transfer-direct`'s `{phoneNumber}`/`{pin}`/`{amount}` placeholders. Assumed dial
    /// pattern `*234*1*{phoneNumber}*{pin}*{amount}#` — verify against the real ETECSA menu before
    /// relying on it; this app has no way to confirm it against a live line.
    private func dialTransfer() {
        guard let code = store.code(withId: "transfer-direct") else { return }
        let resolved = code.resolvedCode(with: ["phoneNumber": phoneNumber, "pin": pin, "amount": amount])
        DialService.dial(resolved)
    }

    private func dialRechargeCard() {
        guard let code = store.code(withId: "recharge-card") else { return }
        DialService.dial(code.resolvedCode(input: cardNumber))
    }
}

#Preview {
    HomeQuickActionsView()
        .environment(USSDCodeStore())
}

/// A secondary/outline look: border and text in the tint color, no filled background —
/// unlike `.bordered`, which fills with a light tint. Used for the Adelanta Saldo amount buttons.
private struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 6)
            .foregroundStyle(Color.brandCyan)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.brandCyan, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// One square icon + label button in the Home quick-action grid.
private struct QuickActionTile: View {
    let title: String
    let systemImage: String
    /// Explicit width computed by the parent from the available screen width, so the tile
    /// actually grows on a bigger screen instead of collapsing to the icon's intrinsic size.
    let size: CGFloat
    let action: () -> Void

    /// Shorter than `size` so the tile reads as a rounded rectangle, not a square.
    private var height: CGFloat { size * 0.72 }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.26))
                    .foregroundStyle(.white)
                    .frame(width: size, height: height)
                    .background(Color.brandCyan, in: RoundedRectangle(cornerRadius: size * 0.24))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appForeground)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Contacts Screen

/// Contactos tab: the device's own address book, listed alphabetically with a search bar —
/// each row gets two extra call buttons (collect call via `*99`, hidden-number call via `#31#`)
/// instead of a single generic "call" action, since that's the whole point of this screen.
struct ContactsListView: View {
    @State private var service = ContactsService()
    @State private var searchText = ""

    private var filteredContacts: [DeviceContact] {
        guard !searchText.isEmpty else { return service.contacts }
        return service.contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Contacts grouped by first letter of name, sorted A→Z — no side index strip, just
    /// section headers plus the search bar to narrow things down.
    private var groupedContacts: [(letter: String, contacts: [DeviceContact])] {
        let groups = Dictionary(grouping: filteredContacts) { contact in
            String(contact.name.prefix(1)).uppercased()
        }
        return groups.keys.sorted().map { letter in
            (letter, groups[letter]!.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if service.isDenied {
                    ContentUnavailableView(
                        "Sin Acceso a Contactos",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Actívalo en Ajustes del sistema › CubaCell Connect › Contactos.")
                    )
                } else if service.contacts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedContacts, id: \.letter) { group in
                            Section(group.letter) {
                                ForEach(group.contacts) { contact in
                                    ContactCallRowView(contact: contact)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Buscar")
                }
            }
            .navigationTitle("Contactos")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { service.loadIfNeeded() }
    }
}

/// One contact row: name + number, then a single round call button offering a choice between
/// hidden caller ID (`#31#`) and collect call (`*99`) — mirroring the old Llamada Privada /
/// Llamada por Cobrar codes, just applied directly to a picked contact instead of a manually
/// typed number.
private struct ContactCallRowView: View {
    let contact: DeviceContact

    @AppStorage("contactCallMode") private var modeRaw = ContactCallMode.separateButtons.rawValue
    private var mode: ContactCallMode { ContactCallMode(rawValue: modeRaw) ?? .separateButtons }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appForeground)
                Text(contact.phoneNumber)
                    .font(AppTheme.codeFont(size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            switch mode {
            case .separateButtons:
                Button {
                    DialService.dial("#31#\(contact.phoneNumber)")
                } label: {
                    anonymousButtonIcon
                }
                .accessibilityLabel("Llamar Anónimo")

                Button {
                    DialService.dial("*99\(contact.phoneNumber)")
                } label: {
                    collectButtonIcon
                }
                .accessibilityLabel("Llamar con 99")

            case .collectDefault:
                Button {
                    DialService.dial("*99\(contact.phoneNumber)")
                } label: {
                    collectButtonIcon
                }
                .accessibilityLabel("Llamar con 99")

            case .anonymousDefault:
                Button {
                    DialService.dial("#31#\(contact.phoneNumber)")
                } label: {
                    anonymousButtonIcon
                }
                .accessibilityLabel("Llamar Anónimo")
            }
        }
        .padding(.vertical, 2)
    }

    private var anonymousButtonIcon: some View {
        Image(systemName: "shield.lefthalf.filled")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Color.brandCyan, in: Circle())
    }

    private var collectButtonIcon: some View {
        HStack(spacing: 3) {
            Image(systemName: "phone.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("99")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(height: 32)
        .padding(.horizontal, 10)
        .background(Color.brandCyan, in: Capsule())
    }
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
    @State private var searchText = ""

    /// `category.groups`, narrowed to codes whose title or number matches the search text —
    /// empty groups are dropped so an unmatched group doesn't leave a bare header behind.
    private var filteredGroups: [USSDCodeGroup] {
        guard !searchText.isEmpty else { return category.groups }
        return category.groups.compactMap { group in
            let matches = group.codes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.code.localizedCaseInsensitiveContains(searchText)
            }
            guard !matches.isEmpty else { return nil }
            return USSDCodeGroup(name: group.name, codes: matches)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showNetworkStatus {
                    ConnectionBannerView()
                }

                List {
                    ForEach(filteredGroups) { group in
                        Section {
                            ForEach(group.codes) { code in
                                // Same compact row for anything with an icon, a price, or the
                                // explicit `compact` flag — an icon-less code still gets this row
                                // shape (just without a leading icon), not the old
                                // title+description+badge row.
                                if code.showsNumber == true {
                                    ContactRowView(code: code) { select(code) }
                                        .contentShape(Rectangle())
                                        .onTapGesture { select(code) }
                                } else if code.icon != nil || code.price != nil || code.compact == true {
                                    Button {
                                        select(code)
                                    } label: {
                                        HStack {
                                            if let icon = code.icon {
                                                Label(code.title, systemImage: icon)
                                            } else {
                                                Text(code.title)
                                            }
                                            if let price = code.price {
                                                Spacer()
                                                Text(price)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                } else {
                                    CodeRowView(code: code)
                                        .contentShape(Rectangle())
                                        .onTapGesture { select(code) }
                                }
                            }
                        } header: {
                            if let name = group.name {
                                Text(name)
                            } else {
                                // A little breathing room in place of a missing header, so an
                                // unnamed first section doesn't sit flush against the nav bar.
                                Color.clear.frame(height: 8)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .tint(.brandCyan)
                .searchable(text: $searchText, prompt: "Buscar")
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
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
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    PreferencesSettingsView()
                } label: {
                    Label("Preferencias", systemImage: "gearshape.fill")
                }

                NavigationLink {
                    HelpSettingsView()
                } label: {
                    Label("Ayuda", systemImage: "questionmark.circle.fill")
                }

                NavigationLink {
                    AboutSettingsView()
                } label: {
                    Label("Información", systemImage: "info.circle.fill")
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Ajustes › Preferencias — appearance and general behavior toggles.
private struct PreferencesSettingsView: View {
    @AppStorage("darkModePreference") private var darkMode: Int = 0
    @AppStorage("showNetworkStatus") private var showNetworkStatus = false
    @AppStorage("defaultTab") private var defaultTab = HomeTab.home.rawValue
    @AppStorage("contactCallMode") private var contactCallMode = ContactCallMode.separateButtons.rawValue

    var body: some View {
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

            Section {
                Picker("Pestaña Inicial", selection: $defaultTab) {
                    ForEach(HomeTab.allCases) { tab in
                        Text(tab.displayName).tag(tab.rawValue)
                    }
                }
            } header: {
                Text("Inicio")
            } footer: {
                Text("La pestaña que se muestra al abrir la app.")
            }

            Section {
                Picker("Llamada desde Contactos", selection: $contactCallMode) {
                    ForEach(ContactCallMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
            } header: {
                Text("Contactos")
            } footer: {
                Text("Cómo se llama a un contacto: con los dos botones a la vista, o directo por Anónimo o por 99.")
            }
        }
        .navigationTitle("Preferencias")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Ajustes › Ayuda — how USSD works, in plain language.
private struct HelpSettingsView: View {
    var body: some View {
        Form {
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
        }
        .navigationTitle("Ayuda")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Ajustes › Información — about the app, links, and version.
private struct AboutSettingsView: View {
    var body: some View {
        Form {
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
        .navigationTitle("Información")
        .navigationBarTitleDisplayMode(.inline)
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
