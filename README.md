# 🇨🇺 CubaCell Connect

> The app is named **Cuba-Cell** (with double "L") to avoid any legal conflicts or trademark issues with Cubacel.

[![Platform](https://img.shields.io/badge/platform-iOS%2017.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.9%2B-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-15.0%2B-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![USSD sync](https://github.com/albertolicea00/cubacell-connect/actions/workflows/ussd-sync-check.yml/badge.svg)](https://github.com/albertolicea00/cubacell-connect/actions/workflows/ussd-sync-check.yml)

An iPhone app to quickly access the **USSD service codes of ETECSA (Cubacel)** : check your balance, buy data/voice/SMS plans, transfer credit and more — all from a clean, organized list that hands the code straight to the system dialer.


## ✨ Features

- 📋 **Full USSD catalog** grouped by category: Balance & Plans, Purchases & Top-Up, Transfers, and Other Utilities.
- 📞 **One-tap dialing** — the app opens the system dialer with the code prefilled (`#` correctly percent-encoded).
- ⌨️ **Input-aware codes** — codes like `*662*{card}#` or `#31#{number}` ask for the missing part before dialing.
- 📎 **Copy to clipboard** for any code.
- 💡 **Mnemonics** — e.g. `328 = DAT`, `266 = BON`, `869 = VOZ` — the keypad letters spell the service name.
- 🌗 **Light and dark mode** support.
- 👤 **Contactos tab** — reads the device's real address book (with photos) so you can call, transfer balance to, or dial a collect/hidden call for any contact without leaving the app.
- 🆔 **Caller ID for `*99` collect calls** — a CallKit Call Directory Extension labels incoming collect calls with the real contact's name instead of the raw wrapped number ETECSA's `*99` service shows. See [ARCHITECTURE.md § 10](ARCHITECTURE.md#10-caller-id-extension-99-collect-call-identification) for how it works and how to enable it.
- 🛜 **Navigation rooms & public WIFI spaces** — Ajustes › Salas y Zonas WiFi lists every Cuban province; picking one shows ETECSA's own paid navigation rooms (with seat counts) and free public WIFI hotspots by municipality, bundled from [`CubaCellConnect/data/wifi_navigation_rooms.json`](CubaCellConnect/data/wifi_navigation_rooms.json). See sources below.

*The full USSD code catalog is dynamically loaded from our JSON configuration file [`CubaCellConnect/codes.json`](CubaCellConnect/codes.json), keeping the app lightweight and easy to update.* 📁

## 🛠️ Requirements

- 🍏 Xcode 15+
- 📱 iOS 17.0+
- ⚙️ [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## 🚀 Getting Started

```bash
git clone https://github.com/albertolicea00/cubacell-connect.git
cd cubacell-connect
xcodegen generate
open CubaCellConnect.xcodeproj
```

Build and run on a device. **USSD dialing requires a physical iPhone with a Cubacel SIM** 📲 — the simulator cannot place calls.

To get Caller ID working for `*99` collect calls, after installing the app go to **Ajustes (Settings) › Teléfono › Bloqueo e Identificación de Llamadas** on the device and enable **CallerID**. This is a one-time, manual iOS setting — no app can enable it automatically. See [ARCHITECTURE.md § 10](ARCHITECTURE.md#10-caller-id-extension-99-collect-call-identification) for why.

## 🗂️ Project Structure

```
CubaCellConnect/
├── CubaCellConnectApp.swift  # App entry point
├── Models.swift              # USSDCode, USSDCategory, catalog decoding, brand palette
├── Services.swift            # JSON catalog store, Contacts, system dialer bridge
├── UIComponents.swift        # Reusable presentational views (code row)
├── Views.swift               # Home, Contactos, category, and settings screens
├── codes.json                # Bundled USSD code catalog
└── data/
    └── wifi_navigation_rooms.json  # Bundled ETECSA navigation-room/hotspot directory

CallerIDExtension/             # CallKit Call Directory Extension (labels *99 collect calls)
└── CallDirectoryHandler.swift

Shared/                        # Code shared by the app and CallerIDExtension
└── CallerIDStore.swift        # App Group–backed caller-ID list (read/write)
```

## 🔄 Code source of truth

The USSD codes in [`CubaCellConnect/codes.json`](CubaCellConnect/codes.json) mirror the canonical [`cuba-cubacel`](https://github.com/albertolicea00/MyUSSDCodes-collection/blob/main/codes/cuba-cubacel.json) collection in **[MyUSSDCodes-collection](https://github.com/albertolicea00/MyUSSDCodes-collection)** — the single source of truth for USSD codes across all my apps.

A weekly GitHub Action ([`ussd-sync-check`](.github/workflows/ussd-sync-check.yml)) compares the dial strings shipped here against that collection. On drift the run fails and opens a `ussd-sync` issue listing the added/removed codes. **Fix codes upstream in MyUSSDCodes-collection first, then sync this file to match.**

## 🔍 Directory (reverse lookup)

Ajustes › Buscar en Directorio lets you query a phone directory (Truecaller-style dump, not bundled with the app) that the user copies into this app's own files (Finder › your iPhone, or the "Importar Base de Datos" button inside the screen). The app never downloads or bundles that file itself — it only detects and reads it if already present.

**Name search is intentionally disabled for privacy and security.** Only number search is allowed — this avoids turning the app into a reverse people-search-by-name tool.

Results show a mobile/landline icon in place of a real contact photo (the dump carries no photos, only line type) and a **copy-to-clipboard** button instead of a call button — also intentional: these are numbers from a scraped third-party dump, not something the user typed in or picked from their own address book, so this app doesn't offer one-tap dialing straight out of a directory search.

## 🛜 Navigation Rooms & Public WIFI Spaces

Ajustes › Salas y Zonas WiFi is a bundled, read-only copy of ETECSA's own public "Navigation rooms and public spaces (WIFI)" directory — unlike the reverse-lookup directory above, this is official public service-location data (room/hotspot names and addresses), not customer data, so it ships inside the app like `codes.json` does.

Scraped once (2026-09) from ETECSA's public site, one page per province:

| Province | Source |
|---|---|
| Pinar del Río | https://www.etecsa.cu/en/rooms-public-spaces?provincia=49 |
| Artemisa | https://www.etecsa.cu/en/rooms-public-spaces?provincia=33 |
| La Habana | https://www.etecsa.cu/en/rooms-public-spaces?provincia=27 |
| Isla de la Juventud | https://www.etecsa.cu/en/rooms-public-spaces?provincia=29 |
| Mayabeque | https://www.etecsa.cu/en/rooms-public-spaces?provincia=200 |
| Matanzas | https://www.etecsa.cu/en/rooms-public-spaces?provincia=212 |
| Cienfuegos | https://www.etecsa.cu/en/rooms-public-spaces?provincia=226 |
| Villa Clara | https://www.etecsa.cu/en/rooms-public-spaces?provincia=235 |
| Sancti Spíritus | https://www.etecsa.cu/en/rooms-public-spaces?provincia=249 |
| Ciego de Ávila | https://www.etecsa.cu/en/rooms-public-spaces?provincia=258 |
| Camagüey | https://www.etecsa.cu/en/rooms-public-spaces?provincia=269 |
| Las Tunas | https://www.etecsa.cu/en/rooms-public-spaces?provincia=283 |
| Granma | https://www.etecsa.cu/en/rooms-public-spaces?provincia=292 |
| Holguín | https://www.etecsa.cu/en/rooms-public-spaces?provincia=306 |
| Santiago de Cuba | https://www.etecsa.cu/en/rooms-public-spaces?provincia=321 |
| Guantánamo | https://www.etecsa.cu/en/rooms-public-spaces?provincia=331 |

Since this data is bundled (not fetched live), it can drift from ETECSA's site over time — there is no sync check for it yet, unlike `codes.json`.

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## ⚠️ Disclaimer

This is an independent, community-made app. It is **not affiliated with, endorsed by, or sponsored by ETECSA**. Codes may change at any time at the carrier's discretion.

## 📚 Sources
The codes were saved from the following sites:
- https://galixpay.com/recargas-a-cuba/
- https://www.fonoma.com/blog/codigos-ussd-cuba
- https://www.etecsa.cu/es/taxonomy/term/1445

## License

[MIT](LICENSE) @albertolicea00
