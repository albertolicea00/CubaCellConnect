Guidance for AI coding agents when working in this repository.

## Project Overview

CubaCell Connect is a SwiftUI iPhone app (iOS 17+) that gives quick access to ETECSA (Cubacel) USSD service codes: balance queries, plan purchases, credit transfers and other utilities. The app hands codes to the system dialer — it performs no networking of its own.

## Build & Run

The Xcode project is **generated, not committed** (`*.xcodeproj` is gitignored):

```bash
xcodegen generate                    # regenerate after changing project.yml or adding files
open CubaCellConnect.xcodeproj
```

Verify compilation from the CLI:

```bash
xcodebuild -project CubaCellConnect.xcodeproj -scheme CubaCellConnect \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

USSD dialing only works on a physical iPhone with a Cubacel SIM; the simulator cannot place calls.

## Architecture

```
CubaCellConnect/
├── App/          CubaCellConnectApp — entry point, injects USSDCodeStore via .environment
├── Models/       USSDCode, USSDCategory, USSDCatalog (Codable, mirror the JSON schema)
├── Services/     USSDCodeStore (@Observable, loads bundled JSON)
│                 DialService (tel:// bridge; `#` must be encoded as %23)
├── Theme/        AppTheme + Color extensions (brand palette)
├── Views/        HomeView (grouped list) → CodeRowView → CodeDetailView (sheet)
└── Resources/    ussd_codes.json — the single source of truth for all codes
```

Data flow: `ussd_codes.json` → `USSDCodeStore` → views. No persistence, no networking, no third-party dependencies.

## USSD Catalog Rules

All codes live in `CubaCellConnect/Resources/ussd_codes.json`. When editing:

- Keep the schema: `id`, `code`, `title`, `details`, `category`, `type`, `requiresInput`, optional `inputPlaceholder`, `mnemonic`.
- `{input}` inside `code` marks the user-provided part (card number, phone number). Set `requiresInput: true` and provide `inputPlaceholder`.
- `type: "ussd"` for dialed sequences (usually end in `#`); `type: "call"` for plain numbers.
- `category` must match an entry in the `categories` array; category `icon` is an SF Symbol name.
- Model changes in `USSDCode.swift` must stay in sync with the JSON schema.

## Conventions

- All code, comments and identifiers in **English** (UI copy too).
- Brand palette only: navy `rgb(0, 0, 102)` (`Color.brandNavy`), cyan `#09C` (`Color.brandCyan`), black and white (adaptive `appBackground` / `appForeground`). No other colors.
- Swift 5.9+, SwiftUI-first, value types preferred, no third-party dependencies.
- Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`), lowercase subjects, no attribution trailers of any kind (no Co-Authored-By).

## Platform Caveats

- iOS rejects raw `#` in `tel://` URLs — always encode as `%23` (handled in `DialService`).
- Interactive multi-step USSD menus (`*133#`, `*234#`) may not render responses on iOS the way they do on Android; the copy-to-clipboard action is the fallback.
- `*#06#` (IMEI) generally only works typed directly in the dialer, not via `tel://`.
