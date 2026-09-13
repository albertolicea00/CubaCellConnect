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
open CubacellConnect.xcodeproj
```

Build and run on a device. **USSD dialing requires a physical iPhone with a Cubacel SIM** 📲 — the simulator cannot place calls.

## 🗂️ Project Structure

```
CubacellConnect/
├── App/          # App entry point
├── Models/       # USSDCode, USSDCategory, catalog decoding
├── Services/     # JSON catalog store, system dialer bridge
├── Theme/        # Brand colors and typography
├── Views/        # Home list, row, detail sheet
└── Resources/    # ussd_codes.json catalog
```

## 🔄 Code source of truth

The USSD codes in [`CubaCellConnect/codes.json`](CubaCellConnect/codes.json) mirror the canonical [`cuba-cubacel`](https://github.com/albertolicea00/MyUSSDCodes-collection/blob/main/codes/cuba-cubacel.json) collection in **[MyUSSDCodes-collection](https://github.com/albertolicea00/MyUSSDCodes-collection)** — the single source of truth for USSD codes across all my apps.

A weekly GitHub Action ([`ussd-sync-check`](.github/workflows/ussd-sync-check.yml)) compares the dial strings shipped here against that collection. On drift the run fails and opens a `ussd-sync` issue listing the added/removed codes. **Fix codes upstream in MyUSSDCodes-collection first, then sync this file to match.**

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
