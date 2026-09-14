# 🇨🇺 CubaCell Connect

> The app is named **Cuba-Cell** (with double "L") to avoid any legal conflicts or trademark issues with Cubacel.

[![Platform](https://img.shields.io/badge/platform-iOS%2017.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.9%2B-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-15.0%2B-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
<!-- [![WiFi rooms sync](https://github.com/albertolicea00/cubacell-connect/actions/workflows/wifi-rooms-sync-check.yml/badge.svg)](https://github.com/albertolicea00/cubacell-connect/actions/workflows/wifi-rooms-sync-check.yml) -->

An iPhone app to quickly access the **USSD service codes of ETECSA (Cubacel)** : check your balance, buy data/voice/SMS plans, transfer credit and more — all from a clean, organized list that hands the code straight to the system dialer.


## ✨ Features

- 📋 **Full USSD catalog** grouped by category: Balance & Plans, Purchases & Top-Up, Transfers, and Other Utilities.
- 📞 **One-tap dialing** — the app opens the system dialer with the code prefilled (`#` correctly percent-encoded).
- ⌨️ **Input-aware codes** — codes like `*662*{card}#` or `#31#{number}` ask for the missing part before dialing.
- 🌗 **Light and dark mode** support.
- 👤 **Contactos tab** — reads the device's real address book (with photos) so you can call, transfer balance to, or dial a collect/hidden call for any contact without leaving the app.
- 🆔 **Caller ID for `*99` collect calls** — a CallKit Call Directory Extension labels incoming collect calls with the real contact's name instead of the raw wrapped number ETECSA's `*99` service shows. See [ARCHITECTURE.md § 10](ARCHITECTURE.md#10-caller-id-extension-99-collect-call-identification) for how it works and how to enable it.
- 🛜 **Navigation rooms & public WIFI spaces** — Ajustes › Salas y Zonas WiFi lists every Cuban province; picking one shows ETECSA's own paid navigation rooms (with seat counts) and free public WIFI hotspots by municipality, bundled from [`CubaCellConnect/wifi_navigation_rooms.json`](CubaCellConnect/wifi_navigation_rooms.json). See sources below.
- ✉️ **Servicios por SMS** — Ajustes › Servicios por SMS is a searchable catalog of ETECSA's text-message services (noticias, suscripciones, deportes, clima, horóscopo, DHL, vuelos, tarifa eléctrica, recetas, ...), each opening the system SMS compose sheet prefilled — never sent silently.
- 📶 **Internet speed test** — Ajustes › Medir Velocidad de Internet runs a ping/download/upload test against Cloudflare's public speed-test endpoints, live gauge included. No ETECSA-run equivalent exists; this is a generic connectivity check, not Cuba-specific.
- 🔎 **Two more directory lookups, alongside the offline one** — Ajustes › Buscar en Páginas Amarillas and Buscar en Directorio (Online) query the web directly instead of a local file — see the Directory section below for how the offline one differs from these.
- 👥 **Plan Amigo & transfer PIN management** — Ajustes › Cuenta has dedicated screens to add/remove Plan Amigo numbers and to view/change/save your transfer PIN (Keychain-backed, never leaves the device) so it can prefill itself in Transferir.
- 🎨 **Accent color picker** — Ajustes › Preferencias lets you replace the app's default cyan accent with any color; a "Restablecer Color por Defecto" button appears once you've changed it.
- 🚀 **Configurable launch screen** — Ajustes › Pestaña Inicial picks which tab opens on launch, and also covers several screens nested *inside* Ajustes itself (Medir Velocidad de Internet, Servicios por SMS, and all three directory searches) — picking one of those jumps straight to Ajustes and auto-pushes that screen the moment the app opens, instead of landing on the plain Ajustes list first.

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
└── wifi_navigation_rooms.json  # Bundled ETECSA navigation-room/hotspot directory

CallerIDExtension/             # CallKit Call Directory Extension (labels *99 collect calls)
└── CallDirectoryHandler.swift

Shared/                        # Code shared by the app and CallerIDExtension
└── CallerIDStore.swift        # App Group–backed caller-ID list (read/write)
```

## ☎️ Direct dial vs. confirmation

Query codes (balance, plan status, Plan Amigo status, etc.) dial **immediately** on tap, no extra confirmation step — they're read-only and free, so there's nothing at risk in firing them off right away.

Purchase codes are different: they spend money, so by default they dial straight into ETECSA's own USSD confirmation menu ("¿Confirma su compra? 1. Sí") and stop there, same as any other USSD session. Compras has an opt-in **Acción Rápida sin Confirmación** toggle (off by default, with an "Activar por Defecto..." master switch in Ajustes) that instead dials a `noConfirmCode` variant which auto-selects that confirmation step in the same dial string — a warning banner stays visible at the top of Compras the whole time it's on, since it's the one mode where a tap alone completes a paid purchase.

## 🔍 Directory (reverse lookup)

There are three separate directory-lookup screens in Ajustes › Utilidades, each hitting a different source — they are not the same feature wearing different names:

- **Buscar en Directorio (Local)** — queries a phone directory (Truecaller-style dump, not bundled with the app) that the user copies into this app's own files (Finder › your iPhone, or the "Importar Base de Datos" button inside the screen). The app never downloads or bundles that file itself — it only detects and reads it if already present. This is the one described in the rest of this section.
- **Buscar en Directorio (Online)** and **Buscar en Páginas Amarillas** — query the web directly instead of a local file.

**Name search is intentionally disabled for privacy and security.** Only number search is allowed — this avoids turning the app into a reverse people-search-by-name tool.

Results show a mobile/landline icon in place of a real contact photo (the dump carries no photos, only line type) and a **copy-to-clipboard** button instead of a call button — also intentional: these are numbers from a scraped third-party dump, not something the user typed in or picked from their own address book, so this app doesn't offer one-tap dialing straight out of a directory search.

See [Known Limitations](#-known-limitations) below for why this isn't wired into Caller ID (`*99`).

## 🛜 Navigation Rooms & Public WIFI Spaces

Ajustes › Salas y Zonas WiFi is a bundled, read-only copy of ETECSA's own public "Navigation rooms and public spaces (WIFI)" directory — unlike the reverse-lookup directory above, this is official public service-location data (room/hotspot names and addresses), not customer data, so it ships inside the app like `codes.json` does.

> Scraped once (2026-09) from ETECSA's public site, one page per province

Since this data is bundled (not fetched live), it can drift from ETECSA's site over time. A GitHub Action ([`wifi-rooms-sync-check`](.github/workflows/wifi-rooms-sync-check.yml), run manually via `workflow_dispatch` — not on a schedule) re-scrapes each province page and diffs it against the bundled JSON, opening a `wifi-rooms-sync` issue on real drift. It checks whether ETECSA's site is even reachable *once*, up front, before touching any province page — GitHub-hosted runners run outside Cuba and some sites block cloud/datacenter IP ranges even though they're open to regular visitors, so if that first check fails the run stops immediately (no failure, no wasted Actions minutes retrying 16 pages that would all fail the same way).

(There used to be a similar `ussd-sync-check` workflow comparing `codes.json` against an external collection — removed as redundant once this repo's catalog became its own source of truth.)

## 🚧 Known Limitations

- **Directory database not integrated with Caller ID (`*99`).** The directory database (see above) is intentionally kept separate from `CallerIDStore`/`CallDirectoryHandler` (see [ARCHITECTURE.md § 10](ARCHITECTURE.md#10-caller-id-extension-99-collect-call-identification)), which only ever loads from the device's own Contacts. A CallKit Call Directory Extension has a hard cap on how many identification entries it can register (historically on the order of 100k–200k) — the directory dump has millions of rows (v1: ~4.6M; v2: ~4.8M combined), so registering it wholesale would get the extension rejected/disabled by iOS. Feeding it in would need a drastic filter (e.g. only numbers already in the device's own contacts, which is exactly what happens today) to fit under that ceiling.

- **No "call via WhatsApp/Teams" option in Contactos.** The Contactos tab only offers cellular actions (normal call, `*99` collect, `#31#` anonymous) next to each contact — it can't add a "call via WhatsApp" or "call via Teams" option alongside them. Those apps place calls over their own proprietary VoIP/Wi-Fi-calling stack, not the cellular network, and don't expose any public API or URL scheme a third-party app can use to trigger a call through them — that's entirely up to WhatsApp/Teams themselves (they'd need to register their own CallKit provider and/or an app-specific integration), not something CubaCellConnect can add from the outside.

- **Physical dual-SIM (two nano-SIM) devices.** iPhone models sold in mainland China, Hong Kong, and Macao support two physical nano-SIMs, instead of the nano-SIM + eSIM combo sold everywhere else. This app has no line-selection UI and no way to force a dial through one SIM specifically — iOS gives apps no public API to pick which line places a `tel://`/USSD call; it always goes out through whichever line the device's own Phone settings mark as default. Acknowledged, not implemented.

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

> ⚠️ **Issues, PR descriptions, and commit messages must be written in English.**
> The app UI is intentionally in Spanish — it targets Cuban users. All technical communication follows English conventions.


## ⚠️ Disclaimer

This is an independent, community-made app. It is **not affiliated with, endorsed by, or sponsored by ETECSA**. Codes may change at any time at the carrier's discretion.

## 📚 Sources
The codes were saved from the following sites:
- https://galixpay.com/recargas-a-cuba/
- https://www.fonoma.com/blog/codigos-ussd-cuba
- https://www.etecsa.cu/es/taxonomy/term/1445
- https://www.etecsa.cu/en/rooms-public-spaces
- https://www.ecured.cu/Entumovil
- https://www.escambray.cu/2017/etecsa-informa-sobre-nuevos-servicios-de-telefonia-movil-para-clientes-prepago-infografia/
- https://www.entumovil.cu/#:~:text=Para%20activar%20las%20siguientes%20prestaciones%2C,portal%20el%20de%20su%20preferencia.

## License

[MIT](LICENSE) @albertolicea00
