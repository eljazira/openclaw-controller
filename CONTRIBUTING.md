# Contributing to OpenClaw Controller

Thanks for your interest in contributing! This is a small project and we keep things simple.

## Getting Started

1. Fork and clone the repo
2. Make sure you have Xcode Command Line Tools: `xcode-select --install`
3. Build: `./build.sh`
4. Launch: `open OpenClawController.app`

## Making Changes

1. Create a branch: `git checkout -b my-change`
2. Make your edits in `Sources/OpenClawController/`
3. Rebuild and test: `./build.sh && killall OpenClawController 2>/dev/null; open OpenClawController.app`
4. Commit and push
5. Open a Pull Request

## Architecture

Read [DEVELOPER_NOTES.md](DEVELOPER_NOTES.md) for a full walkthrough of the codebase, including a cookbook for common edits (adding buttons, changing paths, etc.).

Quick overview:
- **AppSettings.swift** — configuration with auto-detection and persistence
- **GatewayController.swift** — all business logic (runs commands, manages state)
- **SetupWizardView.swift** — first-run onboarding
- **SettingsView.swift** — post-setup configuration
- **MenuBarContentView.swift** — menu bar popover
- **MainWindowView.swift** — main window with action cards and log

## Guidelines

- Keep it simple. This is a utility app, not a framework.
- Test your changes by actually using the app (click buttons, check the log).
- Don't add dependencies unless absolutely necessary. The whole app is vanilla SwiftUI.
- Match the existing code style (no SwiftLint config — just be consistent).

## Reporting Issues

Open a GitHub issue with:
- What you expected
- What happened instead
- Your macOS version and OpenClaw version (`openclaw --version`)

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
