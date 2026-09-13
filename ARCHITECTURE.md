# CubaCell Connect :: Architecture

For contribution workflow see [CONTRIBUTING.md](CONTRIBUTING.md).

This document describes the technical architecture of CubaCell Connect, a native iOS app that lets users dial ETECSA (Cubacel) USSD service codes (`*222#` style dial strings) without needing to remember them.

It is a single-target, dependency-free SwiftUI app with no backend, no network calls, and no persistence beyond the bundled catalog. There is no user data of any kind — everything the app shows comes from one read-only JSON file.

---

## 1. High-Level Overview

```
┌─────────────────────────────────────────────────┐
│                CubaCellConnectApp                │
│         (App entry point · injects store)        │
└───────────────────────────┬───────────────────────┘
                            │
                            ▼
                        HomeView
              (category list · selects a code)
                            │
                            ▼
                    CodeDetailView (sheet)
              (input, copy to clipboard, dial)
                    │                │
                    ▼                ▼
              DialService      UIPasteboard
           (opens tel:// URL)


          USSDCodeStore ── decodes ──▶ USSDCatalog
                  │
                  └── loads CubaCellConnect/codes.json (bundled, read-only)
```

There is no MVVM view-model layer, no navigation state machine, and no singleton services beyond the one `@Observable` catalog store injected at the app root. State flows one way — store (read-only) → views — and the only mutable state anywhere in the app is `selectedCode` in `HomeView` and `input`/`copied` in `CodeDetailView`. This keeps the codebase intentionally tiny (≈250 lines of Swift across 5 files).

---

## 2. Source Layout

| File | Responsibility |
|---|---|
| `CubaCellConnect/CubaCellConnectApp.swift` | `@main` entry point. Creates the single `USSDCodeStore` and injects it into `HomeView` via `.environment`. |
| `CubaCellConnect/Models.swift` | `Codable` catalog models (`USSDCatalog`, `USSDCategory`, `USSDCode`, `USSDActionType`) plus the brand palette (`Color.brandNavy`, `.brandCyan`, `.appBackground`, `.appForeground`) and `AppTheme.codeFont`. |
| `CubaCellConnect/Services.swift` | `USSDCodeStore` (`@Observable`, loads and decodes `codes.json` from the bundle) and `DialService` (stateless enum that builds and opens `tel://` URLs). |
| `CubaCellConnect/UIComponents.swift` | Reusable, presentation-only views: `CodeRowView`, a pure function of a `USSDCode`. |
| `CubaCellConnect/Views.swift` | The two screens: `HomeView` (category list, owns `selectedCode`) and `CodeDetailView` (the sheet with the only real logic in the app). |
| `CubaCellConnect/codes.json` | Static, bundled dataset: version, carrier, categories, and every service code with its dial string and presentation metadata. |
| `CubaCellConnect.xcassets/` | `AccentColor` (brand cyan, `#09C`) and `AppIcon`. |

No separate persistence layer, networking layer, or dependency-injection container exists — `Services.swift` *is* the service layer, and there is exactly one store instance, created once and passed down.

---

## 3. Configuration Data: `codes.json`

`codes.json` is the single source of truth for **what USSD codes exist** and is treated as read-only, bundled data. It decodes into:

```
USSDCatalog
 ├─ version, carrier
 ├─ categories: [USSDCategory]
 │   └─ id, name, icon (SF Symbol)
 └─ codes: [USSDCode]
     ├─ id, code, title, details, category, mnemonic?
     ├─ type: USSDActionType        (.ussd or .call — drives badge icon and button label)
     ├─ requiresInput: Bool
     └─ inputPlaceholder: String?
```

`USSDCodeStore.load(from:)` reads and decodes this once, synchronously, at `init`. There is **no schema versioning enforcement and no remote fetch** — updating codes requires shipping a new app build. A missing or malformed catalog trips an `assertionFailure` in debug and renders an empty list in release; since the file is bundled, this only happens on developer error.

**External sync guard**: a GitHub Actions workflow (`.github/workflows/ussd-sync-check.yml`, script `.github/scripts/check-ussd-sync.mjs`) compares this file's *dial-string set* against the canonical `MyUSSDCodes-collection` repo (`cuba-cubacel.json`) and opens a tracking issue on drift. This is a CI-side consistency check, not a runtime mechanism — the app itself never talks to that repo.

---

## 4. Navigation Model

There is exactly one navigation surface: `HomeView` is a `NavigationStack` wrapping a grouped `List`, one section per category. Tapping a row sets `selectedCode`, which drives a `.sheet(item:)` presenting `CodeDetailView` at `.medium`/`.large` detents. Dismissing the sheet (by dialing or by swipe) simply clears `selectedCode` — there is no back-stack, no deep linking, and no state that survives relaunch.

---

## 5. USSD Execution Path

1. `CodeRowView` tap → `HomeView` sets `selectedCode`, presenting `CodeDetailView`.
2. If the code requires input (`requiresInput == true`), the sheet shows a `TextField` and disables the dial button until it is non-empty; `USSDCode.resolvedCode(input:)` substitutes the `{input}` placeholder.
3. **Copy** writes `resolvedCode` to `UIPasteboard.general` directly — no expiry, no local-only flag, since nothing copied here is a secret (it is a dial string, not a PIN or card number).
4. **Dial** calls `DialService.dial(_:)`, which percent-encodes `#` as `%23` (iOS rejects a raw `#` in a `tel://` URL), builds the URL, and calls `UIApplication.shared.open`. Returns `false` when the device cannot place calls (iPad, simulator, Wi-Fi-only) instead of failing silently; the sheet dismisses either way since iOS itself will show its own confirmation prompt or simply do nothing.

There is no prefill/resolver indirection here (unlike apps that inject saved user data before dialing) — a code either needs typed input or it doesn't, and that is the entire decision tree.

---

## 6. Theming

- **Brand palette**: `Color.brandNavy` (`rgb(0,0,102)`) and `Color.brandCyan` (`#09C`) are fixed static properties on `Color`, defined in `Models.swift` — not user-configurable, unlike apps that expose a `ColorPicker` for the accent. `AccentColor` in the asset catalog is set to the same cyan so system controls (nav bar tint, `.tint(.brandCyan)`) match without restating the value.
- **Adaptive colors**: `Color.appBackground`/`.appForeground` wrap `UIColor.systemBackground`/`.label` so light/dark mode "just works" without any app-level dark-mode toggle or `@AppStorage` preference.
- **Typography**: `AppTheme.codeFont(size:)` is the one shared style — a semibold monospaced font — used everywhere a dial string is displayed, so codes always read as "code" rather than prose.
- All color usage in views must go through these tokens; no ad-hoc colors.

---

## 7. Platform Constraints

These shape the UX and are not fixable in code:

- iOS shows a confirmation prompt before dialing any `tel://` URL — the app cannot dial silently (by design, and good).
- Interactive multi-step USSD menus (`*133#`, `*234#`) may not render session responses the way Android does; the copy action exists as the fallback.
- `*#06#` (IMEI) is parsed by the dialer only when typed manually; via `tel://` it generally does nothing.
- Simulator and Wi-Fi-only devices cannot place calls; `DialService.dial` returns `false` there.

---

## 8. Notable Constraints & Trade-offs (for future contributors)

- **No dependency injection / testability seams**: `USSDCodeStore` is created once in `CubaCellConnectApp` and passed via `.environment` — there is no protocol/mock seam, but the app is small enough that this has not mattered.
- **Silent failure on decode errors**: a malformed `codes.json` trips `assertionFailure` in debug and silently renders an empty list in release, rather than surfacing an error — acceptable only because the file is bundled and never user-supplied.
- **No data migrations**: `codes.json` has a `version` field that nothing currently reads; adding a new field to `USSDCode` is safe (optional fields decode fine), but renaming/retyping an existing field will break decoding for the exact build that ships it.
- **`codes.json` is compiled-in**: adding a new code or category requires a new app build and App Store review — there is no remote-config or in-app update path, unlike apps whose `version` field exists specifically to unlock that later (see Extension Points below).

---

## 9. Extension Points

- **New code or category** → edit `codes.json` only; UI adapts automatically.
- **Search** → filter `store.codes` in `HomeView`; no structural change needed.
- **Favorites / recents** → first real persistence; add a small `UserDefaults`-backed store beside `USSDCodeStore`, keep the catalog itself read-only.
- **Remote catalog updates** → replace `USSDCodeStore.load(from:)` with a cached-remote strategy; the `version` field in the JSON exists for this.
- **Localization** — UI copy is English; catalog `title`/`details` would move to localized variants keyed by the same `id`.
