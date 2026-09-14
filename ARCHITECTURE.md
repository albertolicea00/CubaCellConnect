# CubaCell Connect :: Architecture

For contribution workflow see [CONTRIBUTING.md](CONTRIBUTING.md).

This document describes the technical architecture of CubaCell Connect, a native iOS app that lets users dial ETECSA (Cubacel) USSD service codes (`*222#` style dial strings) without needing to remember them.

It is a dependency-free SwiftUI app with no backend and no network calls. Almost everything comes from one read-only bundled JSON catalog; the two exceptions are the device's own Contacts (read live via the `Contacts` framework, never sent anywhere) and a small App Group file the CallerIDExtension target reads to label `*99` collect calls (§10) — there is still no server, no analytics, and no third-party dependency anywhere in the project.

---

## 1. High-Level Overview

```
┌─────────────────────────────────────────────────┐
│                CubaCellConnectApp                │
│    (App entry point · injects store · theme)     │
└───────────────────────────┬───────────────────────┘
                            │
                            ▼
                        HomeView
                (TabView, one tab per category)
        ┌──────────┬──────────┬──────────┬──────────┐
        ▼          ▼          ▼          ▼          ▼
   CategoryListView (×N, one per USSDCategory)   SettingsView
   (per-category code list · selects a code)   (theme, about, links)
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

There is no MVVM view-model layer, no cross-tab navigation state machine, and no singleton services beyond the one `@Observable` catalog store injected at the app root. State flows one way — store (read-only) → views — and the only mutable state anywhere in the app is `selectedCode` (one per `CategoryListView` instance), `input`/`copied` in `CodeDetailView`, and the `darkModePreference` `@AppStorage` flag read by both `SettingsView` and `CubaCellConnectApp`. This keeps the codebase intentionally small (≈380 lines of Swift across 5 files).

---

## 2. Source Layout

| File | Responsibility |
|---|---|
| `CubaCellConnect/CubaCellConnectApp.swift` | `@main` entry point. Creates the single `USSDCodeStore` and injects it into `HomeView` via `.environment`. |
| `CubaCellConnect/Models.swift` | `Codable` catalog models (`USSDCatalog`, `USSDCategory`, `USSDCode`, `USSDActionType`) plus the brand palette (`Color.brandNavy`, `.brandCyan`, `.appBackground`, `.appForeground`) and `AppTheme.codeFont`. |
| `CubaCellConnect/Services.swift` | `USSDCodeStore` (`@Observable`, loads and decodes `codes.json` from the bundle), `ContactsService` (`@Observable`, reads the device address book via `CNContactStore`, rebuilds the CallerID list on every fetch — §10), `CellularMonitor`, and `DialService` (stateless enum that builds and opens `tel://` URLs). |
| `CubaCellConnect/UIComponents.swift` | Reusable, presentation-only views: `CodeRowView`, `ContactRowView`, a pure function of a `USSDCode`. |
| `CubaCellConnect/Views.swift` | `HomeView` (the root `TabView`), `CategoryListView` (one instance per category), `ContactsListView`/`ContactCallRowView`/`ContactCallOptionsSheet` (Contactos tab: list, swipe-to-call, transfer sheet), and `SettingsView` and its sub-screens. |
| `CubaCellConnect/codes.json` | Static, bundled dataset: version, carrier, categories, and every service code with its dial string and presentation metadata. |
| `CubaCellConnect.xcassets/` | `AccentColor` (brand cyan, `#09C`) and `AppIcon`. |
| `Shared/CallerIDStore.swift` | `CallerIDEntry` model plus read/write helpers for the App Group file both `CubaCellConnect` and `CallerIDExtension` touch — the only file compiled into *both* targets (§10). |
| `CallerIDExtension/CallDirectoryHandler.swift` | The `CXCallDirectoryProvider` subclass — the entire CallerIDExtension target (§10). |

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

---

## 4. Navigation Model

`HomeView` is a bottom `TabView` built by iterating `store.categories` — one tab per catalog category (SF Symbol from `USSDCategory.icon`), plus a fixed final "Settings" tab. Nothing hardcodes the category count or order beyond `codes.json` itself: adding a category there adds a tab automatically.

Each category tab hosts its own `CategoryListView`, a `NavigationStack` wrapping a plain `List` of that category's codes. Tapping a row sets that instance's own `selectedCode`, driving a `.sheet(item:)` that presents `CodeDetailView` at `.medium`/`.large` detents. Because `selectedCode` is local `@State` per `CategoryListView`, each tab's sheet state is independent — switching tabs mid-sheet is not a state collision, SwiftUI just tears down and recreates each tab's own view identity as needed.

`SettingsView` is its own `NavigationStack` with a `Form`, entirely separate from the category tabs — no shared navigation state, no back-stack, no deep linking, and nothing survives relaunch except the one `@AppStorage("darkModePreference")` flag.

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
- **Adaptive colors**: `Color.appBackground`/`.appForeground` wrap `UIColor.systemBackground`/`.label` so light/dark mode "just works" by default.
- **Dark mode override**: `SettingsView` exposes a "Theme" picker (System Default / Light / Dark) backed by `@AppStorage("darkModePreference")` (`Int`, 0/1/2). `CubaCellConnectApp` reads the same key and applies `.preferredColorScheme(nil/.light/.dark)` to the root `WindowGroup` content — the one piece of state in the app that is both user-configurable and persisted across launches.
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
- **Search** → filter `store.codes(in:)` inside `CategoryListView`; no structural change needed.
- **Favorites / recents** → first real persistence; add a small `UserDefaults`-backed store beside `USSDCodeStore`, keep the catalog itself read-only.
- **Remote catalog updates** → replace `USSDCodeStore.load(from:)` with a cached-remote strategy; the `version` field in the JSON exists for this.
- **Localization** — UI copy is English; catalog `title`/`details` would move to localized variants keyed by the same `id`.

---

## 10. Caller ID Extension (`*99` collect-call identification)

### 10.1 Why this exists

ETECSA's `*99` collect-call service does **not** withhold the caller's number the way `#31#` (anonymous) does — it wraps it. Dialing `*99{number}` makes the call arrive on the other end with a caller ID string of the form:

```
99 + "53" (country code) + {8-digit local number} + 99
```

e.g. a call to `51234567` shows up as `99535123456799` (14 digits) instead of the real number. iOS's stock Phone app has no idea what to do with that, so the incoming call just shows a meaningless 14-digit string. Since the real digits genuinely reach the device (unlike a truly anonymous call, which never transmits them — see the in-app "Ayuda" copy on this), it's possible to reverse the wrapping and show the real contact's name instead. Apple's supported mechanism for that is a **CallKit Call Directory Extension**.

### 10.2 How it works

```
CubaCellConnect (main app)                 CallerIDExtension (app extension)
──────────────────────────                 ────────────────────────────────
ContactsService.fetch()
  reads CNContactStore
  → [DeviceContact]
        │
        ▼
CallerIDStore.wrappedNumber(...)
  "99" + "53" + localNumber + "99"
        │
        ▼
CallerIDStore.write([CallerIDEntry])  ──▶  App Group container (shared file)
  group.com.cubacellconnect.shared          "caller-id-entries.json"
        │                                          │
        ▼                                          ▼
CXCallDirectoryManager.reloadExtension  ──▶  CallDirectoryHandler.beginRequest(with:)
  (tells iOS to re-run the extension)          CallerIDStore.read()
                                                → context.addIdentificationEntry(...)
                                                  for each entry, ascending order
                                                → context.completeRequest()
```

- **`Shared/CallerIDStore.swift`** is compiled into *both* targets. It defines `CallerIDEntry` (`wrappedNumber: Int64`, `name: String`), the wrapping formula, and JSON read/write against a file in the App Group container (`group.com.cubacellconnect.shared`) — the only way for two separate sandboxed processes (the app and the extension) to share data.
- **`ContactsService.fetch()`** (in `CubaCellConnect/Services.swift`) rebuilds the full entry list from `contacts` every time it re-fetches from `CNContactStore`, writes it via `CallerIDStore.write(_:)`, then calls `CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier:)` so iOS re-invokes the extension immediately rather than waiting for its own schedule. This keeps the Caller ID list in sync automatically — there is no separate manual "sync" button in the UI.
- **`CallerIDExtension/CallDirectoryHandler.swift`** is the entire extension target: a `CXCallDirectoryProvider` subclass that reads the shared file and calls `addIdentificationEntry(withNextSequentialPhoneNumber:label:)` once per contact, in strictly ascending numeric order (a hard CallKit requirement — the request is rejected otherwise), then `completeRequest()`. It never touches `CNContactStore` itself and has no Contacts permission of its own — everything it shows was computed by the main app.

### 10.3 Real constraints (not fixable in code)

- **Only labels contacts already in the address book.** A `*99` call from an unknown number still shows the raw wrapped digits — same limitation as Truecaller-style apps for unrecognized numbers.
- **The user must enable it once, manually**: Ajustes del sistema › Teléfono › Bloqueo e Identificación de Llamadas › CallerID. No API lets an app turn this on for itself.
- **Requires the App Groups capability to be signed correctly** (`group.com.cubacellconnect.shared`, declared in both targets' entitlements in `project.yml`). With automatic signing this is normally provisioned by Xcode the first time you build with a real Team ID; if identification silently doesn't show up, check that the App Group actually got created under that team in the Apple Developer portal.
- **Only testable on a physical iPhone.** The simulator has no real telephony stack, so this cannot be verified with `xcrun simctl` screenshots the way the rest of the UI in this repo is — it needs an actual incoming `*99` call on a device with the extension enabled.
- **A truly anonymous call (`#31#`) can never be identified this way** — see §7 platform constraints; the network never transmits the number at all in that case, so there is nothing for `CallerIDStore` to wrap or unwrap.
