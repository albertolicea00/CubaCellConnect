import Foundation
import SwiftUI

// MARK: - Catalog Models

/// How a code is executed on the device.
enum USSDActionType: String, Codable {
    /// Dialed as a USSD sequence (e.g. *222#).
    case ussd
    /// A regular phone call (e.g. *2266).
    case call
}

/// A single ETECSA (Cubacel) service code. Its category and group are implied by where it sits
/// in the catalog's nested JSON — a code carries no category/group tag of its own.
struct USSDCode: Identifiable, Codable, Hashable {
    let id: String
    /// Raw code. May contain the `{input}` placeholder when user input is required.
    let code: String
    let title: String
    let details: String
    let type: USSDActionType
    let requiresInput: Bool
    let inputPlaceholder: String?

    /// Code with the user-provided input substituted in.
    func resolvedCode(input: String = "") -> String {
        code.replacingOccurrences(of: "{input}", with: input)
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

// MARK: - Brand Palette

extension Color {
    /// rgb(0, 0, 102) — primary brand color.
    static let brandNavy = Color(red: 0 / 255, green: 0 / 255, blue: 102 / 255)
    /// #09C — accent color.
    static let brandCyan = Color(red: 0 / 255, green: 153 / 255, blue: 204 / 255)
    /// Adaptive background: white in light mode, black in dark mode.
    static let appBackground = Color(UIColor.systemBackground)
    /// Adaptive foreground: black in light mode, white in dark mode.
    static let appForeground = Color(UIColor.label)
}

enum AppTheme {
    /// Monospaced style used to display dialable codes.
    static func codeFont(size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}
