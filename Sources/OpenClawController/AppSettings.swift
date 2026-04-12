import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("openclawPath") var openclawPath: String = ""
    @AppStorage("sessionsPath") var sessionsPath: String = ""
    @AppStorage("agentName") var agentName: String = "main"
    @AppStorage("hasCompletedSetup") var hasCompletedSetup: Bool = false
    @AppStorage("authToken") var authToken: String = ""

    var resolvedOpenclawPath: String {
        if !openclawPath.isEmpty { return openclawPath }
        return Self.detectOpenclawPath() ?? "/opt/homebrew/bin/openclaw"
    }

    var resolvedSessionsPath: String {
        if !sessionsPath.isEmpty { return sessionsPath }
        let home = NSHomeDirectory()
        return "\(home)/.openclaw/agents/\(agentName)/sessions"
    }

    var openclawExists: Bool {
        FileManager.default.isExecutableFile(atPath: resolvedOpenclawPath)
    }

    var sessionsDirectoryExists: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: resolvedSessionsPath, isDirectory: &isDir) && isDir.boolValue
    }

    var sessionFileCount: Int {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: resolvedSessionsPath) else {
            return 0
        }
        return contents.filter { !$0.hasPrefix(".") }.count
    }

    static func detectOpenclawPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/openclaw",
            "/usr/local/bin/openclaw",
            "\(NSHomeDirectory())/.local/bin/openclaw",
            "/usr/bin/openclaw"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return whichOpenclaw()
    }

    static func detectSessionsPath(agent: String = "main") -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.openclaw/agents/\(agent)/sessions",
            "\(home)/.openclaw-dev/agents/\(agent)/sessions"
        ]
        for path in candidates {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return path
            }
        }
        return nil
    }

    static func listAgents() -> [String] {
        let home = NSHomeDirectory()
        let agentsDir = "\(home)/.openclaw/agents"
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: agentsDir) else {
            return ["main"]
        }
        let agents = contents.filter { name in
            !name.hasPrefix(".") && {
                var isDir: ObjCBool = false
                return FileManager.default.fileExists(atPath: "\(agentsDir)/\(name)", isDirectory: &isDir) && isDir.boolValue
            }()
        }.sorted()
        return agents.isEmpty ? ["main"] : agents
    }

    static func openclawVersion(at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    func resetToDefaults() {
        openclawPath = ""
        sessionsPath = ""
        agentName = "main"
        authToken = ""
    }

    func resetSetup() {
        hasCompletedSetup = false
        resetToDefaults()
    }

    private static func whichOpenclaw() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "openclaw"]
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin"
        if let existing = env["PATH"] {
            env["PATH"] = "\(extraPaths):\(existing)"
        } else {
            env["PATH"] = "\(extraPaths):/usr/bin:/bin"
        }
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return path.isEmpty ? nil : path
            }
        } catch {}
        return nil
    }
}
