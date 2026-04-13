import Foundation
import SwiftUI

@MainActor
final class GatewayController: ObservableObject {
    let settings: AppSettings

    struct LogLine: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: Level
        let text: String

        enum Level {
            case info, success, error, command, warning
        }
    }

    @Published var logLines: [LogLine] = []
    @Published var isBusy: Bool = false
    @Published var sessionCount: Int = 0
    @Published var lastAction: String = "Idle"

    private var refreshTimer: Timer?

    init(settings: AppSettings) {
        self.settings = settings
        refreshSessionCount()
        log("OpenClaw Controller ready", level: .success)
        log("Sessions: \(settings.resolvedSessionsPath)", level: .info)
        startAutoRefresh()
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSessionCount()
            }
        }
    }

    func refreshSessionCount() {
        sessionCount = settings.sessionFileCount
    }

    private func log(_ text: String, level: LogLine.Level = .info) {
        logLines.append(LogLine(timestamp: Date(), level: level, text: text))
        if logLines.count > 2000 {
            logLines.removeFirst(logLines.count - 2000)
        }
    }

    func clearLog() {
        logLines.removeAll()
        log("Log cleared", level: .info)
    }

    private var clawPath: String { settings.resolvedOpenclawPath }
    private var sessPath: String { settings.resolvedSessionsPath }

    func stopGateway() async {
        guard !isBusy else { return }
        isBusy = true
        lastAction = "Stopping gateway…"
        defer { isBusy = false; lastAction = "Idle" }
        log("$ openclaw gateway stop", level: .command)
        await runCommand(clawPath, args: ["gateway", "stop"])
    }

    func startGateway() async {
        guard !isBusy else { return }
        isBusy = true
        lastAction = "Starting gateway…"
        defer { isBusy = false; lastAction = "Idle" }
        log("$ openclaw gateway start", level: .command)
        await runCommand(clawPath, args: ["gateway", "start"])
    }

    func restartGateway() async {
        guard !isBusy else { return }
        isBusy = true
        lastAction = "Restarting gateway…"
        defer { isBusy = false; lastAction = "Idle" }
        log("$ openclaw gateway restart", level: .command)
        await runCommand(clawPath, args: ["gateway", "restart"])
    }

    func statusGateway() async {
        guard !isBusy else { return }
        isBusy = true
        lastAction = "Checking status…"
        defer { isBusy = false; lastAction = "Idle" }
        log("$ openclaw gateway status", level: .command)
        await runCommand(clawPath, args: ["gateway", "status"])
    }

    func clearSessions() async {
        guard !isBusy else { return }
        isBusy = true
        lastAction = "Clearing sessions…"
        defer { isBusy = false; lastAction = "Idle" }

        log("Clearing sessions in: \(sessPath)", level: .command)

        let fm = FileManager.default
        guard fm.fileExists(atPath: sessPath) else {
            log("Sessions directory does not exist: \(sessPath)", level: .warning)
            return
        }

        do {
            let contents = try fm.contentsOfDirectory(atPath: sessPath)
            var deleted = 0
            var failed = 0
            for item in contents where !item.hasPrefix(".") {
                let path = "\(sessPath)/\(item)"
                do {
                    try fm.removeItem(atPath: path)
                    deleted += 1
                } catch {
                    failed += 1
                    log("Failed to delete \(item): \(error.localizedDescription)", level: .error)
                }
            }
            if failed == 0 {
                log("Deleted \(deleted) session file(s)", level: .success)
            } else {
                log("Deleted \(deleted), failed \(failed)", level: .warning)
            }
        } catch {
            log("Failed to list directory: \(error.localizedDescription)", level: .error)
        }
        refreshSessionCount()
    }

    func fullReset() async {
        guard !isBusy else { return }
        isBusy = true
        lastAction = "Full reset in progress…"
        defer { isBusy = false; lastAction = "Idle" }

        log("=== FULL RESET ===", level: .command)

        log("Step 1/3 — Stopping gateway", level: .info)
        log("$ openclaw gateway stop", level: .command)
        await runCommand(clawPath, args: ["gateway", "stop"])

        log("Step 2/3 — Clearing session files", level: .info)
        let fm = FileManager.default
        if fm.fileExists(atPath: sessPath) {
            do {
                let contents = try fm.contentsOfDirectory(atPath: sessPath)
                var deleted = 0
                for item in contents where !item.hasPrefix(".") {
                    let path = "\(sessPath)/\(item)"
                    try? fm.removeItem(atPath: path)
                    deleted += 1
                }
                log("Deleted \(deleted) session file(s)", level: .success)
            } catch {
                log("Failed: \(error.localizedDescription)", level: .error)
            }
        } else {
            log("Sessions directory does not exist", level: .warning)
        }
        refreshSessionCount()

        log("Step 3/3 — Restarting gateway", level: .info)
        log("$ openclaw gateway restart", level: .command)
        await runCommand(clawPath, args: ["gateway", "restart"])

        log("=== FULL RESET COMPLETE ===", level: .success)
    }

    func testConnectivity() async -> Bool {
        log("Testing connectivity…", level: .command)
        log("$ openclaw gateway status", level: .command)

        let path = clawPath
        let result = await Task.detached(priority: .userInitiated) { () -> (Int32, String) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["gateway", "status"]
            Self.configureProcessEnv(process)
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
            } catch {
                return (-1, error.localizedDescription)
            }
        }.value

        let stripped = Self.stripAnsi(result.1)
        for line in stripped.split(separator: "\n", omittingEmptySubsequences: true) {
            log(String(line), level: .info)
        }

        if result.0 == 0 {
            log("Connection OK", level: .success)
            return true
        } else {
            log("Connection failed (exit \(result.0))", level: .error)
            return false
        }
    }

    private func runCommand(_ path: String, args: [String]) async {
        let task = Task.detached(priority: .userInitiated) { () -> (Int32, String) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            Self.configureProcessEnv(process)

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                return (-1, "Failed to start: \(error.localizedDescription)")
            }

            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        }

        let (status, output) = await task.value

        let stripped = Self.stripAnsi(output)
        let lines = stripped.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines {
            let trimmed = String(line)
            if trimmed.isEmpty { continue }
            let level: LogLine.Level
            let lower = trimmed.lowercased()
            if lower.contains("error") || lower.contains("fatal") {
                level = .error
            } else if lower.contains("warn") {
                level = .warning
            } else {
                level = .info
            }
            log(trimmed, level: level)
        }

        if status == 0 {
            log("Command completed successfully", level: .success)
        } else if status == -1 {
            log(output, level: .error)
        } else {
            log("Command exited with status \(status)", level: .error)
        }
    }

    nonisolated private static func configureProcessEnv(_ process: Process) {
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin"
        if let existing = env["PATH"] {
            if !existing.contains("/opt/homebrew/bin") {
                env["PATH"] = "\(extraPaths):\(existing)"
            }
        } else {
            env["PATH"] = "\(extraPaths):/usr/bin:/bin"
        }
        process.environment = env
    }

    nonisolated static func stripAnsi(_ input: String) -> String {
        let pattern = "\u{001B}\\[[0-9;?]*[a-zA-Z]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: "")
    }
}
