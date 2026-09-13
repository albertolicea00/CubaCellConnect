import SwiftUI
import UniformTypeIdentifiers

// MARK: - Home Screen

/// Root screen. Tab order is explicit (not a generic `ForEach` over every category) since Home
/// must sit in the middle, flanked by Contactos/Líneas de Ayuda on one side and Compras on the
/// other: Líneas de Ayuda, Contactos, Home, Compras, Ajustes.
struct HomeView: View {
    @Environment(USSDCodeStore.self) private var store
    @Environment(AccentColorStore.self) private var accentColorStore
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
        .tint(accentColorStore.color)
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
        .environment(AccentColorStore())
}

// MARK: - Home Quick Actions

/// The Home tab: one system `List` (same `.insetGrouped` style as every other tab), with
/// "Consultar Todo" and the balance shortcuts sharing a single "Saldo y Planes" section,
/// plus a "Transferir" and a "Recargar" section whose fields are plain rows, not a custom card.
struct HomeQuickActionsView: View {
    @Environment(USSDCodeStore.self) private var store
    @Environment(AccentColorStore.self) private var accentColorStore
    @AppStorage("showNetworkStatus") private var showNetworkStatus = false

    @State private var phoneNumber = ""
    @State private var pin = ""
    @State private var amount = ""
    @State private var cardNumber = ""
    @State private var showingContactPicker = false
    @State private var showsInvalidNumberWarning = false

    /// `true` while `pin` holds the value just loaded from `TransferPinStore` and not yet typed
    /// over by the user — drives whether the "Clave" field masks itself (see `PinRevealField`).
    @State private var pinIsFromStore = false
    /// Set right before assigning `pin` from the store so the `onChange(of: pin)` below can tell
    /// that mutation apart from the user actually typing, instead of immediately unmasking it.
    @State private var isLoadingStoredPin = false

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
                            PinRevealField(title: "Clave", text: $pin, isMasked: pinIsFromStore)
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
                .tint(accentColorStore.color)
                .sheet(isPresented: $showingContactPicker) {
                    ContactPickerView { number, isValidCubanNumber in
                        phoneNumber = number
                        showsInvalidNumberWarning = !isValidCubanNumber
                    }
                    .ignoresSafeArea()
                }
                .alert("Número no parece cubano", isPresented: $showsInvalidNumberWarning) {
                    Button("Entendido", role: .cancel) {}
                } message: {
                    Text("Este contacto no tiene un número con formato de móvil cubano (+53 y 8 dígitos). Revísalo antes de transferir.")
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if pin.isEmpty, let saved = TransferPinStore.load() {
                isLoadingStoredPin = true
                pin = saved
            }
        }
        .onChange(of: pin) {
            if isLoadingStoredPin {
                pinIsFromStore = true
                isLoadingStoredPin = false
            } else {
                pinIsFromStore = false
            }
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
        .environment(AccentColorStore())
}

/// A secondary/outline look: border and text in the tint color, no filled background —
/// unlike `.bordered`, which fills with a light tint. Used for the Adelanta Saldo amount buttons.
private struct OutlineButtonStyle: ButtonStyle {
    @Environment(AccentColorStore.self) private var accentColorStore

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 6)
            .foregroundStyle(accentColorStore.color)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(accentColorStore.color, lineWidth: 1.5)
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

    @Environment(AccentColorStore.self) private var accentColorStore

    /// Shorter than `size` so the tile reads as a rounded rectangle, not a square.
    private var height: CGFloat { size * 0.72 }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.26))
                    .foregroundStyle(.white)
                    .frame(width: size, height: height)
                    .background(accentColorStore.color, in: RoundedRectangle(cornerRadius: size * 0.24))
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
        return service.contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.phoneNumber.localizedCaseInsensitiveContains(searchText)
        }
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
                } else if !service.isLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if service.contacts.isEmpty {
                    ContentUnavailableView(
                        "Sin Contactos Cubanos",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("No se encontró ningún contacto con número cubano (+53, 8 dígitos).")
                    )
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
                    .searchDictationBehavior(.automatic)
                }
            }
            .navigationTitle("Contactos")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { service.loadIfNeeded() }
    }
}

/// One contact row: name + number. Swiping reveals a call action on each side — collect call
/// (`*99`) trailing, hidden caller ID (`#31#`) leading — and tapping the row opens a bottom
/// sheet with both choices, mirroring the old Llamada por Cobrar / Llamada Privada codes,
/// just applied directly to a picked contact instead of a manually typed number.
private struct ContactCallRowView: View {
    let contact: DeviceContact

    @Environment(AccentColorStore.self) private var accentColorStore
    @State private var showingCallOptions = false

    var body: some View {
        HStack(spacing: 12) {
            ContactAvatarView(contact: contact)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.appForeground)
                Text(contact.phoneNumber)
                    .font(AppTheme.codeFont(size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            showingCallOptions = true
        }
        .swipeActions(edge: .trailing) {
            Button {
                DialService.dial("*99\(contact.phoneNumber)")
            } label: {
                Label("Llamar 99", systemImage: "phone.fill")
            }
            .tint(accentColorStore.color)

            Button {
                DialService.dial("#31#\(contact.phoneNumber)")
            } label: {
                Label("Anónimo", systemImage: "shield.lefthalf.filled")
            }
            .tint(accentColorStore.color.opacity(0.6))
        }
        .sheet(isPresented: $showingCallOptions) {
            ContactCallOptionsSheet(contact: contact)
        }
    }
}

/// Round contact photo pulled from the device address book, falling back to the contact's
/// initials on a tinted circle when there's no photo.
private struct ContactAvatarView: View {
    let contact: DeviceContact
    var size: CGFloat = 40

    @Environment(AccentColorStore.self) private var accentColorStore

    private var initials: String {
        let words = contact.name.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var body: some View {
        Group {
            if let data = contact.thumbnailImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    accentColorStore.color.opacity(0.2)
                    Text(initials)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundStyle(accentColorStore.color)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// Bottom sheet shown when a contact row is tapped: call the contact (collect via `*99` or
/// hidden caller ID via `#31#`), or transfer balance to it — same Clave/Monto form as Home's
/// Transferir, just with the number already filled in from the contact.
private struct ContactCallOptionsSheet: View {
    let contact: DeviceContact

    @Environment(\.dismiss) private var dismiss
    @Environment(USSDCodeStore.self) private var store
    @Environment(AccentColorStore.self) private var accentColorStore

    @State private var pin = ""
    @State private var amount = ""

    /// Same store-vs-typed tracking as Home's Transferir — see `HomeQuickActionsView`.
    @State private var pinIsFromStore = false
    @State private var isLoadingStoredPin = false

    private var isTransferDisabled: Bool {
        pin.trimmingCharacters(in: .whitespaces).isEmpty
            || amount.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    ContactAvatarView(contact: contact, size: 64)

                    VStack(spacing: 4) {
                        Text(contact.name)
                            .font(.title2.weight(.semibold))
                        Text(contact.phoneNumber)
                            .font(AppTheme.codeFont(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)

                VStack(spacing: 10) {
                    Button {
                        DialService.dial("*99\(contact.phoneNumber)")
                        dismiss()
                    } label: {
                        Label("Llamar con *99", systemImage: "phone.fill")
                            .labelStyle(.titleAndIcon)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColorStore.color)

                    Button {
                        DialService.dial("#31#\(contact.phoneNumber)")
                        dismiss()
                    } label: {
                        Label("Llamar Anónimo", systemImage: "shield.lefthalf.filled")
                            .labelStyle(.titleAndIcon)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(accentColorStore.color)
                }
                .controlSize(.large)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .listSectionSpacing(6)

            Section("Transferir Saldo") {
                HStack(spacing: 12) {
                    PinRevealField(title: "Clave", text: $pin, isMasked: pinIsFromStore)
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
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if pin.isEmpty, let saved = TransferPinStore.load() {
                isLoadingStoredPin = true
                pin = saved
            }
        }
        .onChange(of: pin) {
            if isLoadingStoredPin {
                pinIsFromStore = true
                isLoadingStoredPin = false
            } else {
                pinIsFromStore = false
            }
        }
    }

    /// Composes `transfer-direct`'s `{phoneNumber}`/`{pin}`/`{amount}` placeholders — same as
    /// Home's Transferir, with the contact's number already supplied.
    private func dialTransfer() {
        guard let code = store.code(withId: "transfer-direct") else { return }
        let resolved = code.resolvedCode(with: ["phoneNumber": contact.phoneNumber, "pin": pin, "amount": amount])
        DialService.dial(resolved)
        dismiss()
    }
}

// MARK: - Category Screen

/// One tab's content: the codes belonging to a single category.
/// Tapping a row dials it directly — iOS itself confirms before the call is placed.
/// Codes that need an extra value (card number, phone number, ...) prompt for it first via an alert.
struct CategoryListView: View {
    let category: USSDCategory

    @Environment(AccentColorStore.self) private var accentColorStore
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
                .tint(accentColorStore.color)
                .searchable(text: $searchText, prompt: "Buscar")
                .searchDictationBehavior(.automatic)
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
    @Environment(AccentColorStore.self) private var accentColorStore

    @AppStorage("darkModePreference") private var darkMode: Int = 0
    @AppStorage("showNetworkStatus") private var showNetworkStatus = false
    @AppStorage("defaultTab") private var defaultTab = HomeTab.home.rawValue

    @State private var showingChangePin = false
    @State private var showingSavePin = false

    var body: some View {
        NavigationStack {
            List {
                Section("Preferencias") {
                    Picker("Tema", selection: $darkMode) {
                        Text("Por Defecto").tag(0)
                        Text("Claro").tag(1)
                        Text("Oscuro").tag(2)
                    }

                    Toggle("Aviso de señal celular", isOn: $showNetworkStatus)

                    Picker("Pestaña Inicial", selection: $defaultTab) {
                        ForEach(HomeTab.allCases) { tab in
                            Text(tab.displayName).tag(tab.rawValue)
                        }
                    }

                    ColorPicker(
                        "Color de Acento",
                        selection: Binding(
                            get: { accentColorStore.color },
                            set: { accentColorStore.color = $0 }
                        ),
                        supportsOpacity: false
                    )

                    if accentColorStore.color.hexString != Color.brandCyan.hexString {
                        Button("Restablecer Color por Defecto") {
                            accentColorStore.resetToDefault()
                        }
                    }
                }

                Section("Utilidades") {
                    NavigationLink {
                        DirectorySearchView()
                    } label: {
                        Label("Buscar en Directorio", systemImage: "magnifyingglass")
                    }

                    NavigationLink {
                        WifiRoomsProvinceListView()
                    } label: {
                        Label("Salas y Zonas WiFi", systemImage: "wifi")
                    }

                    NavigationLink {
                        SpeedTestView()
                    } label: {
                        Label("Medir Velocidad de Internet", systemImage: "speedometer")
                    }
                }

                Section("Clave de Transferencia") {
                    Button {
                        showingChangePin = true
                    } label: {
                        Label("Cambiar Clave", systemImage: "key.fill")
                    }

                    Button {
                        showingSavePin = true
                    } label: {
                        Label("Guardar Clave", systemImage: "lock.fill")
                    }
                }

                Section("Acerca de") {
                    NavigationLink {
                        HelpSettingsView()
                    } label: {
                        Label("Ayuda (Manual de Uso)", systemImage: "questionmark.circle.fill")
                    }

                    Text("CubaCell Connect da acceso rápido a los códigos USSD de servicio de ETECSA (Cubacel): saldo, compras, transferencias y otras utilidades, todo desde una app sin conexión y sin dependencias.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label("No está afiliada, avalada ni patrocinada por ETECSA. Los códigos pueden cambiar en cualquier momento a discreción del operador.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Link(destination: URL(string: "https://github.com/albertolicea00/cubacell-connect")!) {
                        Label("Código fuente en GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
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
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingChangePin) {
                ChangeTransferPinSheet()
            }
            .sheet(isPresented: $showingSavePin) {
                SavedTransferPinSheet()
            }
        }
    }
}

/// Ajustes › Buscar en Directorio — reverse number/name lookup over whichever directory database
/// file the user has copied into this app's Documents folder (Finder file sharing, or the
/// "Importar Base de Datos" picker below; the app never downloads or bundles it itself). Its
/// schema shape (v1/v2) is auto-detected from the file's own tables — see `DirectoryDatabase`.
struct DirectorySearchView: View {
    @State private var databaseFile: DirectoryDatabaseFile?
    @State private var hasSearchedForDatabase = false
    @State private var showingImporter = false
    @State private var isImporting = false
    @State private var importErrorMessage: String?

    @State private var numberQuery = ""
    @State private var nameQuery = ""
    @State private var results: [DirectoryEntry] = []
    @State private var isSearching = false

    /// Mirrors `DirectoryDatabase`'s own minimums so the empty-state message doesn't flash "sin
    /// resultados" while the user is still short of the threshold that would actually search.
    private var hasSearchableInput: Bool {
        numberQuery.trimmingCharacters(in: .whitespaces).count >= DirectoryDatabase.minimumNumberQueryLength
            || nameQuery.trimmingCharacters(in: .whitespaces).count >= DirectoryDatabase.minimumNameQueryLength
    }

    var body: some View {
        Group {
            if !hasSearchedForDatabase {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if databaseFile == nil {
                VStack(spacing: 20) {
                    // Never names v1/v2 here — whoever copies the file in may not know which
                    // shape it is either; the app detects that on its own from its tables.
                    ContentUnavailableView(
                        "Sin Base de Datos",
                        systemImage: "externaldrive.badge.questionmark",
                        description: Text("Descarga la base de datos o impórtala si ya la tienes en este dispositivo.")
                    )

                    if isImporting {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Importando… puede tardar varios minutos, no cierres la app.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                // No hay endpoint de descarga todavía — deshabilitado hasta tenerlo.
                            } label: {
                                Label("Descargar Base de Datos", systemImage: "arrow.down.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.brandCyan)
                            .disabled(true)

                            Button {
                                showingImporter = true
                            } label: {
                                Label("Importar Base de Datos", systemImage: "square.and.arrow.down.on.square")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.brandCyan)
                        }
                        .controlSize(.large)
                        .padding(.horizontal, 32)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.item]) { result in
                    importDatabase(from: result)
                }
                .alert(
                    "No se Pudo Importar",
                    isPresented: Binding(
                        get: { importErrorMessage != nil },
                        set: { if !$0 { importErrorMessage = nil } }
                    )
                ) {
                    Button("Entendido", role: .cancel) {}
                } message: {
                    Text(importErrorMessage ?? "")
                }
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Número", text: $numberQuery)
                                .keyboardType(.phonePad)
                            Text("Mínimo \(DirectoryDatabase.minimumNumberQueryLength) dígitos")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Name search intentionally disabled for privacy and security — see
                        // README. `nameQuery` stays "" forever; the rest of the code
                        // (DirectoryDatabase.search, hasSearchableInput) already supports it
                        // again just by uncommenting this field.
                        // VStack(alignment: .leading, spacing: 2) {
                        //     TextField("Nombre", text: $nameQuery)
                        //     Text("Mínimo \(DirectoryDatabase.minimumNameQueryLength) caracteres")
                        //         .font(.caption)
                        //         .foregroundStyle(.secondary)
                        // }
                    }

                    Section {
                        ForEach(results) { entry in
                            DirectoryEntryRowView(entry: entry)
                        }

                        if isSearching {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else if hasSearchableInput, results.isEmpty {
                            Text("Sin resultados")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Buscar en Directorio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !hasSearchedForDatabase else { return }
            databaseFile = DirectoryDatabase.discoverDatabase()
            hasSearchedForDatabase = true
        }
        .task(id: "\(numberQuery)|\(nameQuery)") {
            guard let file = databaseFile, hasSearchableInput else {
                isSearching = false
                results = []
                return
            }
            isSearching = true
            // Debounce: wait out a pause in typing before paying for a scan over a
            // multi-million-row table, and bail if a newer keystroke already superseded us.
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            let searchNumber = numberQuery
            let searchName = nameQuery
            let found = await Task.detached(priority: .userInitiated) {
                DirectoryDatabase.search(numberQuery: searchNumber, nameQuery: searchName, in: file)
            }.value

            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }

    /// Copies a file the user picked (Files app, iCloud Drive, "On My iPhone", …) into this app's
    /// Documents folder, then re-runs discovery — `DirectoryDatabase` doesn't care about the
    /// filename, only what tables the copy actually has, so an unrecognized file just leaves
    /// `databaseFile` nil instead of throwing here.
    /// These dumps are 400+MB — copying on the calling thread would block the UI for however
    /// long that takes (and risk the app being killed or force-quit mid-copy, leaving a truncated
    /// file `sqlite3` can't read). So the actual `copyItem` runs on a detached background task,
    /// and its result is checked against the source's byte size before trusting it — a size
    /// mismatch means an interrupted copy, not a bad file, so it's reported as that distinctly.
    private func importDatabase(from result: Result<URL, Error>) {
        guard case let .success(sourceURL) = result else { return }
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            importErrorMessage = "No se pudo acceder a los archivos de la app."
            return
        }
        let destinationURL = documents.appendingPathComponent(sourceURL.lastPathComponent)

        isImporting = true
        Task.detached(priority: .userInitiated) {
            let didAccess = sourceURL.startAccessingSecurityScopedResource()
            defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }

            do {
                let sourceSize = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

                let destinationSize = try FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int
                if let sourceSize, let destinationSize, sourceSize != destinationSize {
                    try? FileManager.default.removeItem(at: destinationURL)
                    await MainActor.run {
                        isImporting = false
                        importErrorMessage = "La copia no terminó (\(destinationSize) de \(sourceSize) bytes) — inténtalo de nuevo."
                    }
                    return
                }

                let discovered = DirectoryDatabase.discoverDatabase()
                // Temporary diagnostic: surface the real sqlite error/table names instead of a
                // generic message, since a copy that opens fine on a Mac has failed here before
                // for a reason `discoverDatabase()` alone doesn't report.
                let diagnosis = discovered == nil ? DirectoryDatabase.diagnose(at: destinationURL) : nil
                await MainActor.run {
                    databaseFile = discovered
                    isImporting = false
                    if discovered == nil {
                        importErrorMessage = "El archivo se copió pero no tiene el formato esperado de base de datos de directorio.\n\nDiagnóstico: \(diagnosis ?? "?")"
                    }
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importErrorMessage = "No se pudo copiar el archivo: \(error.localizedDescription)"
                }
            }
        }
    }
}

/// Bottom sheet opened from Ajustes' "Cambiar Clave de Transferencia" row: dials
/// `transfer-pin-change` (`*234*2*{current}*{new}#`). `.password`/`.newPassword` content types
/// so iOS also offers to save the new PIN to Passwords. On save, the new PIN is written to
/// `TransferPinStore` (the Keychain-backed store `SavedTransferPinSheet` manages directly) so it
/// stays in sync with what Transferir prefills.
private struct ChangeTransferPinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(USSDCodeStore.self) private var store

    @State private var currentPin = ""
    @State private var newPin = ""

    /// Blocks empty fields and a "new" PIN identical to the current one — changing to the same
    /// PIN isn't a change.
    private var isDisabled: Bool {
        currentPin.trimmingCharacters(in: .whitespaces).isEmpty
            || newPin.trimmingCharacters(in: .whitespaces).isEmpty
            || newPin == currentPin
    }

    /// Only flagged once both fields are filled in — an empty field is caught by `isDisabled`
    /// alone and doesn't need an explicit error.
    private var showsSamePinError: Bool {
        !currentPin.isEmpty && !newPin.isEmpty && newPin == currentPin
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        TextField("Clave actual", text: $currentPin)
                            .textContentType(.password)
                            .keyboardType(.numberPad)
                        Divider()
                        TextField("Clave nueva", text: $newPin)
                            .textContentType(.newPassword)
                            .keyboardType(.numberPad)
                    }
                } footer: {
                    if showsSamePinError {
                        Text("La clave nueva es igual a la actual.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Cambiar Clave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                        dismiss()
                    }
                    .disabled(isDisabled)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard let code = store.code(withId: "transfer-pin-change") else { return }
        let resolved = code.resolvedCode(with: ["current": currentPin, "new": newPin])
        DialService.dial(resolved)
        TransferPinStore.save(newPin)
    }
}

/// Bottom sheet opened from Ajustes' "Guardar Clave de Transferencia" row: persists the PIN to
/// the Keychain (see `TransferPinStore`) so Transferir's "Clave" field prefills itself on Home
/// and inside a contact's sheet, instead of asking the user to retype it every time.
private struct SavedTransferPinSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var isSaved = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PinRevealField(title: "Clave", text: $pin, isMasked: true)
                } footer: {
                    Text("Se guarda cifrada en el Llavero de este dispositivo (nunca sale de él) y se rellena sola en el campo Clave al transferir, tanto en Home como dentro de un contacto.")
                }

                if isSaved {
                    Section {
                        Button("Olvidar Clave Guardada", role: .destructive) {
                            TransferPinStore.delete()
                            pin = ""
                            isSaved = false
                        }
                    }
                }
            }
            .navigationTitle("Guardar Clave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        TransferPinStore.save(pin)
                        isSaved = true
                        dismiss()
                    }
                    .disabled(pin.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let stored = TransferPinStore.load() {
                pin = stored
                isSaved = true
            }
        }
    }
}

/// Ajustes › Preferencias — appearance and general behavior toggles.
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

            Section("Identificar Llamadas por Cobrar (*99)") {
                SettingsInfoRow(
                    title: "¿Por qué me llaman con un número raro?",
                    text: "El servicio *99 de ETECSA no oculta el número de quien llama — lo envuelve, y por eso el teléfono muestra una cadena larga en vez del contacto real."
                )
                SettingsInfoRow(
                    title: "Cómo activarlo",
                    text: "Ve a Ajustes del sistema › Teléfono › Bloqueo e Identificación de Llamadas y activa \"CallerID\". Es un paso manual de iOS — la app no puede activarlo sola. Solo identifica a quienes ya tienes en Contactos; una llamada anónima (#31#) nunca se puede identificar, porque el número real nunca llega al teléfono."
                )
            }
        }
        .navigationTitle("Ayuda")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One title + body row inside a Settings section.
private struct SettingsInfoRow: View {
    let title: String
    let text: String

    @Environment(AccentColorStore.self) private var accentColorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accentColorStore.color)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView()
        .environment(USSDCodeStore())
        .environment(AccentColorStore())
        .environment(WifiRoomsStore())
}

// MARK: - Wifi Navigation Rooms & Hotspots

/// Ajustes › Salas y Zonas WiFi — every Cuban province from ETECSA's own public "Navigation
/// rooms and public spaces (WIFI)" directory (`wifi_navigation_rooms.json`, scraped once from
/// https://www.etecsa.cu/en/rooms-public-spaces — see README for the exact source URLs). Picking
/// a province shows its navigation rooms (seat counts) and free WIFI hotspots by municipality.
struct WifiRoomsProvinceListView: View {
    @Environment(WifiRoomsStore.self) private var store

    var body: some View {
        List(store.provinces) { province in
            NavigationLink {
                WifiRoomsDetailView(province: province)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(province.province)
                        .font(.body.weight(.medium))
                    Text("\(province.rooms.count) salas de navegación · \(province.hotspots.reduce(0) { $0 + $1.spots.count }) zonas wifi")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Salas y Zonas WiFi")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WifiRoomsProvinceListView()
    }
    .environment(WifiRoomsStore())
}

/// One province's navigation rooms (paid, with seat counts) and free WIFI hotspots, grouped by
/// municipality and collapsed behind a `DisclosureGroup` since a big province can list 100+ spots.
struct WifiRoomsDetailView: View {
    let province: WifiProvince

    @Environment(AccentColorStore.self) private var accentColorStore
    @State private var searchText = ""

    private var filteredRooms: [WifiRoom] {
        guard !searchText.isEmpty else { return province.rooms }
        return province.rooms.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.address.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Municipality name match keeps the whole group; otherwise only its matching spots survive
    /// — a group with none is dropped entirely so an unmatched municipality doesn't leave an
    /// empty, pointless `DisclosureGroup` behind.
    private var filteredHotspotGroups: [WifiHotspotGroup] {
        guard !searchText.isEmpty else { return province.hotspots }
        return province.hotspots.compactMap { group in
            if group.municipality.localizedCaseInsensitiveContains(searchText) {
                return group
            }
            let matches = group.spots.filter { $0.localizedCaseInsensitiveContains(searchText) }
            guard !matches.isEmpty else { return nil }
            return WifiHotspotGroup(municipality: group.municipality, spots: matches)
        }
    }

    var body: some View {
        List {
            if !filteredRooms.isEmpty {
                Section("Salas de Navegación") {
                    ForEach(filteredRooms) { room in
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                if let positions = room.positions {
                                    Text("\(positions) puestos")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Text(room.name)
                                    .font(.body.weight(.medium))
                                if !room.address.isEmpty {
                                    Text(room.address)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                MapsService.openSearch(for: mapsQuery(name: room.name, address: room.address))
                            } label: {
                                Image(systemName: "map")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(accentColorStore.color)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !filteredHotspotGroups.isEmpty {
                Section("Zonas WiFi Públicas") {
                    ForEach(filteredHotspotGroups) { group in
                        DisclosureGroup {
                            ForEach(group.spots, id: \.self) { spot in
                                HStack {
                                    Text(spot)
                                        .font(.subheadline)
                                    Spacer()
                                    Button {
                                        MapsService.openSearch(for: mapsQuery(name: spot, address: group.municipality))
                                    } label: {
                                        Image(systemName: "map")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(accentColorStore.color)
                                }
                            }
                        } label: {
                            HStack {
                                Text(group.municipality)
                                Spacer()
                                Text("\(group.spots.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(province.province)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar sala o zona wifi")
    }

    /// "Name, address, Province, Cuba" (address falls back to just the province when ETECSA's
    /// listing didn't include a street address) — enough context for Maps to geocode a Cuban
    /// place it has no exact pin for.
    private func mapsQuery(name: String, address: String) -> String {
        let locality = address.isEmpty ? province.province : address
        return "\(name), \(locality), \(province.province), Cuba"
    }
}

#Preview {
    NavigationStack {
        WifiRoomsDetailView(province: WifiProvince(
            province: "Artemisa",
            rooms: [
                WifiRoom(name: "Multiservice Center Artemisa", address: "Calle 50 e/ 27 y 29", positions: 4),
                WifiRoom(name: "Youth Club Bauta III", address: "", positions: nil),
            ],
            hotspots: [
                WifiHotspotGroup(municipality: "Artemisa", spots: ["Park Las Cañas", "Boulevard"]),
            ]
        ))
    }
    .environment(AccentColorStore())
}

// MARK: - Speed Test

/// Ajustes › Prueba de Velocidad — ping/download/upload against Cloudflare's public speed-test
/// endpoints (see `SpeedTestRunner`). Works over any connection with internet access; not tied
/// to Cuban carriers or bundled data the way the rest of Ajustes is.
struct SpeedTestView: View {
    @Environment(AccentColorStore.self) private var accentColorStore
    @State private var runner = SpeedTestRunner()

    private var statusText: String {
        switch runner.phase {
        case .idle: return "Toca el botón para medir tu conexión."
        case .testingPing: return "Midiendo ping…"
        case .testingDownload: return "Midiendo velocidad de descarga…"
        case .testingUpload: return "Midiendo velocidad de subida…"
        case .finished: return "Prueba completada."
        case .failed(let message): return message
        }
    }

    /// What the needle/number track for the current phase — ping is milliseconds on a 0–300
    /// scale, download/upload are Mbps on a 0–150 scale (a reasonable ceiling for a home/mobile
    /// connection; a real reading past that just pins the needle at max, the number keeps going).
    private var gaugeMaxValue: Double {
        switch runner.phase {
        case .testingPing: return 300
        default: return 150
        }
    }

    private var gaugeUnit: String {
        switch runner.phase {
        case .testingPing: return "ms"
        case .testingDownload, .testingUpload: return "Mbps"
        default: return ""
        }
    }

    /// "Intento 3 de 5" under the number while pinging — download/upload already read as "doing
    /// something" from the number itself climbing live, ping's single small number doesn't.
    private var liveCaption: String? {
        guard case .testingPing = runner.phase else { return nil }
        return "Intento \(runner.pingAttempt) de 5"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    SpeedGaugeView(
                        value: runner.gaugeValue,
                        maxValue: gaugeMaxValue,
                        color: accentColorStore.color
                    )
                    .frame(width: 220, height: 130)

                    if runner.isRunning {
                        VStack(spacing: 2) {
                            Text(formattedGaugeValue)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                                .animation(.snappy, value: runner.gaugeValue)
                                .foregroundStyle(accentColorStore.color)
                            Text(gaugeUnit)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        if let liveCaption {
                            Text(liveCaption)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(.default, value: statusText)

                    if !runner.isRunning {
                        Button {
                            runner.start()
                        } label: {
                            Label(
                                isFinishedOrFailed ? "Repetir Prueba" : "Iniciar Prueba",
                                systemImage: "play.fill"
                            )
                            .labelStyle(.titleAndIcon)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentColorStore.color)
                        .controlSize(.large)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            if hasAnyResult {
                Section("Resultados") {
                    if let ping = runner.result.pingMs {
                        LabeledContent("Ping", value: String(format: "%.0f ms", ping))
                    }
                    if let download = runner.result.downloadMbps {
                        LabeledContent("Descarga", value: String(format: "%.1f Mbps", download))
                    }
                    if let upload = runner.result.uploadMbps {
                        LabeledContent("Subida", value: String(format: "%.1f Mbps", upload))
                    }
                }
            }
        }
        .navigationTitle("Prueba de Velocidad")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            runner.cancel()
        }
    }

    private var isFinishedOrFailed: Bool {
        switch runner.phase {
        case .finished, .failed: return true
        default: return false
        }
    }

    private var hasAnyResult: Bool {
        runner.result.pingMs != nil || runner.result.downloadMbps != nil || runner.result.uploadMbps != nil
    }

    private var formattedGaugeValue: String {
        switch runner.phase {
        case .testingPing: return String(format: "%.0f", runner.gaugeValue)
        default: return String(format: "%.1f", runner.gaugeValue)
        }
    }
}

/// A car-speedometer-style semicircular gauge: a needle that sweeps from left (0) to right
/// (`maxValue`) as `value` changes, animating smoothly between readings instead of jumping —
/// used by `SpeedTestView` to make a live ping/download/upload reading visibly "move" as it
/// updates, the way a real speed test's needle does.
private struct SpeedGaugeView: View {
    let value: Double
    let maxValue: Double
    let color: Color

    private var fraction: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }

    /// 0 = needle pointing straight up (the `rotationEffect` rest position); the needle itself
    /// is drawn vertical, pivoting from its bottom edge, so -90°/+90° swing it to the gauge's
    /// left/right ends.
    private var needleRotationDegrees: Double {
        -90 + fraction * 180
    }

    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width / 2, geometry.size.height)

            ZStack(alignment: .bottom) {
                Path { path in
                    path.addArc(
                        center: CGPoint(x: radius, y: radius),
                        radius: radius - 10,
                        startAngle: .degrees(180),
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                }
                .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: radius * 2, height: radius)

                Path { path in
                    path.addArc(
                        center: CGPoint(x: radius, y: radius),
                        radius: radius - 10,
                        startAngle: .degrees(180),
                        endAngle: .degrees(180 + fraction * 180),
                        clockwise: false
                    )
                }
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: radius * 2, height: radius)
                .animation(.easeOut(duration: 0.25), value: fraction)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4, height: radius - 22)
                    .rotationEffect(.degrees(needleRotationDegrees), anchor: .bottom)
                    .animation(.easeOut(duration: 0.25), value: needleRotationDegrees)

                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .offset(y: 6)
            }
            .frame(width: radius * 2, height: radius, alignment: .top)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    NavigationStack {
        SpeedTestView()
    }
    .environment(AccentColorStore())
}
