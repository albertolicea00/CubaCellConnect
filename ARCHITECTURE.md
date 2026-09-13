# Architecture

This document describes how CubaCell Connect is structured and why. For contribution workflow see [CONTRIBUTING.md](CONTRIBUTING.md).

## Overview

CubaCell Connect is a small, dependency-free SwiftUI app. Its entire job:

1. Load a bundled catalog of ETECSA USSD codes.
2. Present them grouped by category.
3. Hand a selected code to the system dialer (or the clipboard).

There is **no networking, no persistence, no state beyond the UI**. The catalog JSON is the single source of truth; everything else renders or executes it.

## Layer Diagram

```
┌─────────────────────────────────────────────────┐
│                     Views                       │
│  HomeView ──▶ CodeRowView                       │
│      │                                          │
│      └──▶ CodeDetailView (sheet)                │
│               │            │                    │
│               ▼            ▼                    │
│         DialService   UIPasteboard              │
└──────────────│──────────────────────────────────┘
               │ reads
┌──────────────▼──────────────────────────────────┐
│                   Services                      │
│  USSDCodeStore (@Observable)                    │
│  DialService (stateless enum)                   │
└──────────────│──────────────────────────────────┘
               │ decodes
┌──────────────▼──────────────────────────────────┐
│              Models + Resources                 │
│  USSDCatalog / USSDCategory / USSDCode          │
│  ussd_codes.json (bundled, read-only)           │
└─────────────────────────────────────────────────┘
```

## Components

### Models (`CubacellConnect/Models/`)

Plain `Codable` value types mirroring the JSON schema:

- `USSDCatalog` — root: version, carrier, categories, codes.
- `USSDCategory` — id, display name, SF Symbol icon.
- `USSDCode` — the code itself plus presentation metadata. `resolvedCode(input:)` substitutes the `{input}` placeholder with user-provided text (card number, phone number).
- `USSDActionType` — `ussd` (dialed sequence) vs `call` (plain number). Drives the row badge icon and the detail button label; execution path is identical (both go through the dialer).

### Services (`CubacellConnect/Services/`)

- **`USSDCodeStore`** — `@Observable` class, loads and decodes `ussd_codes.json` from the bundle at init. Exposes `categories`, `codes`, and `codes(in:)` for category filtering. Injected once at app root via `.environment`. A missing or malformed catalog trips an `assertionFailure` in debug and renders an empty list in release — the file is bundled, so this only happens on developer error.
- **`DialService`** — stateless enum. Builds `tel://` URLs and opens them. The one non-obvious rule of the whole app lives here: **`#` must be percent-encoded as `%23`** or `URL(string:)`/iOS rejects the sequence. Returns `false` when the device cannot place calls (iPad, simulator) instead of failing silently.

### Theme (`CubacellConnect/Theme/`)

Brand palette as `Color` extensions — navy `rgb(0, 0, 102)`, cyan `#09C`, plus adaptive black/white via `systemBackground`/`label`. `AppTheme.codeFont` provides the monospaced style for anything dialable. All color usage in views must go through these tokens; no ad-hoc colors.

### Views (`CubacellConnect/Views/`)

- **`HomeView`** — `NavigationStack` + grouped `List`, one section per category. Owns the `selectedCode` state that drives the detail sheet. Navy toolbar, cyan tint.
- **`CodeRowView`** — pure function of a `USSDCode`: title, monospaced code, type badge (phone vs `#`).
- **`CodeDetailView`** — the only view with real logic: local `input` state for `{input}` codes, dial button disabled until input is non-empty, copy-to-clipboard fallback, dismisses after dialing.

State flows one way: store (read-only catalog) → views; the only mutable state is `selectedCode` in `HomeView` and `input`/`copied` in `CodeDetailView`.

## Key Decisions

| Decision | Rationale |
| --- | --- |
| Catalog as bundled JSON, not Swift constants | Non-developers can review/update codes; schema is documented and diff-friendly; opens the door to remote catalog updates later without restructuring. |
| No networking | Target users often have expensive/limited connectivity — the app must be 100% offline. |
| No third-party dependencies | Nothing here needs one; keeps the build reproducible with `xcodegen generate` alone. |
| XcodeGen, project not committed | `project.pbxproj` merge conflicts are the worst part of iOS collaboration; `project.yml` is reviewable. |
| `@Observable` over `ObservableObject` | iOS 17 baseline makes the modern observation model available; less boilerplate. |
| Dial via `tel://`, not CoreTelephony/CallKit | iOS offers no API to run USSD programmatically; opening the dialer is the only sanctioned path. |

## Platform Constraints

These shape the UX and are not fixable in code:

- iOS shows a confirmation prompt before dialing any `tel://` URL — the app cannot dial silently (by design, and good).
- Interactive multi-step USSD menus (`*133#`, `*234#`) may not render session responses the way Android does; the copy action exists as the fallback.
- `*#06#` (IMEI) is parsed by the dialer only when typed manually; via `tel://` it generally does nothing.
- Simulator and Wi-Fi-only devices cannot place calls; `DialService.dial` returns `false` there.

## Extension Points

- **New code or category** → edit `ussd_codes.json` only; UI adapts automatically.
- **Search** → filter `store.codes` in `HomeView`; no structural change needed.
- **Favorites / recents** → first real persistence; add a small `UserDefaults`-backed service beside `USSDCodeStore`, keep the catalog itself read-only.
- **Remote catalog updates** → replace `USSDCodeStore.load(from:)` with a cached-remote strategy; the `version` field in the JSON exists for this.
- **Localization** — UI copy is English; catalog `title`/`details` would move to localized variants keyed by the same `id`.
