# OpenClaw Controller — Developer Notes

A native macOS menu bar + window app that runs the most common OpenClaw gateway
operations (stop / start / restart / clear sessions / status) as one-click buttons.
Built because the daily `stop → wipe sessions → restart` loop through the terminal
was painful.

Session name for memory: **OpenClaw Controller**

---

## TL;DR — How to run it

**Right now, launch the already-built app:**
```sh
open /Users/doc9/OpenClawController/OpenClawController.app
```
→ Look at the top-right of your screen for a ⚡ bolt icon in the menu bar. Click it.

**Quit it:**
```sh
killall OpenClawController
```
Or click the bolt icon → **Quit**.

**Make it auto-launch on login (recommended):**
1. Move the app into Applications:
   ```sh
   mv /Users/doc9/OpenClawController/OpenClawController.app /Applications/
   ```
2. System Settings → General → Login Items & Extensions → click **+** under "Open at Login" → select `OpenClawController` from `/Applications`.
3. Launch once manually (`open -a OpenClawController`) so it appears in the menu bar immediately.

**After editing source files, rebuild + relaunch:**
```sh
cd /Users/doc9/OpenClawController \
  && ./build.sh \
  && killall OpenClawController 2>/dev/null; \
  open OpenClawController.app
```

**First-time build from scratch (only needed if you delete `.build/`):**
```sh
cd /Users/doc9/OpenClawController
./build.sh
open OpenClawController.app
```

**How to use it** — click the bolt in the menu bar, then:
- **Check Status** → safe read-only sanity test
- **Stop / Start / Restart Gateway** → individual actions
- **Clear Sessions** → wipes `.jsonl` files in the sessions dir (badge shows count)
- **Full Reset** → stop → clear → restart in one click (the thing you do most)
- **Open Window** → opens the larger window with cards + live log

---

## 1. What was built

| Piece | Purpose |
|---|---|
| **Swift Package** at `/Users/doc9/OpenClawController` | Source + build scripts |
| **Menu bar icon** (⚡ bolt) | Always-visible; click to open the popover |
| **Popover menu** | Quick actions: Stop / Clear / Restart / Full Reset / Status / Open Window / Quit |
| **Main window** | Bigger UI with action cards + live color-coded log + status bar |
| **`GatewayController`** | All logic: runs shell commands, deletes session files, tracks state |
| **`build.sh`** | Compiles the Swift package and packages it into a real `.app` bundle |

Runnable artifact: `/Users/doc9/OpenClawController/OpenClawController.app`

---

## 2. Why each decision

- **SwiftUI, not Electron / Tauri / Python** — feels native, fast to launch, zero runtime deps, first-class menu bar support via `MenuBarExtra`.
- **Swift Package + manual `.app` bundle** — you only have Command Line Tools (no full Xcode), so `swift build` + hand-rolled `Info.plist` is the cleanest path.
- **`LSUIElement=true`** — makes it a true menu-bar-only app (no dock clutter by default). Dock icon only appears when you open the main window, so the app still feels "real" when you're interacting with it.
- **Absolute path to `openclaw`** (`/opt/homebrew/bin/openclaw`) — app bundles don't inherit your shell's PATH, so relying on `openclaw` in PATH would silently break. The controller also prepends `/opt/homebrew/bin` into `Process.environment` as a belt-and-suspenders.
- **Not streaming output, just collecting at end** — gateway commands return in well under a second (they just talk to launchd). Streaming would add complexity for no visible benefit.
- **`isBusy` flag + `.disabled()`** — prevents double-clicks and overlapping runs. Simple, reliable.

---

## 3. File map

```
/Users/doc9/OpenClawController/
├── Package.swift                        # Swift 5.9 manifest, targets macOS 14+
├── build.sh                             # swift build -c release → .app bundle
├── DEVELOPER_NOTES.md                   # this file
├── Sources/OpenClawController/
│   ├── App.swift                        # @main, MenuBarExtra + Window scenes
│   ├── MenuBarContentView.swift         # Popover that appears under the bolt icon
│   ├── MainWindowView.swift             # The big window (cards, log, status bar)
│   └── GatewayController.swift          # ObservableObject — all the logic
└── OpenClawController.app/              # Built bundle (safe to delete, rebuilt on ./build.sh)
    └── Contents/
        ├── Info.plist                   # LSUIElement, bundle id, version
        ├── MacOS/OpenClawController     # The compiled binary
        └── Resources/
```

### What each Swift file owns

- **`App.swift`** — entry point. Defines two SwiftUI *scenes*:
  - `MenuBarExtra { MenuBarContentView(...) } label: { Image(...) }` — the menu bar icon + popover
  - `Window("OpenClaw Controller", id: "main") { MainWindowView() }` — the detachable window
  - `onAppear` on the window calls `NSApp.setActivationPolicy(.regular)` so the window can take focus.

- **`MenuBarContentView.swift`** — compact 260pt-wide popover. Each row is a `menuButton(...)` helper. When the window button is clicked, it calls `openWindow(id: "main")`.

- **`MainWindowView.swift`** — the full window. Split into four sections (header / button grid / log / status bar). `ActionCard` is the big button style. `LogLineView` formats each log entry with a color and symbol based on `LogLine.Level`.

- **`GatewayController.swift`** — the brain. `@MainActor ObservableObject`. Owns:
  - `logLines: [LogLine]` — the log (capped at 2000 entries)
  - `isBusy: Bool` — prevents overlapping work
  - `sessionCount: Int` — displayed in the badge and status bar
  - `lastAction: String` — shown while busy
  - Methods: `stopGateway`, `startGateway`, `restartGateway`, `statusGateway`, `clearSessions`, `fullReset`
  - `runCommand(path:args:)` — private helper that runs a `Process` inside `Task.detached`, waits for exit, strips ANSI, logs the output, and reports the exit status.

---

## 4. How to build / run / install

```sh
# Build + package
cd /Users/doc9/OpenClawController
./build.sh

# Run in place
open /Users/doc9/OpenClawController/OpenClawController.app

# Install into Applications (recommended)
mv /Users/doc9/OpenClawController/OpenClawController.app /Applications/
open -a OpenClawController

# Auto-launch on login
# System Settings → General → Login Items → + → pick OpenClawController
```

Rebuild + relaunch in one line:
```sh
cd /Users/doc9/OpenClawController \
  && ./build.sh \
  && killall OpenClawController 2>/dev/null; \
  open OpenClawController.app
```

---

## 5. Common edits (cookbook)

### Add a new button (example: "Open Dashboard")

1. **Add the method** in `GatewayController.swift` near the other `func *Gateway()` methods:
   ```swift
   func openDashboard() async {
       guard !isBusy else { return }
       isBusy = true
       lastAction = "Opening dashboard…"
       defer { isBusy = false; lastAction = "Idle" }
       log("$ openclaw dashboard", level: .command)
       await runCommand(Self.openclawPath, args: ["dashboard"])
   }
   ```

2. **Add to the popover** in `MenuBarContentView.swift` — copy one of the existing `menuButton(...)` calls inside the second VStack:
   ```swift
   menuButton(title: "Open Dashboard", icon: "safari", tint: .cyan) {
       Task { await controller.openDashboard() }
   }
   ```

3. **Add to the big window** in `MainWindowView.swift`'s `buttonGrid` — add another `ActionCard(...)` to one of the `HStack` rows:
   ```swift
   ActionCard(
       title: "Open Dashboard",
       subtitle: "openclaw dashboard",
       icon: "safari",
       tint: .cyan
   ) {
       Task { await controller.openDashboard() }
   }
   ```

4. `./build.sh && killall OpenClawController; open OpenClawController.app`

### Change the sessions path

Edit the constant at the top of `GatewayController.swift`:
```swift
static let sessionsPath = "/Users/doc9/.openclaw/agents/main/sessions"
```

### Change the openclaw binary location

Edit `GatewayController.openclawPath`. If homebrew is at `/usr/local/bin`:
```swift
static let openclawPath = "/usr/local/bin/openclaw"
```
Also update the PATH prepend inside `runCommand` if you drop homebrew entirely.

### Switch between menu-bar-only and normal app

In `build.sh`, the `Info.plist` heredoc has:
```xml
<key>LSUIElement</key>
<true/>
```
Change to `<false/>` to always show a dock icon. Rebuild.

### Add a keyboard shortcut to Full Reset

In `MenuBarContentView.swift`, add `.keyboardShortcut("r", modifiers: [.command, .shift])` to the Full Reset button. Only works while the menu bar popover is open, unless you move the shortcut to a menu item on the main window.

### Add log export

In `MainWindowView.swift`, add a button next to "Clear Log" that runs:
```swift
let panel = NSSavePanel()
panel.nameFieldStringValue = "openclaw-log.txt"
if panel.runModal() == .OK, let url = panel.url {
    let text = controller.logLines.map { "\($0.timestamp) \($0.text)" }.joined(separator: "\n")
    try? text.write(to: url, atomically: true, encoding: .utf8)
}
```

---

## 6. Gotchas (things that already bit us or will bite you)

### Bash `${VAR}` braces in `build.sh`
`build.sh` uses `set -euo pipefail`. The Unicode ellipsis `…` is NOT a word-break character in bash, so `"$APP_BUNDLE…"` gets parsed as the variable `APP_BUNDLE…` and errors out as "unbound variable". Always use `"${APP_BUNDLE}…"` when a variable is followed by non-ASCII or alphanumeric characters.

### PATH inside the .app
macOS doesn't give `.app` bundles your shell PATH. We already prepend `/opt/homebrew/bin:/opt/homebrew/sbin` inside `runCommand`. If you add commands from `/usr/local/bin`, `~/bin`, etc., extend that block or they'll fail silently.

### Not code-signed / notarized
First launch after download may be blocked by Gatekeeper. Right-click → Open once to whitelist. For personal local use this is fine; do not distribute.

### `LSUIElement=true` + window focus
Because the app starts as "accessory" (no dock), opening the window requires calling `NSApp.setActivationPolicy(.regular)` and `NSApp.activate(...)` — the App.swift `onAppear` does this. If the window ever refuses to come to the front, that's the hook to check.

### Don't wire up `openclaw gateway run`
`run` is the foreground version — it blocks and streams forever. The `runCommand` helper uses `waitUntilExit`, so clicking a button wired to `run` would lock the UI until you kill the process. Use `start` (launchd) instead.

### Clearing sessions is immediate, no confirmation
By design — you do this dozens of times a day. If you ever want a confirm dialog, wrap the call in an `NSAlert` inside `clearSessions()`.

### Log auto-scroll
`MainWindowView.logView` uses `ScrollViewReader` + `onChange(of: logLines.count)` to scroll to the last entry. Scrolls happen on every log append. If you want to stop auto-scroll when the user scrolls up, you'd need to track scroll offset and add a "jump to bottom" button.

### Session count doesn't auto-refresh
It only updates on app launch, after clear operations, and when you click the refresh button in the header. If openclaw writes new session files while the window is open, the count stays stale. Add a `Timer` inside `GatewayController.init` if you want live tracking.

---

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| Menu bar icon doesn't appear | `ps aux \| grep OpenClawController` — if running, toggle the menu bar (⌘ Drag to rearrange) or reboot. If not running, check Console.app for crash logs. |
| Clicking Status shows "Failed to start" | `openclaw` isn't at `/opt/homebrew/bin/openclaw`. Run `which openclaw` and update `GatewayController.openclawPath`. |
| "Command exited with status 1" on Stop | Gateway already stopped. Harmless. |
| Build fails with "unbound variable" in build.sh | See §6 — use `${VAR}` braces. |
| Swift compile errors after edit | `rm -rf .build && ./build.sh` for a clean rebuild. |
| Window won't come to front | See §6 — activation policy. Check `App.swift` `onAppear` hook. |

---

## 8. Future ideas (not built yet)

- **Notifications** — native banner when a long operation finishes
- **File watcher auto-reset** — watch a config file and trigger Full Reset on save
- **Session viewer** — show recent `.jsonl` filenames and let you tail them
- **Multiple agents** — currently hardcoded to `main`; expand to any dir under `~/.openclaw/agents/*`
- **Dashboard launcher** — wire up `openclaw dashboard`
- **Profile switcher** — use `--profile` to switch between dev / prod gateways
- **Health polling** — background `openclaw gateway probe` every N seconds to show live state dot in menu bar icon

---

## 9. Quick reference — all commands this app runs

| Button | Exact command | Side effect |
|---|---|---|
| Stop Gateway | `openclaw gateway stop` | Stops launchd service |
| Start Gateway | `openclaw gateway start` | Starts launchd service |
| Restart Gateway | `openclaw gateway restart` | Stops + starts |
| Check Status | `openclaw gateway status` | Read-only, safe |
| Clear Sessions | `rm` on every non-dotfile in `/Users/doc9/.openclaw/agents/main/sessions` | Deletes session `.jsonl` files |
| Full Reset | `stop` → clear sessions → `restart` | All three in sequence |
