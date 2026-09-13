import CoreTelephony
import Foundation
import UIKit

let AppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
let AppBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

// MARK: - Catalog Store

/// Loads and exposes the bundled USSD code catalog.
@Observable
final class USSDCodeStore {
    private(set) var categories: [USSDCategory] = []
    private(set) var codes: [USSDCode] = []
    private(set) var carrier: String = ""

    init(bundle: Bundle = .main) {
        load(from: bundle)
    }

    func codes(in category: USSDCategory) -> [USSDCode] {
        codes.filter { $0.category == category.id }
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
        codes = catalog.codes
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
