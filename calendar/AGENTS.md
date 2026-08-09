# Callisto — macOS Menu Bar Google Calendar App

## Tech Stack

- **Language:** Swift (`SWIFT_VERSION = 5.0`, with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  and `SWIFT_APPROACHABLE_CONCURRENCY = YES` — types are main-actor isolated by default)
- **UI:** SwiftUI content hosted by AppKit. There is no SwiftUI `App` — `main.swift`
  installs `AppDelegate`, which owns an `NSStatusItem` (`MenuBarController`), a borderless
  `NSPanel` for the popover (`MenuBarPanel`), and an `NSWindow` for Settings
  (`SettingsWindowController`). No Dock icon (`LSUIElement = YES`), no main window.
  See [Why not `MenuBarExtra`](#why-not-menubarextra).
- **State:** Observation framework (`@Observable`). No Combine, no `@Query`.
- **Persistence:** SwiftData (accounts, calendars, events, attendees, attachments, reminders)
- **Secrets:** macOS Keychain (OAuth tokens only)
- **Preferences:** `UserDefaults` behind the `SettingsStore` protocol
- **Auth:** Google OAuth 2.0 installed-app flow with PKCE. Consent opens in the user's
  default browser; the redirect returns through the app's registered URL scheme. See
  [Why not `ASWebAuthenticationSession`](#why-not-aswebauthenticationsession).
- **API:** Google Calendar API v3 over bare `URLSession` + hand-written `Codable` DTOs
- **Dependencies (SPM):** [Sparkle](https://github.com/sparkle-project/Sparkle) 2.9.x for
  auto-update — the only third party. Do not add more without a strong reason;
  everything else is Apple-native.
- **Platform:** macOS 14.0+

## Project Structure

```
calendar/
├── App/                       # main.swift + AppDelegate — dependency construction, wiring
├── Models/
│   ├── *.swift                # SwiftData @Model types + EventEntry / EventDay value types
│   ├── *Mock.swift            # #if DEBUG preview fixtures
│   └── GoogleCalendar/        # GC* — Codable DTOs, 1:1 with the Google API JSON
├── Services/
│   ├── Auth/                  # AuthConfig, PKCEHelper, AuthorizationSession
│   ├── Keychain/              # KeychainService, OAuthTokens, KeychainError
│   └── Google/                # The three managers + GoogleCalendarAPI + APIError
├── Views/
│   ├── MenuBar/               # Status item, panel, chrome, label, right-click menu
│   ├── Events/                # Event list, rows, context menu, preview fixtures
│   ├── Accounts/              # NoAccountsView
│   └── Settings/              # Settings window, updates section
└── Utilities/                 # Schedulers, extensions, Logger, Constants, AppInfo
```

## Architecture — three managers, one chain

There is no service/store split and no snapshot pipeline. Each manager is
`@MainActor @Observable`, owns its own `ModelContext`, mirrors its rows into an
in-memory array, and exposes `iter*()` read methods to SwiftUI.

| Concern | Owner | Notes |
|---|---|---|
| Accounts, OAuth consent, Keychain, token refresh | `GoogleAccountManager` | leaf of the chain |
| Calendar list + per-calendar visibility | `GoogleCalendarManager` | holds `accounts` |
| Events, sync orchestration, RSVP/delete mutations | `GoogleCalendarEventManager` | holds `calendars` (and `calendars.accounts`) |
| User preferences | `UserSettings` | `SettingsStore`-backed, computed properties |
| HTTP transport | `GoogleCalendarAPI` | `nonisolated struct`, stateless, `Sendable` |

`AppDelegate.applicationDidFinishLaunching` builds one `ModelContainer` and one
`GoogleCalendarEventManager`; that manager constructs `GoogleCalendarManager`, which
constructs `GoogleAccountManager`. `AppDelegate.inject(_:)` reaches through
`eventManager.accounts` / `eventManager.calendars` to put all three into the SwiftUI
environment. Views resolve them with `@Environment(GoogleCalendarEventManager.self)` etc.

The panel and the settings window are hosted separately, so **each root must be passed
through `inject(_:)`** — there is no single scene graph to inherit from.

### Observation contract

`@Observable` only auto-tracks *stored property* access. Because the managers expose data
through **methods**, each keeps a `private var version: UInt64` that every `iter*()` reads
(`_ = version`) and every mutation bumps (`version &+= 1`). **If you add a read method or a
mutation, keep that pattern or views will not re-render.** `UserSettings` does the equivalent
by hand with `access(keyPath:)` in getters and `withMutation(keyPath:)` in setters, because
its properties are computed over `UserDefaults`.

### Sync

Driven by `SyncScheduler` (fires immediately, then every `UserSettings.refreshIntervalMinutes`;
restarted when that setting changes). `GoogleCalendarEventManager.sync()` is re-entrancy
guarded by `isSyncing`.

```
sync()
 └─ calendars.sync()
     └─ accounts.authenticated()      refresh every canRead account's token in parallel
     │                                (one in-flight refresh per account, coalesced via refreshTasks)
     └─ GET /users/me/calendarList    per account, in parallel → upsert + delete stale
     └─ returns [(accountId, calendarId)]
 └─ GET /calendars/{id}/events        per pair, in parallel
        singleEvents=true, orderBy=startTime, maxResults=250,
        timeMin=startOfToday, timeMax=+31d
 └─ applySync(...)                    upsert events, replace attendees/attachments/reminders,
                                      delete events absent from the response
 └─ prune()                           delete events with endDate < yesterday
```

Fetch window is always 31 days; `UserSettings.showDaysAhead` is a **display** filter applied
at render time, so the local cache always holds a full month.

A 401/403 from any read is treated as a revoked scope: `markReadPermissionDenied` +
`logout(accountId:)`, which drops that account's cached calendars and events. Settings then
shows a "Grant read permission" row that re-runs the OAuth flow.

### Permissions

Callisto requests the narrowest scope that serves each endpoint it calls — Google's
sensitive-scope review grades on exactly that, and `calendar.readonly` is deliberately
**not** requested:

| Scope | Serves | Required? |
| --- | --- | --- |
| `calendar.calendarlist.readonly` | `GET /users/me/calendarList` | yes |
| `calendar.events.readonly` | `events.list` / `get` / `instances` | yes |
| `calendar.events` | RSVP, delete, move, patch | optional |

Scopes are granular and *verified against what Google actually granted*, not what was
requested. `OAuthTokens.grantedScopes` drives `canRead` (calendar list **and** event read —
either half alone syncs nothing) and `canWrite`; these are mirrored onto `GoogleAccount` and
reconciled from the Keychain at launch. UI gates on them: read-only accounts sync but hide
RSVP/delete actions. Event mutations additionally require `GoogleCalendar.canWriteEvents`
(`accessRole` is `writer`/`owner`).

Two asymmetries in `AuthConfig` are load-bearing, not redundancy:

- `calendar.events` counts as an *event read* grant. Google returns only the scopes the user
  actually ticked, so a consent where write was granted and read was not must still read.
- `calendar.readonly` and `calendar` are recognized (`legacy*Scope`) but never requested.
  Accounts linked before the narrowing hold those grants, and their refresh tokens keep
  working — without the alias they would degrade to "Calendar access needed" on upgrade.

### Read path

Views never resolve associations. `GoogleCalendarEventManager` returns bundles:

- `iter(_ settings:) -> [EventEntry]` — chronological, filtered by window, account/calendar
  visibility, `canRead`, cancelled status, and `showDeclinedEvents`. `EventEntry` carries
  `(event, calendar, account)`.
- `iterByDays(_ settings:) -> [EventDay]` — grouped per day; emits empty days when
  `showEmptyDays` is on. `EventDay.iter()` returns that day's entries.
- `next() -> GoogleCalendarEvent?` — next non-declined, non-cancelled event for the menu bar
  label; prefers timed events over all-day ones.

`MinuteScheduler` publishes `now` at each minute boundary; views that render relative time
read `ticker.now` to register the dependency.

### Data flow

```
                    main.swift → AppDelegate
                    ModelContainer + UserSettings + schedulers
                              │
                    GoogleCalendarEventManager
                       ├── GoogleCalendarManager
                       │      └── GoogleAccountManager ── Keychain
                       └── GoogleCalendarAPI ── URLSession ── Google Calendar API v3
                              │
              inject(...) into MenuBarController (status item + panel)
                        and SettingsWindowController
                              │
                    Views call iter*() / next() to read,
                    call manager methods to mutate,
                    read/write UserSettings directly
```

## Why not `ASWebAuthenticationSession`

It was one call — open the consent page, capture the redirect — but on macOS it presents a
sheet with **no address bar**. Google's sensitive-scope verification requires a demo video
showing "the browser address bar of the OAuth consent screen correctly includes your app's
OAuth client ID", and Callisto requests three sensitive Calendar scopes, so that sheet is a
hard blocker on shipping a verified app.

`AuthorizationSession` opens the authorization URL with `NSWorkspace.open` instead. Three
consequences:

- **The redirect comes back through LaunchServices**, into
  `AppDelegate.application(_:open:)` → `GoogleAccountManager.handleAuthorizationCallback`.
  `CFBundleURLSchemes` in the root `Info.plist` is now load-bearing, not vestigial.
- **Callisto and Callisto Nightly register the same scheme** (it is derived from the shared
  `GOOGLE_CLIENT_ID`), so with both installed the redirect can land in the wrong copy.
  `AuthorizationSession.handle` matches the `state` and returns `false` on a mismatch rather
  than resuming a flow whose PKCE verifier it does not hold. Give Nightly its own client ID
  if you need both signing in.
- **Closing the tab raises no event**, so the flow has a 180s timeout and every entry point
  offers an explicit Cancel (`isAuthorizing` on the manager).

The browser also reuses the user's existing Google sessions, which is what
`GoogleAccount.authuser` already assumes — the old ephemeral session forced a password on
every link.

## Why not `MenuBarExtra`

`MenuBarExtra` renders its `label:` into a **template** image: alpha is kept, colour is
discarded and replaced by the menu bar tint, so `ConferenceIconView`'s per-provider colour
was flat white in the bar. It also hides its `NSStatusItem`, so right-clicks had to be
stolen with a global `NSEvent` monitor matched on window class name.

`MenuBarController` hosts the label in an `NSHostingView` inside the status item button
instead, which keeps its colour, and gets both mouse buttons from
`button.sendAction(on:)`. Two consequences to keep in mind:

- **The panel is outside SwiftUI's scene graph**, so `@Environment(\.openWindow)` does not
  work in it and there is no public way to open a `Window(id:)` scene from AppKit. Views
  open windows through `@Environment(\.openWindows)` (`OpenWindowsAction`), which
  `AppDelegate` backs with `SettingsWindowController`.
- **The panel is not the key window when a link is followed**, so never dismiss it with
  `NSApp.keyWindow?.close()` — that would close the settings window. Call
  `dismissMenuBarPanel()`.

Views handed to `MenuBarController` are built **once** and kept by the hosting view, so
anything resolved outside a `body` is frozen at launch. `MenuBarStatusLabel` reads
`eventManager.next()` inside its own `body` for exactly this reason.

### Panel chrome and previews

The panel is borderless, so `PopoverChrome` — not the window — draws the `.popover`
material and the corner radius, and `PopoverContent` wraps itself in it. That is what keeps
previews honest: a preview has no window, so anything the window contributed would silently
vanish from the canvas. `MenuBarPreviewStage` (DEBUG) puts previews on a stand-in desktop so
the material has something to blend with, and `MenuBarLabel`'s previews render the label on
a menu bar strip next to a template-flattened copy — if the two rows ever match, the label
has regressed to template rendering.

## Conventions

- Swift concurrency (`async`/`await`, `withTaskGroup`) throughout — no completion handlers.
- DTOs (`GC*`) are `nonisolated ... Codable, Sendable`, mirror the API 1:1, carry a
  `Reference:` doc link, and never escape the Services layer. Views and SwiftData models
  consume them only through `init(from:)` / `update(from:)`.
- SwiftData models are the only classes that are not value types. Persistence models must not
  make network calls.
- Keep views small; extract subviews into their own files past ~80 lines. Name files after the
  primary type.
- Preview fixtures live in `*Mock.swift` / `EventPreviewFixture.swift` and **must** stay inside
  `#if DEBUG` — they ship in the app target.
- Typed errors (`APIError`, `AuthError`, `KeychainError`,
  `GoogleCalendarEventManager.MutationError`) with user-facing `errorDescription`.
- Logging via `Logger.shared`; mark interpolations `privacy: .public` only for non-PII values.
- Constants belong in `Utilities/Constants.swift` (`Constants`, `UI`, `DefaultsKey`,
  `EventStatus`, `EventType`) — no stringly-typed literals at call sites.
- Indentation is mixed across the codebase (2-space in newer files, 4-space in older ones).
  Match the file you are editing.

## Security rules

- OAuth tokens go in the Keychain via `KeychainService` and **nowhere else** — never SwiftData,
  never `UserDefaults`, never a log line.
- The client ID comes from `GOOGLE_CLIENT_ID` in `Config.xcconfig` → `Info.plist` →
  `AuthConfig.clientId`. There is no client secret (installed-app PKCE flow); do not add one.
- The app is sandboxed with hardened runtime, `network.client`, and a keychain access group.
  Do not widen entitlements to work around a problem.

## Build & Run

```bash
# Debug / test build (scheme: callisto, product: Callisto.app)
xcodebuild -project calendar.xcodeproj -scheme callisto -configuration Debug -destination 'platform=macOS' build

# Unit + UI tests
xcodebuild -project calendar.xcodeproj -scheme callisto -configuration Debug -destination 'platform=macOS' test

# Nightly build installed to ~/Applications (bundle id dev.frami.callisto.nightly)
make run
```

`Config.xcconfig` is required and git-ignored — `cp Config.xcconfig.example Config.xcconfig`
and set a real `GOOGLE_CLIENT_ID` (the placeholder builds but cannot authenticate).

**If `xcodebuild` is unavailable in your environment, ask the user to run the build/test
commands and report back.**

Build configurations: `Debug`, `Release`, `Nightly` (separate bundle id, icon, entitlements,
and display name so it can be installed side by side).

## Release

`main` → semantic-release (`.releaserc.json`) → GitHub release → `scripts/prepare-release.sh`
archives, signs with Developer ID, notarizes with `notarytool`, packages a zip + DMG, and
generates an EdDSA-signed Sparkle appcast. In-app updates are served from `SUFeedURL` in the
root `Info.plist`. Do not change `SUPublicEDKey`, the appcast URL, or the signing/notarization
steps without coordinating a key rotation.

CI (`.github/workflows/main.yml`, `pr.yml`) currently runs `build-for-testing` only — it
compiles the tests but does not execute them. `pr.yml` runs only on the `run-macos-ci` label
or manual dispatch.

## Known gaps

Do not assume these are handled; they are the current state, not the intended end state:

- **Sync is full-scan.** No `syncToken`, no `updatedMin`, no conditional ETag requests.
  `nextPageToken` is decoded but never followed, so `maxResults=250` silently truncates.
- **No backoff.** `APIError.rateLimited` exists but nothing retries or throttles; all
  `(account, calendar)` requests fire concurrently every cycle.
- **Attendees, attachments and reminders are deleted and reinserted on every sync**, for every
  event, changed or not.
- **Managers are not unit-testable** — `GoogleCalendarAPI` is constructed inline with no
  protocol seam. Tests cover DTO decoding, date parsing, PKCE, colors and model basics only.
- Each manager owns a separate `ModelContext` on the shared container, and the in-memory
  arrays — not SwiftData — are what the views read.
- `try? modelContext.save()` swallows persistence errors; sync failures surface only in logs.
