# CalendarBar — macOS Menu Bar Google Calendar App

## Project Overview

A **menu bar only** macOS application that displays Google Calendar events. Built with Swift, SwiftUI, SwiftData, and Keychain for secure credential storage. Supports multiple Google accounts.

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI (menu bar popover, no main window)
- **Data persistence:** SwiftData (events, account metadata)
- **Secrets:** macOS Keychain (OAuth tokens)
- **Auth:** Google OAuth 2.0 (installed app / PKCE flow)
- **API:** Google Calendar API v3
- **Platform:** macOS 26.2+

## Architecture

```
calendar/
├── App/                    # App entry point, menu bar setup
├── Models/                 # SwiftData models (Account, CalendarEvent, etc.) + value types like EventDay
├── Services/
│   ├── Auth/               # Google OAuth, token management
│   ├── Keychain/           # Keychain wrapper for secrets
│   └── GoogleCalendar/     # Google Calendar API client
├── Views/
│   ├── MenuBar/            # Menu bar icon, popover
│   ├── Events/             # Event list, event detail
│   ├── Accounts/           # Account management, add/remove
│   └── Settings/           # Preferences (refresh interval, etc.)
└── Utilities/              # Date helpers, extensions
```

## Key Design Decisions

- **Menu bar only:** Uses `MenuBarExtra` — no Dock icon, no main window.
- **Multi-account:** Each Google account stored as a SwiftData `Account` entity. OAuth tokens stored in Keychain keyed by account ID.
- **Keychain for secrets:** Never persist OAuth tokens in SwiftData or UserDefaults. All tokens (access + refresh) go through the Keychain wrapper.
- **Background refresh:** Timer-based polling of the Google Calendar API. Respect API rate limits.
- **No external dependencies:** Use Foundation `URLSession` for networking. No third-party packages.

## Architectural Considerations — 5 Distinct Owners

| Concern | Owner | Type |
|---|---|---|
| Sync + Auth + Timer | `CalendarService` | `Sendable` class |
| Account & Calendar CRUD | `AccountService` | `@MainActor @Observable` |
| Settings | `UserSettings` | `@MainActor @Observable` |
| Event view state (read-only) | `CalendarStore` | `@MainActor @Observable` |
| Account/calendar view state (read-only) | `AccountStore` | `@MainActor @Observable` |

### CalendarStore (event-only read layer)

- Stores only events, scoped to a rolling `[yesterday, today + 31 days]` window.
- Receives new event data via `update(account:events:)` — called once per account by the snapshot dispatcher in `CalendarApp`. Upserts events (plus attendees, attachments, reminders) and deletes stale events scoped to that account.
- `prune()` is public and deletes events with `endDate < yesterday`. External code (e.g. the snapshot dispatcher) decides when to call it.
- Exposes **iterator methods** that SwiftUI views consume in `ForEach`:
  - `iter(settings: UserSettings? = nil) -> [CalendarEvent]` — chronologically ordered events, with structural filters (enabled account, visible calendar, not cancelled, not ended). When `settings` is provided, applies `showDaysAhead` and `showDeclinedEvents`.
  - `iterDays(settings: UserSettings? = nil) -> [EventDay]` — one entry per day with at least one event. Each `EventDay` has a `day: Date` and `iter()` returning that day's events flat-ordered by `startDate`.
- `nextEvent: CalendarEvent?` — recomputed on every `update(account:events:)` / `prune()` call.
- Uses an internal `version` counter read inside `iter()` / `iterDays()` so `@Observable` tracks method-based access and SwiftUI views re-render after mutations.

### AccountStore (account/calendar read layer)

- Mirrors `CalendarStore`'s role but for accounts and their calendar metadata.
- Exposes `accounts: [Account]`, refreshed via `refreshData()` after `AccountService` mutations.
- `update(account:calendars:)` upserts the calendar list for an account from a sync snapshot and removes stale calendars.

### CalendarService (sync orchestration)

- Owns `SyncTimer`, `AccountSync`, `GoogleAuthService`, `SyncStatus`, backoff logic, and the `sync()` entry point.
- Fetches calendar and event data from the Google Calendar API and produces `SyncSnapshot` values — immutable `Sendable` structs.
- Never writes to `ModelContext` directly. Produces snapshots via `AsyncStream` and a `@MainActor var onSnapshot: ((SyncSnapshot) -> Void)?` callback that `CalendarApp` wires to fan snapshots out per-account to `AccountStore` / `CalendarStore`.
- `addAccount()` runs the OAuth consent flow and returns a `NewAccountResult` — does not write to SwiftData.

### AccountService (account & calendar CRUD)

- Owns all SwiftData writes for accounts and calendars, plus Keychain cleanup.
- `insertAccount(from:)` creates an Account from a `NewAccountResult`, saves tokens to Keychain, and triggers initial sync.
- `removeAccount(_:)`, `toggleAccountEnabled(_:)`, `toggleCalendarVisible(_:)` mutate SwiftData and notify downstream.
- After each mutation, calls `accountStore.refreshData()` and `syncService.updateAccounts(...)`.

### AccountSync (actor for token lifecycle)

- `AccountSync` is a dedicated `actor` that manages OAuth token refresh and validation.
- It owns the logic for `validAccessToken(for:)` and `refreshTokens(for:)`, serializing Keychain reads/writes and token refresh network calls.
- `CalendarService` calls `AccountSync` to obtain valid access tokens before making API requests.
- `GoogleAuthService` retains only the initial OAuth consent flow (`startOAuthFlow`); all token lifecycle logic lives in `AccountSync`.

### UserSettings (user preferences)

- `@MainActor @Observable`, backed by a `SettingsStore` protocol (production: `UserDefaults`; tests/previews: `InMemorySettingsStore`).
- Views read and write it directly — no proxy methods needed.
- Passed into `CalendarStore.iter(settings:)` / `iterDays(settings:)` at call sites to apply display preferences.

### Data flow

```
                     CalendarApp (creates all, wires once)
          ┌──────────┬──────────────┬──────────────┐
          ▼          ▼              ▼              ▼
  CalendarService     AccountService CalendarStore AccountStore
  ┌──────────────┐  ┌─────────────┐ ┌────────────┐ ┌────────────┐
  │ sync()       │  │ insertAcct  │ │ update(    │ │ accounts   │
  │ addAccount() │  │ remove()    │ │   account, │ │ refresh()  │
  │ SyncTimer    │  │ toggle()    │ │   events)  │ │ update(    │
  │ AccountSync  │  │ toggleCal() │ │ prune()    │ │   account, │
  │ onSnapshot   │  │ ModelContext│ │ iter()     │ │   calendars)│
  │ SyncStatus   │  │ Keychain    │ │ iterDays() │ │ ModelContext│
  └──────┬───────┘  └──────┬──────┘ │ nextEvent  │ └─────┬──────┘
         │                 │        └─────┬──────┘       │
         │ onSnapshot(SyncSnapshot) — dispatched per-account
         └─────────────────┼──────────────┼──────────────┘
                           │              │
                    refreshData()   update(account:events:)
                    update(account:calendars:)
                           │              │
                           └──────┬───────┘
                                  ▼
                           SwiftUI Views
                           (ForEach over store.iterDays(settings:),
                            accountStore.accounts for account list,
                            store.nextEvent for menu bar label)

    Views read/write UserSettings directly
    Views pass UserSettings into store.iter*(settings:) calls
    Views call syncService.sync() (→ onSnapshot → stores update)
    Views call accountService.remove() (→ accountStore.refreshData)
```

## Build & Run

```bash
# Open in Xcode
open calendar.xcodeproj

# Build from command line
xcodebuild -scheme calendar -configuration Debug build

# Run tests
xcodebuild -scheme calendar -configuration Debug test
```

**Important:** If `xcodebuild` is not available in your environment, ask the user to run the build/test commands and report back the results.

## Conventions

- Use Swift concurrency (async/await) throughout — no completion handlers.
- Prefer value types (structs/enums) except for SwiftData `@Model` classes.
- Keep views small; extract subviews into separate files when they exceed ~80 lines.
- Name files after the primary type they contain.
- Group related files in folders matching the architecture above.
- Error handling: use typed Swift errors, surface user-facing messages in the UI.
