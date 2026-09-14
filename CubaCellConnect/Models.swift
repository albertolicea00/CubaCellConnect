import Foundation
import SwiftUI

// MARK: - Catalog Models

/// How a code is executed on the device.
enum USSDActionType: String, Codable {
    /// Dialed as a USSD sequence (e.g. *222#).
    case ussd
    /// A regular phone call (e.g. *2266).
    case call
    /// Sent as an SMS — `code` is the destination number, `smsBody` the message text (e.g.
    /// "ayuda" to *2266) — opens the system SMS compose sheet prefilled, it isn't sent silently.
    case sms
}

/// A single ETECSA (Cubacel) service code. Its category and group are implied by where it sits
/// in the catalog's nested JSON — a code carries no category/group tag of its own.
struct USSDCode: Identifiable, Codable, Hashable {
    let id: String
    /// Raw code. May contain the `{input}` placeholder when user input is required.
    let code: String
    let title: String
    let details: String
    /// SF Symbol name. When present, the row renders as an icon + title (no description) like
    /// the Home quick actions; when nil, it renders as the default title + description row.
    let icon: String?
    /// Price tag shown trailing in the row, e.g. "$25.00". Nil for codes with no fixed price.
    let price: String?
    /// Forces the compact icon-row layout (title only, no description) even with no icon or
    /// price — for actions whose title alone is self-explanatory.
    let compact: Bool?
    /// Renders as a contact-book row instead: icon, title + the raw number, and a call button.
    /// Used for phone directories (Teléfonos) where seeing the actual number is the point.
    let showsNumber: Bool?
    let type: USSDActionType
    let requiresInput: Bool
    let inputPlaceholder: String?
    /// Alternate dial string that auto-selects ETECSA's confirmation step (e.g. `*133*1*4*1#` →
    /// `*133*1*4*1*1#`) so the purchase executes in one shot instead of stopping at the "¿Confirma
    /// su compra? 1. Sí" USSD reply menu. Nil for codes with no confirmation step to skip — dialing
    /// always falls back to `code` when this is nil.
    let noConfirmCode: String?
    /// For `type == .sms`: the message text to send to `code` (the destination number). May
    /// contain the `{input}` placeholder, same convention as `code` itself (e.g. an SMS that
    /// texts back the phone's IMEI, or a MMS-config text made of the first 9 digits of an email).
    let smsBody: String?
    /// For `type == .sms` codes with a fixed set of valid message texts (e.g. "Frases y Poemas" —
    /// texting one of ~35 topic words to 8888 gets a phrase back for that topic). When present,
    /// the row opens a picker listing these instead of dialing/composing directly; picking one is
    /// substituted into `smsBody`'s `{input}` token same as typed input would be (e.g. "Recetas"
    /// picks "BATIDOS" → sends "RECETA BATIDOS"). Nil for every other code.
    let options: [String]?
    /// Marks an ongoing subscription (e.g. "Martí" via 8100) as opposed to a one-off query — shown
    /// as a small "Suscripción" badge next to the title. Nil/false for everything else.
    let isSubscription: Bool?

    /// Code with the given named placeholders substituted in — each dictionary key `name`
    /// replaces a `{name}` token in `code`. Used by multi-field actions like the Home transfer card.
    func resolvedCode(with values: [String: String]) -> String {
        values.reduce(code) { partial, entry in
            partial.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
        }
    }

    /// Convenience for the common single-placeholder case (`{input}`).
    func resolvedCode(input: String = "") -> String {
        resolvedCode(with: ["input": input])
    }

    /// `smsBody` with the given named placeholders substituted in — mirrors `resolvedCode(with:)`
    /// but for the SMS message text instead of the dial string.
    func resolvedSMSBody(with values: [String: String]) -> String {
        values.reduce(smsBody ?? "") { partial, entry in
            partial.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
        }
    }

    /// Convenience for the common single-placeholder case (`{input}`).
    func resolvedSMSBody(input: String = "") -> String {
        resolvedSMSBody(with: ["input": input])
    }
}

/// A named sub-heading of codes within a category's list, e.g. "Datos", "SMS", "Voz" inside
/// Compras y Recargas. `name` is nil for a category with no sub-grouping, and renders with no header.
struct USSDCodeGroup: Identifiable, Codable, Hashable {
    var id: String { name ?? "_" }
    let name: String?
    let codes: [USSDCode]
}

/// A category of related service codes, shown as one tab.
struct USSDCategory: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    /// SF Symbol name used in the UI.
    let icon: String
    let groups: [USSDCodeGroup]
}

/// Root shape of the bundled `codes.json` catalog.
struct USSDCatalog: Codable {
    let version: Int
    let carrier: String
    let categories: [USSDCategory]
}

// MARK: - Cuban Phone Numbers

/// The one place that knows what a "valid Cuban mobile number" looks like — used by
/// `ContactsService` (filtering the Contactos tab) and `ContactPickerView` (validating a
/// contact picked for Transferir), so the rule only needs to change in one spot.
enum CubanPhoneNumber {
    /// Leading digit(s) a valid Cuban mobile number starts with, after the country code is
    /// stripped. Currently "5" or "6" (broad — covers today's ETECSA mobile ranges); narrow
    /// this to specific prefixes later (e.g. `["60", "61", "64"]` instead of `"6"`) if only
    /// some ranges under 6 turn out to be mobile — `hasPrefix` matching means any length works.
    static let validMobilePrefixes = ["5", "6"]

    /// Strips formatting to bare digits, then accepts either the bare 8-digit local form or
    /// `+53` plus 8 digits — stripping the country code down to those 8 digits (e.g.
    /// "+53 5 123 4567" → "51234567") — and checks the result starts with an allowed prefix.
    /// Returns `nil` for anything else (a US `+1`, a Mexican `+52`, a malformed number, a Cuban
    /// landline prefix, ...).
    static func normalize(_ rawNumber: String) -> String? {
        let digits = rawNumber.filter { $0.isASCII && $0.isNumber }

        let localNumber: String
        if digits.count == 8 {
            localNumber = digits
        } else if digits.count == 10, digits.hasPrefix("53") {
            localNumber = String(digits.dropFirst(2))
        } else {
            return nil
        }

        guard validMobilePrefixes.contains(where: localNumber.hasPrefix) else { return nil }
        return localNumber
    }
}

// MARK: - Brand Palette

extension Color {
    /// rgb(0, 0, 102) — primary brand color.
    static let brandNavy = Color(red: 0 / 255, green: 0 / 255, blue: 102 / 255)
    /// #09C — the app's default accent color. The user can override this in Ajustes ›
    /// Preferencias (see `AccentColorStore`); this constant is only the fallback/default value.
    static let brandCyan = Color(red: 0 / 255, green: 153 / 255, blue: 204 / 255)
    /// Adaptive background: white in light mode, black in dark mode.
    static let appBackground = Color(UIColor.systemBackground)
    /// Adaptive foreground: black in light mode, white in dark mode.
    static let appForeground = Color(UIColor.label)

    /// Builds an opaque color from a 6-digit "RRGGBB" hex string (an optional leading "#" is
    /// stripped). Returns `nil` for anything else — used to round-trip the user's chosen accent
    /// color through `@AppStorage`/`UserDefaults`, which can't store `Color` directly.
    init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Inverse of `init?(hex:)` — the "RRGGBB" hex string for this color's RGB components
    /// (alpha is dropped; every use in this app is opaque). Falls back to `brandCyan`'s hex if
    /// the color can't be converted to RGB (should not happen for any color `ColorPicker` hands
    /// back).
    var hexString: String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return "0099CC" }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

enum AppTheme {
    /// Monospaced style used to display dialable codes.
    static func codeFont(size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

// MARK: - Wifi Navigation Rooms & Hotspots

/// One province's data from ETECSA's public "Navigation rooms and public spaces (WIFI)"
/// directory (`wifi_navigation_rooms.json`, scraped from
/// https://www.etecsa.cu/en/rooms-public-spaces — a public service locator, not customer data).
struct WifiProvince: Identifiable, Codable, Hashable {
    var id: String { province }
    let province: String
    /// Navigation rooms (paid internet-access points with computers/positions) in this province.
    let rooms: [WifiRoom]
    /// Free public WIFI hotspots, grouped by municipality.
    let hotspots: [WifiHotspotGroup]
}

/// One navigation room: a name, an address (sometimes blank — ETECSA's own listing omits it for
/// a few rooms), and a seat/"position" count (`nil` when ETECSA's listing omits that too).
struct WifiRoom: Identifiable, Codable, Hashable {
    var id: String { name + address }
    let name: String
    let address: String
    let positions: Int?
}

/// Free WIFI hotspot locations (parks, plazas, ...) in one municipality.
struct WifiHotspotGroup: Identifiable, Codable, Hashable {
    var id: String { municipality }
    let municipality: String
    let spots: [String]
}
