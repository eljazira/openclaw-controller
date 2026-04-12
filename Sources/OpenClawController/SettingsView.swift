import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var openclawPath: String = ""
    @State private var sessionsPath: String = ""
    @State private var agentName: String = "main"
    @State private var agents: [String] = ["main"]
    @State private var detectedVersion: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenClaw Binary")
                            .font(.system(size: 13, weight: .semibold))
                        HStack {
                            TextField("/path/to/openclaw", text: $openclawPath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                            Button("Browse…") { browseForFile() }
                                .controlSize(.small)
                            Button("Detect") { autoDetectCLI() }
                                .controlSize(.small)
                        }
                        if !detectedVersion.isEmpty {
                            Text(detectedVersion)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        let path = openclawPath.isEmpty ? (AppSettings.detectOpenclawPath() ?? "") : openclawPath
                        if !path.isEmpty {
                            let exists = FileManager.default.isExecutableFile(atPath: path)
                            Label(
                                exists ? "Binary found" : "Binary not found at this path",
                                systemImage: exists ? "checkmark.circle.fill" : "xmark.circle.fill"
                            )
                            .font(.system(size: 11))
                            .foregroundStyle(exists ? .green : .red)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Agent")
                            .font(.system(size: 13, weight: .semibold))
                        Picker("Active agent:", selection: $agentName) {
                            ForEach(agents, id: \.self) { agent in
                                Text(agent).tag(agent)
                            }
                        }
                        .frame(maxWidth: 200)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sessions Directory")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Leave empty to use the default path for the selected agent.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("~/.openclaw/agents/\(agentName)/sessions", text: $sessionsPath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                            Button("Browse…") { browseForFolder() }
                                .controlSize(.small)
                        }
                        let resolved = sessionsPath.isEmpty
                            ? "\(NSHomeDirectory())/.openclaw/agents/\(agentName)/sessions"
                            : sessionsPath
                        let exists = FileManager.default.fileExists(atPath: resolved)
                        Label(
                            exists ? "Directory exists (\(countFiles(at: resolved)) files)" : "Directory not found",
                            systemImage: exists ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(exists ? .green : .orange)
                    }
                }

                Section {
                    Button("Re-run Setup Wizard…") {
                        settings.resetSetup()
                        dismiss()
                    }
                    .foregroundStyle(.orange)

                    Button("Reset All Settings to Defaults") {
                        settings.resetToDefaults()
                        loadFromSettings()
                    }
                    .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    saveToSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 520, height: 480)
        .onAppear { loadFromSettings() }
    }

    private func loadFromSettings() {
        openclawPath = settings.openclawPath
        sessionsPath = settings.sessionsPath
        agentName = settings.agentName
        agents = AppSettings.listAgents()
        if !agents.contains(agentName) {
            agents.append(agentName)
        }
        updateVersion()
    }

    private func saveToSettings() {
        settings.openclawPath = openclawPath
        settings.sessionsPath = sessionsPath
        settings.agentName = agentName
    }

    private func autoDetectCLI() {
        if let path = AppSettings.detectOpenclawPath() {
            openclawPath = path
            updateVersion()
        }
    }

    private func updateVersion() {
        let path = openclawPath.isEmpty ? (AppSettings.detectOpenclawPath() ?? "") : openclawPath
        if !path.isEmpty {
            detectedVersion = AppSettings.openclawVersion(at: path) ?? ""
        }
    }

    private func countFiles(at path: String) -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: path))?.filter { !$0.hasPrefix(".") }.count ?? 0
    }

    private func browseForFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the openclaw binary"
        if panel.runModal() == .OK, let url = panel.url {
            openclawPath = url.path
            updateVersion()
        }
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the sessions directory"
        if panel.runModal() == .OK, let url = panel.url {
            sessionsPath = url.path
        }
    }
}
