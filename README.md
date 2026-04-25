# CalendarBar

A lightweight macOS menu bar app for viewing Google Calendar events.

## Features

- **Menu bar only** — lives in your menu bar with no Dock icon or main window
- **Settings window** — dedicated window with sectioned settings (Sync, Accounts, Debug), opened via the gear icon
- **Multi-account** — link multiple Google accounts and toggle them independently
- **Background sync** — automatic polling at a configurable interval (1–10 minutes)
- **Keychain security** — OAuth tokens are stored exclusively in the macOS Keychain
- **Per-calendar visibility** — show or hide individual calendars from the event list
- **No external dependencies** — built entirely with Apple frameworks (SwiftUI, SwiftData, CryptoKit, Security, AuthenticationServices)

## Requirements

- macOS 26.2+
- Xcode 26+
- A Google Cloud project with OAuth 2.0 credentials (Desktop / Installed app type)

## Setup

### 1. Google Cloud Console

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project (or select an existing one).
3. Enable the **Google Calendar API**.
4. Go to **APIs & Services → Credentials** and create an **OAuth 2.0 Client ID** (application type: **Desktop app**).
5. Note the **Client ID** — you will need it in the next step.

### 2. Configure the project

Create a file at the project root named `Config.xcconfig`:

```
GOOGLE_CLIENT_ID = <your-client-id>.apps.googleusercontent.com
```

This value is read at runtime via `Info.plist` → `GOOGLE_CLIENT_ID`.

### 3. Build and run

```bash
# Open in Xcode
open calendar.xcodeproj

# Or build from the command line
xcodebuild -scheme calendar -configuration Debug build
```

### 4. Run tests

```bash
# Unit tests
xcodebuild -scheme calendar -configuration Debug test

# The project includes two test targets: calendarTests and calendarUITests
```

## Architecture

```
calendar/
├── App/                        # App entry point, AppDelegate, menu bar + settings window setup
├── Models/                     # SwiftData models (Account, GoogleCalendar, CalendarEvent)
├── Services/
│   ├── Auth/                   # Google OAuth 2.0 with PKCE via ASWebAuthenticationSession
│   ├── Keychain/               # Keychain wrapper for secure token storage
│   └── GoogleCalendar/         # API client, sync service, background sync manager
│       └── DTOs/               # Codable response types for the Google Calendar API
├── Views/
│   ├── MenuBar/                # Popover (events only), header, footer, view model
│   ├── Events/                 # Event list, event row, all-day section
│   ├── Accounts/               # Account list, add account button
│   └── Settings/               # Settings window with Sync, Accounts, and Debug sections
└── Utilities/                  # Date helpers, formatters, Color hex extension
```

### Layer overview

| Layer | Responsibility |
|-------|---------------|
| **App** | Bootstraps the `MenuBarExtra` and settings `Window`, creates the SwiftData container |
| **Models** | SwiftData `@Model` classes representing accounts, calendars, and events |
| **Services** | All business logic — OAuth via `ASWebAuthenticationSession`, Keychain access, API calls, sync orchestration |
| **Views** | SwiftUI views for the popover and settings window, broken into focused subviews |
| **Utilities** | Stateless helpers for date formatting and color parsing |

## Key Design Decisions

- **`MenuBarExtra` with `.window` style** — provides a native popover anchored to the menu bar icon without a Dock presence.
- **Separate settings window** — settings, account management, and login are in a proper macOS window (`Window` scene with `id: "settings"`), keeping the popover focused on events.
- **`ASWebAuthenticationSession` for OAuth** — combines browser-open and redirect-capture into one API call with built-in cancellation, replacing the fragile `NSWorkspace.open()` + Apple Event handler approach.
- **SwiftData for local persistence** — accounts, calendars, and events are stored locally so the UI can render instantly before a sync completes.
- **Keychain for OAuth tokens** — access and refresh tokens never touch SwiftData or `UserDefaults`. All token I/O goes through `KeychainService`.
- **PKCE auth flow** — the OAuth flow uses Proof Key for Code Exchange (S256) to secure the authorization code, even though the app is a native desktop client.
- **Exponential backoff** — when the Google API returns HTTP 429, `SyncTimer` doubles the retry interval (up to 1 hour) before resuming normal polling.

## How It Works

1. The user clicks **Add Account** in the settings window, which launches `ASWebAuthenticationSession` for Google OAuth consent.
2. After consent, `ASWebAuthenticationSession` captures the redirect to the custom URL scheme (`com.googleusercontent.apps.<client-id>`) automatically.
3. The auth service extracts the authorization code, exchanges it for tokens (using PKCE), fetches the user's profile, and publishes the result. The UI observes this and creates the account in SwiftData + Keychain.
4. `CalendarService` fetches the calendar list and events from the Google Calendar API, upserting them into SwiftData.
5. `MenuBarViewModel` filters and groups events by day, and the SwiftUI views render them in the popover.
6. A repeating `Timer` in `SyncTimer` triggers periodic re-syncs at the user's configured interval.
7. The gear icon in the popover header opens the settings window via `openWindow(id: "settings")`.

## Contributing

- Use Swift concurrency (`async`/`await`) throughout — no completion handlers.
- Prefer value types (structs/enums) except for SwiftData `@Model` classes.
- Keep views small; extract subviews when they exceed ~80 lines.
- Name files after the primary type they contain.
- Use typed Swift errors and surface user-facing messages in the UI.
- No external dependencies — use Foundation `URLSession` for networking.

## License

This project is not yet licensed. A license will be added in a future release.
