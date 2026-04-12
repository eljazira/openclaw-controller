import SwiftUI

struct SetupWizardView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var controller: GatewayController
    @Binding var isPresented: Bool

    @State private var step: Step = .welcome
    @State private var detectedPath: String = ""
    @State private var detectedSessionsPath: String = ""
    @State private var customPath: String = ""
    @State private var customSessionsPath: String = ""
    @State private var selectedAgent: String = "main"
    @State private var agents: [String] = ["main"]
    @State private var version: String = ""
    @State private var testPassed: Bool? = nil
    @State private var testRunning: Bool = false

    enum Step: Int, CaseIterable {
        case welcome, detectCLI, configureSessions, test, done
    }

    var body: some View {
        VStack(spacing: 0) {
            progressBar
            Divider()

            Group {
                switch step {
                case .welcome: welcomeStep
                case .detectCLI: detectStep
                case .configureSessions: sessionsStep
                case .test: testStep
                case .done: doneStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)

            Divider()
            navigationBar
        }
        .frame(width: 560, height: 480)
        .onAppear { runAutoDetect() }
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 0) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Rectangle()
                    .fill(s.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Welcome to OpenClaw Controller")
                .font(.system(size: 24, weight: .bold))

            Text("A menu bar app that gives you one-click buttons for common OpenClaw gateway operations — no terminal required.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "stop.circle.fill", color: .orange, text: "Stop, start, and restart the gateway")
                featureRow(icon: "trash.circle.fill", color: .red, text: "Clear session files with one click")
                featureRow(icon: "bolt.circle.fill", color: .purple, text: "Full reset: stop → clear → restart")
                featureRow(icon: "waveform.path.ecg", color: .blue, text: "Check gateway status instantly")
            }
            .padding(.top, 8)
        }
    }

    private var detectStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Locate OpenClaw")
                .font(.system(size: 20, weight: .semibold))

            if !detectedPath.isEmpty {
                VStack(spacing: 8) {
                    Label("Found OpenClaw", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 15, weight: .medium))

                    Text(detectedPath)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                        .textSelection(.enabled)

                    if !version.isEmpty {
                        Text(version)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Label("OpenClaw not found", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 15, weight: .medium))

                    Text("Make sure OpenClaw is installed. You can enter the path manually below.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Custom path (leave empty to use auto-detected):")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("/path/to/openclaw", text: $customPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                    Button("Browse…") { browseForFile() }
                        .controlSize(.small)
                }
            }
        }
    }

    private var sessionsStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Sessions Directory")
                .font(.system(size: 20, weight: .semibold))

            Text("Choose which agent's sessions to manage. The session files are cleared when you click \"Clear Sessions\" or \"Full Reset\".")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Agent:")
                        .font(.system(size: 13))
                    Picker("", selection: $selectedAgent) {
                        ForEach(agents, id: \.self) { agent in
                            Text(agent).tag(agent)
                        }
                    }
                    .frame(width: 160)
                    .onChange(of: selectedAgent) { _, newVal in
                        if let path = AppSettings.detectSessionsPath(agent: newVal) {
                            detectedSessionsPath = path
                        } else {
                            let home = NSHomeDirectory()
                            detectedSessionsPath = "\(home)/.openclaw/agents/\(newVal)/sessions"
                        }
                    }
                }

                if !detectedSessionsPath.isEmpty {
                    HStack(spacing: 6) {
                        let exists = FileManager.default.fileExists(atPath: detectedSessionsPath)
                        Image(systemName: exists ? "checkmark.circle.fill" : "questionmark.circle.fill")
                            .foregroundStyle(exists ? .green : .orange)
                        Text(detectedSessionsPath)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom path (leave empty to use default):")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("~/.openclaw/agents/main/sessions", text: $customSessionsPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                        Button("Browse…") { browseForFolder() }
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private var testStep: some View {
        VStack(spacing: 20) {
            if testRunning {
                ProgressView()
                    .controlSize(.large)
                    .padding(.bottom, 4)
                Text("Testing connection…")
                    .font(.system(size: 20, weight: .semibold))
            } else if testPassed == true {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Connection Successful")
                    .font(.system(size: 20, weight: .semibold))
                Text("OpenClaw gateway responded. Everything is working.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else if testPassed == false {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text("Gateway Not Responding")
                    .font(.system(size: 20, weight: .semibold))
                Text("The gateway may not be running yet — that's fine.\nYou can start it later using the app.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "network")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("Test Connectivity")
                    .font(.system(size: 20, weight: .semibold))
                Text("Run a quick status check to make sure everything is wired up correctly.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(testPassed != nil ? "Test Again" : "Run Test") {
                Task { await runTest() }
            }
            .controlSize(.large)
            .disabled(testRunning)

            if testPassed == false {
                Text("You can skip this and continue — the app will still work once the gateway is started.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)

            Text("You're All Set!")
                .font(.system(size: 24, weight: .bold))

            Text("OpenClaw Controller will live in your menu bar.\nLook for the ⚡ bolt icon in the top-right of your screen.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 8) {
                configRow(label: "OpenClaw", value: settings.resolvedOpenclawPath)
                configRow(label: "Agent", value: settings.agentName)
                configRow(label: "Sessions", value: settings.resolvedSessionsPath)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))

            Text("You can change these anytime from Settings (in the menu bar popover).")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack {
            if step != .welcome {
                Button("Back") {
                    withAnimation { step = Step(rawValue: step.rawValue - 1)! }
                }
            }
            Spacer()
            if step == .done {
                Button("Get Started") {
                    applySettings()
                    settings.hasCompletedSetup = true
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            } else {
                let label = step == .test && testPassed == false ? "Skip & Continue" : "Continue"
                Button(label) {
                    if step == .detectCLI { applyDetection() }
                    if step == .configureSessions { applySessions() }
                    withAnimation { step = Step(rawValue: step.rawValue + 1)! }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(step == .detectCLI && detectedPath.isEmpty && customPath.isEmpty)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 13))
        }
    }

    private func configRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private func runAutoDetect() {
        if let path = AppSettings.detectOpenclawPath() {
            detectedPath = path
            version = AppSettings.openclawVersion(at: path) ?? ""
        }
        agents = AppSettings.listAgents()
        selectedAgent = agents.first ?? "main"
        if let sessPath = AppSettings.detectSessionsPath(agent: selectedAgent) {
            detectedSessionsPath = sessPath
        } else {
            detectedSessionsPath = "\(NSHomeDirectory())/.openclaw/agents/\(selectedAgent)/sessions"
        }
    }

    private func applyDetection() {
        if !customPath.isEmpty {
            settings.openclawPath = customPath
        } else if !detectedPath.isEmpty {
            settings.openclawPath = detectedPath
        }
    }

    private func applySessions() {
        settings.agentName = selectedAgent
        if !customSessionsPath.isEmpty {
            settings.sessionsPath = customSessionsPath
        } else {
            settings.sessionsPath = ""
        }
    }

    private func applySettings() {
        applyDetection()
        applySessions()
    }

    private func runTest() async {
        testRunning = true
        testPassed = nil
        applySettings()
        testPassed = await controller.testConnectivity()
        testRunning = false
    }

    private func browseForFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the openclaw binary"
        if panel.runModal() == .OK, let url = panel.url {
            customPath = url.path
        }
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the sessions directory"
        if panel.runModal() == .OK, let url = panel.url {
            customSessionsPath = url.path
        }
    }
}
