import CallKit
import Contacts
import CoreTelephony
import Foundation
import Security
import SQLite3
import SwiftUI
import UIKit

let AppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
let AppBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

// MARK: - Accent Color Store

/// The user's chosen accent color (Ajustes › Preferencias), used everywhere the app used to
/// hardcode `Color.brandCyan`. Persisted as a hex string in `UserDefaults` (`Color` itself isn't
/// storable there) and defaults to `brandCyan` until the user picks something else.
@Observable
final class AccentColorStore {
    private static let key = "accentColorHex"

    var color: Color {
        didSet {
            UserDefaults.standard.set(color.hexString, forKey: Self.key)
        }
    }

    init() {
        if let hex = UserDefaults.standard.string(forKey: Self.key), let saved = Color(hex: hex) {
            color = saved
        } else {
            color = .brandCyan
        }
    }

    /// Reverts to the app's default accent (`brandCyan`) — offered in Ajustes next to the picker.
    func resetToDefault() {
        color = .brandCyan
    }
}

// MARK: - Wifi Rooms Store

/// Loads the bundled `wifi_navigation_rooms.json` (ETECSA's public navigation-room/hotspot
/// directory, one entry per province) once at init — same "load once, read-only" shape as
/// `USSDCodeStore`.
@Observable
final class WifiRoomsStore {
    private(set) var provinces: [WifiProvince] = []

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "wifi_navigation_rooms", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([WifiProvince].self, from: data)
        else {
            assertionFailure("Failed to load wifi_navigation_rooms.json from the app bundle")
            return
        }
        provinces = decoded
    }
}

// MARK: - Catalog Store

/// Loads and exposes the bundled USSD code catalog. Categories carry their own groups and
/// codes (see `USSDCategory`/`USSDCodeGroup`), so no separate flat lookup is needed here.
@Observable
final class USSDCodeStore {
    private(set) var categories: [USSDCategory] = []
    private(set) var carrier: String = ""

    /// Categories shown as their own tab — everything except the `home` category, which the
    /// Home screen renders itself (a custom layout, not a plain code list).
    var tabCategories: [USSDCategory] {
        categories.filter { $0.id != "home" }
    }

    init(bundle: Bundle = .main) {
        load(from: bundle)
    }

    /// Looks up one code by id anywhere in the catalog, regardless of which category/group holds it.
    /// Used by the Home screen to pull specific codes (main balance, transfer, recharge) into its
    /// own custom layout instead of a generic list.
    func code(withId id: String) -> USSDCode? {
        for category in categories {
            for group in category.groups {
                if let match = group.codes.first(where: { $0.id == id }) {
                    return match
                }
            }
        }
        return nil
    }

    /// Looks up a named group anywhere in the catalog — e.g. Home's "Servicio Adelanta Saldo" —
    /// so a custom layout can pull its title and codes (price, title, ...) from the catalog
    /// instead of hardcoding them in the view.
    func group(named name: String) -> USSDCodeGroup? {
        for category in categories {
            if let match = category.groups.first(where: { $0.name == name }) {
                return match
            }
        }
        return nil
    }

    private func load(from bundle: Bundle) {
        guard let url = bundle.url(forResource: "codes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(USSDCatalog.self, from: data)
        else {
            assertionFailure("Failed to load codes.json from the app bundle")
            return
        }
        categories = catalog.categories
        carrier = catalog.carrier
    }
}

// MARK: - Cellular Signal Monitor

/// Tracks the device's current radio access technology so the UI can warn before a USSD
/// code is dialed with no/weak signal — USSD needs voice-network reachability, not data or Wi-Fi.
@Observable
final class CellularMonitor {
    static let shared = CellularMonitor()

    private let telephonyInfo = CTTelephonyNetworkInfo()

    private(set) var hasService = false
    /// User-facing network type label, e.g. "4G / LTE". Spanish since it is shown in the UI.
    private(set) var networkType = "Buscando red..."
    /// 0 (no service) through 3 (best).
    private(set) var signalQuality = 0

    private init() {
        updateStatus()
        NotificationCenter.default.addObserver(
            forName: .CTServiceRadioAccessTechnologyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatus()
        }
    }

    private func updateStatus() {
        guard let techByService = telephonyInfo.serviceCurrentRadioAccessTechnology,
              let tech = techByService.values.first, !tech.isEmpty
        else {
            hasService = false
            networkType = "Sin servicio celular"
            signalQuality = 0
            return
        }

        hasService = true
        switch tech {
        case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA:
            networkType = "5G"
            signalQuality = 3
        case CTRadioAccessTechnologyLTE:
            networkType = "4G / LTE"
            signalQuality = 3
        case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMA1x, CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            networkType = "3G"
            signalQuality = 2
        case CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyGPRS:
            networkType = "2G / EDGE"
            signalQuality = 1
        default:
            networkType = "Red celular"
            signalQuality = 2
        }
    }
}

// MARK: - Speed Test

/// The three phases a run passes through, in order, plus the terminal states.
enum SpeedTestPhase {
    case idle
    case testingPing
    case testingDownload
    case testingUpload
    case finished
    case failed(String)
}

/// Results filled in as each phase completes — `nil` means "not measured yet", not "measured
/// zero", so the results section only shows rows for what has actually finished.
struct SpeedTestResult {
    var pingMs: Double?
    var downloadMbps: Double?
    var uploadMbps: Double?
}

/// Runs a basic internet speed test (ping, download, upload) against Cloudflare's public,
/// no-API-key speed-test endpoints (the same ones behind speed.cloudflare.com) — there is no
/// ETECSA-run equivalent, and this needs a real server round-trip either way, not bundled data.
/// Cellular-only in practice since that's this app's whole context, but works over Wi-Fi too;
/// nothing here is Cuba-specific.
@Observable
final class SpeedTestRunner {
    private(set) var phase: SpeedTestPhase = .idle
    private(set) var result = SpeedTestResult()

    var isRunning: Bool {
        switch phase {
        case .testingPing, .testingDownload, .testingUpload: return true
        case .idle, .finished, .failed: return false
        }
    }

    /// No-op while a run is already in flight — button that triggers this is hidden during a
    /// run anyway, but this guards direct callers too.
    func start() {
        guard !isRunning else { return }
        result = SpeedTestResult()
        Task { await run() }
    }

    @MainActor
    private func run() async {
        do {
            phase = .testingPing
            result.pingMs = try await Self.measurePing()

            phase = .testingDownload
            result.downloadMbps = try await Self.measureDownload()

            phase = .testingUpload
            result.uploadMbps = try await Self.measureUpload()

            phase = .finished
        } catch {
            phase = .failed("No se pudo completar la prueba. Revisa tu conexión e inténtalo de nuevo.")
        }
    }

    /// Median round-trip time of a handful of zero-byte requests — rough (a real speed test
    /// warms up the connection first), but good enough for "is this laggy or not".
    private static func measurePing() async throws -> Double {
        let url = URL(string: "https://speed.cloudflare.com/__down?bytes=0")!
        var samples: [Double] = []
        for _ in 0..<5 {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let start = Date()
            _ = try await URLSession.shared.data(for: request)
            samples.append(Date().timeIntervalSince(start) * 1000)
        }
        samples.sort()
        return samples[samples.count / 2]
    }

    private static func measureDownload() async throws -> Double {
        let byteCount = 25_000_000
        var request = URLRequest(url: URL(string: "https://speed.cloudflare.com/__down?bytes=\(byteCount)")!)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let start = Date()
        let (data, _) = try await URLSession.shared.data(for: request)
        let elapsed = Date().timeIntervalSince(start)

        return megabits(forByteCount: data.count, elapsed: elapsed)
    }

    private static func measureUpload() async throws -> Double {
        let byteCount = 10_000_000
        var request = URLRequest(url: URL(string: "https://speed.cloudflare.com/__up")!)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let payload = Data(count: byteCount)

        let start = Date()
        _ = try await URLSession.shared.upload(for: request, from: payload)
        let elapsed = Date().timeIntervalSince(start)

        return megabits(forByteCount: byteCount, elapsed: elapsed)
    }

    private static func megabits(forByteCount byteCount: Int, elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return 0 }
        return (Double(byteCount) * 8 / 1_000_000) / elapsed
    }
}

// MARK: - Device Contacts

/// One entry from the device address book: just enough to list and dial it. Uses the first
/// phone number on the contact — contacts with several numbers only show that one.
struct DeviceContact: Identifiable, Hashable {
    let id: String
    let name: String
    let phoneNumber: String
    let thumbnailImageData: Data?
}

/// Reads the full address book so the Contactos tab can render its own alphabetical list
/// instead of the one-at-a-time system picker used in Transferir. This needs full Contacts
/// access (`NSContactsUsageDescription`), unlike `ContactPickerView`, which needs no permission
/// at all since it runs out-of-process.
@Observable
final class ContactsService {
    private(set) var contacts: [DeviceContact] = []
    private(set) var isDenied = false
    /// True once the initial fetch has completed (with or without results) — lets the view tell
    /// "still loading" apart from "loaded, but no Cuban numbers found", which would otherwise
    /// both look like an empty `contacts` array and spin the loading indicator forever.
    private(set) var isLoaded = false

    private let store = CNContactStore()
    private var hasLoaded = false

    /// Requests access (once) and loads contacts. Safe to call from `onAppear` repeatedly.
    func loadIfNeeded() {
        guard !hasLoaded else { return }

        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            hasLoaded = true
            fetch()
        case .notDetermined:
            hasLoaded = true
            store.requestAccess(for: .contacts) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        self?.fetch()
                    } else {
                        self?.isDenied = true
                    }
                }
            }
        default:
            hasLoaded = true
            isDenied = true
        }
    }

    private func fetch() {
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName

        DispatchQueue.global(qos: .userInitiated).async { [store] in
            var results: [DeviceContact] = []
            try? store.enumerateContacts(with: request) { contact, _ in
                // Skip contacts with no Cuban mobile number at all, even if a different
                // (foreign) number is listed first — only Cuban numbers matter for USSD.
                guard let cubanNumber = contact.phoneNumbers.lazy
                    .compactMap({ CubanPhoneNumber.normalize($0.value.stringValue) })
                    .first
                else { return }
                let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "Sin nombre"
                results.append(DeviceContact(
                    id: contact.identifier,
                    name: name,
                    phoneNumber: cubanNumber,
                    thumbnailImageData: contact.thumbnailImageData
                ))
            }
            let sorted = results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            Self.syncCallerIDExtension(with: sorted)
            DispatchQueue.main.async { [weak self] in
                self?.contacts = sorted
                self?.isLoaded = true
            }
        }
    }

    /// Rebuilds the `*99` collect-call caller-ID list (see `CallerIDStore`) from the freshly
    /// fetched contacts and asks CallKit to reload `CallerIDExtension` with it. No-op if the
    /// user has never enabled the extension in Ajustes del sistema — `reloadExtension` still
    /// completes, CallKit just has nothing enabled to feed.
    private static func syncCallerIDExtension(with contacts: [DeviceContact]) {
        let entries = contacts.compactMap { contact -> CallerIDEntry? in
            guard let wrapped = CallerIDStore.wrappedNumber(forLocalNumber: contact.phoneNumber) else { return nil }
            return CallerIDEntry(wrappedNumber: wrapped, name: contact.name)
        }
        CallerIDStore.write(entries)
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: CallerIDStore.extensionBundleID) { _ in }
    }
}

// MARK: - Dial Service

/// Opens the system dialer with a USSD sequence or phone number.
enum DialService {
    /// Builds a `tel://` URL for the given code.
    /// `#` must be percent-encoded or the URL is rejected by iOS.
    static func dialURL(for rawCode: String) -> URL? {
        let encoded = rawCode
            .replacingOccurrences(of: "#", with: "%23")
            .replacingOccurrences(of: " ", with: "")
        return URL(string: "tel://\(encoded)")
    }

    /// Hands the code to the system dialer. Returns false when the device
    /// cannot place calls (e.g. iPad, simulator).
    @discardableResult
    static func dial(_ rawCode: String) -> Bool {
        guard let url = dialURL(for: rawCode), UIApplication.shared.canOpenURL(url) else {
            return false
        }
        UIApplication.shared.open(url)
        return true
    }
}

// MARK: - Maps Service

/// Opens the system Maps app as a place *search*, not a pin at known coordinates — ETECSA's
/// navigation-room/hotspot data only gives names and (sometimes) street addresses, never lat/lng,
/// so a search query is the only thing that makes sense here.
enum MapsService {
    /// Hands a free-text query to Apple Maps. Falls back to a Google Maps search URL if Maps
    /// itself can't be opened (e.g. no Maps app), since that URL works in any browser too.
    static func openSearch(for query: String) {
        var appleComponents = URLComponents(string: "https://maps.apple.com/")!
        appleComponents.queryItems = [URLQueryItem(name: "q", value: query)]
        if let appleURL = appleComponents.url, UIApplication.shared.canOpenURL(appleURL) {
            UIApplication.shared.open(appleURL)
            return
        }

        var googleComponents = URLComponents(string: "https://www.google.com/maps/search/")!
        googleComponents.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: query)]
        guard let googleURL = googleComponents.url else { return }
        UIApplication.shared.open(googleURL)
    }
}

// MARK: - Transfer PIN Store

/// Persists the user's transfer PIN in the device Keychain — encrypted at rest by iOS,
/// `.whenUnlockedThisDeviceOnly` so it never leaves this device (no iCloud sync, no backup) —
/// so the "Clave" field in Transferir (Home and inside a contact) can prefill itself instead of
/// asking the user to retype it every time.
enum TransferPinStore {
    private static let service = "com.cubacellconnect.transferpin"
    private static let account = "transferPin"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// Replaces (or clears, for an empty string) the stored PIN.
    static func save(_ pin: String) {
        SecItemDelete(query as CFDictionary)
        guard !pin.isEmpty, let data = pin.data(using: .utf8) else { return }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load() -> String? {
        var attributes = query
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(attributes as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Directory Database

/// The two schema shapes the on-device Truecaller-style dump can come in — detected from the
/// file's own tables (see `DirectoryDatabase.discoverDatabase`), never from its filename or a
/// user choice: whoever copies the file in via Finder names it whatever they want, and may not
/// know themselves which shape it is.
enum DirectoryDatabaseVersion {
    case v1
    case v2
}

/// A `.db` file found in the app's Documents folder with its schema already identified.
struct DirectoryDatabaseFile {
    let url: URL
    let version: DirectoryDatabaseVersion
}

/// One directory match: a number and the name it resolves to (blank for a few `fix` rows that
/// carry no name in the source dump).
struct DirectoryEntry: Identifiable, Hashable {
    var id: String { number }
    let number: String
    let name: String
}

/// Reverse number/name lookup over a Truecaller-style dump the user drops into this app's
/// Documents folder via Finder file sharing (`UIFileSharingEnabled`) — the app never bundles or
/// downloads it, and doesn't assume a filename or ask which schema it is. v1 is a single
/// `contacts(number, name, is_mobile)` table; v2 splits landline and mobile into separate
/// `fix(number, name)` / `movil(number, name)` tables — `discoverDatabase` tells them apart by
/// querying `sqlite_master` for the table names each shape actually has. Both dumps are 400+MB
/// with millions of rows and only `name` is indexed, so a name search is a full table scan:
/// callers must run `search` off the main thread and keep queries short (it refuses under 3
/// characters) to bound how bad that scan gets.
enum DirectoryDatabase {
    private static let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Opens `url` via the `file:...?immutable=1` URI form instead of a plain path. Plain
    /// `SQLITE_OPEN_READONLY` still has SQLite take a shared lock and probe for a hot journal on
    /// first real access — inside the iOS sandbox that first access can fail with
    /// `SQLITE_CANTOPEN` ("unable to open database file") even though the file itself opens and
    /// reads fine at the raw POSIX level (confirmed: a plain `FileHandle` read of the same file
    /// succeeds where `sqlite3_prepare_v2` didn't). `immutable=1` tells SQLite the file will never
    /// change while open, so it skips locking and the journal probe entirely — the standard fix
    /// for a bundled/copied read-only database on iOS.
    private static func open(_ url: URL) -> OpaquePointer? {
        var components = URLComponents()
        components.scheme = "file"
        components.path = url.path
        components.queryItems = [URLQueryItem(name: "immutable", value: "1")]
        guard let uri = components.url?.absoluteString else { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }
            return nil
        }
        return db
    }

    /// Scans Documents for any `.db` file and opens each just long enough to read its table
    /// names, returning the first one that matches a known shape (sorted by filename, for
    /// determinism when more than one is present). `nil` if Documents has no recognizable file.
    static func discoverDatabase() -> DirectoryDatabaseFile? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let candidates = try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)
        else { return nil }

        let dbFiles = candidates
            .filter { $0.pathExtension.lowercased() == "db" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        for url in dbFiles {
            if let version = detectVersion(at: url) {
                return DirectoryDatabaseFile(url: url, version: version)
            }
        }
        return nil
    }

    /// Opens `url` read-only and checks `sqlite_master` for the table names that identify each
    /// schema shape. `nil` if it's neither (not a directory dump, or an unrelated `.db` file).
    private static func detectVersion(at url: URL) -> DirectoryDatabaseVersion? {
        guard let db = open(url) else { return nil }
        defer { sqlite3_close(db) }

        let tables = tableNames(db: db)
        if tables.contains("contacts") { return .v1 }
        if tables.contains("movil") || tables.contains("fix") { return .v2 }
        return nil
    }

    private static func tableNames(db: OpaquePointer) -> Set<String> {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type = 'table';", -1, &statement, nil) == SQLITE_OK,
              let statement
        else { return [] }
        defer { sqlite3_finalize(statement) }

        var names: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                names.insert(String(cString: cString))
            }
        }
        return names
    }

    /// Diagnostic twin of `detectVersion` that returns *why* a file wasn't recognized instead of
    /// just `nil` — the real `sqlite3_open`/`sqlite3_prepare` error, or the actual table names
    /// found, so a report of "wrong format" on a file that opens fine on a Mac can be traced
    /// instead of guessed at. Not on the normal discovery path (that one only needs yes/no).
    static func diagnose(at url: URL) -> String {
        var lines: [String] = []

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes?[.size] as? Int
        let posixPermissions = attributes?[.posixPermissions] as? Int
        let protectionType = attributes?[.protectionKey] as? FileProtectionType
        lines.append("exists=\(FileManager.default.fileExists(atPath: url.path)) size=\(size.map(String.init) ?? "?") posix=\(posixPermissions.map { String($0, radix: 8) } ?? "?") protection=\(protectionType.map(String.init(describing:)) ?? "?")")
        lines.append("isReadableFile=\(FileManager.default.isReadableFile(atPath: url.path))")

        // Bypass SQLite entirely: read the first 16 bytes at the raw Foundation/POSIX level to
        // tell "SQLite specifically can't open this" apart from "nothing can read this file
        // right now" (e.g. Data Protection locked, or the file provider never materialized it).
        if let handle = FileHandle(forReadingAtPath: url.path) {
            let header = handle.readData(ofLength: 16)
            try? handle.close()
            let headerString = String(data: header, encoding: .ascii) ?? "?"
            lines.append("raw header read OK, \(header.count) bytes: \"\(headerString)\"")
        } else {
            lines.append("raw FileHandle open FAILED (OS-level read denied, not an SQLite-specific issue)")
        }

        guard let db = open(url) else {
            lines.append("sqlite3_open (immutable URI) failed")
            return lines.joined(separator: "\n")
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type = 'table';", -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            lines.append("sqlite3_prepare failed (code \(prepareResult)): \(String(cString: sqlite3_errmsg(db)))")
            return lines.joined(separator: "\n")
        }
        defer { sqlite3_finalize(statement) }

        var names: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                names.append(String(cString: cString))
            }
        }
        lines.append(
            names.isEmpty
                ? "opened fine but sqlite_master has no tables"
                : "opened fine, tables found: \(names.joined(separator: ", ")) — none match the expected v1/v2 shape"
        )
        return lines.joined(separator: "\n")
    }

    /// Separate number/name inputs instead of one combined field: a number search is a prefix
    /// match that rides `number`'s index (cheap even for a 1-digit prefix, since `LIMIT` stops
    /// the index range scan early); a name search is `LIKE '%x%'`, which can't use any index and
    /// is a genuine full-table scan. Filling both ANDs them — SQLite narrows via the number index
    /// first and only checks `name` against that already-small result set, so it stays cheap.
    /// A name-only search below 3 characters is refused (an unbounded scan for near-zero signal);
    /// a number-only search has no minimum since the index bounds its cost regardless of length.
    /// Synchronous and potentially slow (see type-level note) — call from a background task.
    static func search(numberQuery: String, nameQuery: String, in file: DirectoryDatabaseFile, limit: Int32 = 100) -> [DirectoryEntry] {
        let number = numberQuery.trimmingCharacters(in: .whitespaces)
        let name = nameQuery.trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty || !name.isEmpty else { return [] }
        guard !number.isEmpty || name.count >= 3 else { return [] }

        guard let db = open(file.url) else { return [] }
        defer { sqlite3_close(db) }

        var clauses: [String] = []
        var patterns: [String] = []
        if !number.isEmpty {
            clauses.append("number LIKE ?")
            patterns.append("\(number)%")
        }
        if !name.isEmpty {
            clauses.append("name LIKE ?")
            patterns.append("%\(name)%")
        }
        let whereClause = clauses.joined(separator: " AND ")

        switch file.version {
        case .v1:
            return rows(db: db, table: "contacts", whereClause: whereClause, patterns: patterns, limit: limit)
        case .v2:
            let mobile = rows(db: db, table: "movil", whereClause: whereClause, patterns: patterns, limit: limit)
            guard mobile.count < limit else { return mobile }
            let landline = rows(
                db: db,
                table: "fix",
                whereClause: whereClause,
                patterns: patterns,
                limit: limit - Int32(mobile.count)
            )
            return mobile + landline
        }
    }

    private static func rows(
        db: OpaquePointer,
        table: String,
        whereClause: String,
        patterns: [String],
        limit: Int32
    ) -> [DirectoryEntry] {
        let sql = "SELECT number, name FROM \(table) WHERE \(whereClause) LIMIT ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        for (index, pattern) in patterns.enumerated() {
            sqlite3_bind_text(statement, Int32(index) + 1, pattern, -1, transientDestructor)
        }
        sqlite3_bind_int(statement, Int32(patterns.count) + 1, limit)

        var results: [DirectoryEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let numberCString = sqlite3_column_text(statement, 0) else { continue }
            let name = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            results.append(DirectoryEntry(number: String(cString: numberCString), name: name))
        }
        return results
    }
}
