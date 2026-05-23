# board-game-app-ios

SwiftUI iOS app for recording board-game sessions against the [`board-game-server`](../board-game-server/) backend. Pick from 15 supported games, fill in a tailored form for that game's end-state, and browse past records.

## Stack

- Xcode 26 / Swift 6 / SwiftUI / iOS 26 deployment target
- `@Observable` view models, Swift Testing (`@Test`), `NavigationStack`
- Strict concurrency enabled (`SWIFT_STRICT_CONCURRENCY = complete`)
- No third-party dependencies
- Project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Layout

```
BoardGameApp/
├── BoardGameAppApp.swift            # @main TabView (Create + Records)
├── Info.plist
├── Config/AppConfig.swift           # Reads ServerBaseURL / ApiKey from Info.plist
├── Models/
│   ├── GameSummary.swift            # server DTO
│   ├── GameRecord.swift             # server DTO
│   ├── RecordDraft.swift            # create-request payload (snake_case out)
│   └── GameCatalog.swift            # 15 hardcoded GameDefinition entries
├── Networking/
│   ├── APIClient.swift              # URLSession actor, snake_case codable
│   └── APIError.swift
└── Features/
    ├── GamePicker/GamePickerView.swift
    ├── CreateRecord/
    │   ├── CreateRecordView.swift
    │   ├── CreateRecordViewModel.swift
    │   ├── PlayerEditorView.swift
    │   └── EndStateFieldView.swift  # Stepper (int) / Toggle (bool) from schema
    ├── RecordsList/RecordsListView.swift
    └── RecordDetail/RecordDetailView.swift
```

## First-time setup

1. Install XcodeGen (once per machine):
   ```bash
   brew install xcodegen
   ```
2. Copy the example secrets file and adjust if needed:
   ```bash
   cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
   ```
   - `SERVER_BASE_URL` defaults to `http://localhost:8080` (works in the simulator, reaches the Mac's localhost).
   - For a physical iOS device on the same LAN, set `SERVER_BASE_URL` to `http://<Mac-LAN-IP>:8080`.
3. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
4. In Xcode, select the `BoardGameApp` target → **Signing & Capabilities** → set your development team and confirm **Sign in with Apple** is listed. Sign in with Apple works in the simulator too, but requires the capability to be enabled against a real team.
5. Start the server (see `../board-game-server/README.md`).
6. Open `BoardGameApp.xcodeproj` and ⌘R on any iOS 26 simulator. On first launch you'll be shown a Sign in with Apple screen; after that the JWT is persisted in Keychain and subsequent launches skip straight to the tabs.

## Authentication

The app uses **Sign in with Apple**. On success, the identity token is POSTed to `/api/auth/apple`, which returns a server JWT that gets stored in Keychain (`AuthStore` + `KeychainStore`). Every subsequent request sends it as `Authorization: Bearer <token>`. Signing out (Players tab → avatar menu → Sign Out) clears the Keychain entry and drops back to the login screen.

## Running tests

```bash
xcodebuild test \
  -project BoardGameApp.xcodeproj \
  -scheme BoardGameApp \
  -destination 'platform=iOS Simulator,OS=26.0,name=iPhone 16'
```

The Swift Testing suite asserts every supported slug is present, keys are unique per game, coup carries `yearPublished = 2012`, and identity-using games have non-empty enums.

## How the form is driven

Each game has a `GameDefinition` in `GameCatalog.swift` that mirrors its JSON Schema in the sibling `board-game-record` repo. The definition declares:

- `identityOptions` — shown as a Picker if non-empty.
- `supportsTeams` / `supportsElimination` — gate the Team Stepper and Eliminated Toggle.
- `endStateFields` — ordered list of fields. `.integer` renders a `Stepper`; `.boolean` renders a `Toggle`. Min/max are copied from the schema.

When the user submits, the draft is serialised with snake-cased keys (to match the canonical record shape) and POSTed to `/api/records`. Server-side validation errors are surfaced inline — each JSON Pointer path becomes a readable line in the error banner.

## Adding a new game

1. Land the schema in `board-game-record/games/<slug>/<slug>.schema.json`.
2. Rebuild the server so the updated schemas are copied into resources.
3. Add a `static let <slug> = GameDefinition(…)` entry in `GameCatalog.swift` mirroring the schema's `propertyNames.enum`, identity enum, and min/max.
4. Append the new constant to the `GameCatalog.all` array.
5. Extend `GameCatalogTests.swift`'s expected slug set.
