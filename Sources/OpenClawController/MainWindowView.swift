import SwiftUI
import AppKit

struct MainWindowView: View {
    @EnvironmentObject var controller: GatewayController
    @EnvironmentObject var settings: AppSettings
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            buttonGrid
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            Divider()
            logView
            Divider()
            statusBar
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenClaw Gateway Controller")
                    .font(.system(size: 17, weight: .semibold))
                Text(settings.resolvedSessionsPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(controller.isBusy ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(controller.isBusy ? "Working" : "Ready")
                        .font(.system(size: 12, weight: .medium))
                }
                Text("\(controller.sessionCount) session file\(controller.sessionCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Button {
                    controller.refreshSessionCount()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh session file count")
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var buttonGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ActionCard(
                    title: "Stop Gateway",
                    subtitle: "openclaw gateway stop",
                    icon: "stop.circle.fill",
                    tint: .orange
                ) {
                    Task { await controller.stopGateway() }
                }

                ActionCard(
                    title: "Clear Sessions",
                    subtitle: "Delete session files",
                    icon: "trash.circle.fill",
                    tint: .red,
                    badge: controller.sessionCount > 0 ? "\(controller.sessionCount)" : nil
                ) {
                    Task { await controller.clearSessions() }
                }

                ActionCard(
                    title: "Restart Gateway",
                    subtitle: "openclaw gateway restart",
                    icon: "arrow.clockwise.circle.fill",
                    tint: .green
                ) {
                    Task { await controller.restartGateway() }
                }
            }

            HStack(spacing: 12) {
                ActionCard(
                    title: "Full Reset",
                    subtitle: "stop \u{2192} clear \u{2192} restart",
                    icon: "bolt.circle.fill",
                    tint: .purple,
                    emphasized: true
                ) {
                    Task { await controller.fullReset() }
                }

                ActionCard(
                    title: "Start Gateway",
                    subtitle: "openclaw gateway start",
                    icon: "play.circle.fill",
                    tint: .mint
                ) {
                    Task { await controller.startGateway() }
                }

                ActionCard(
                    title: "Check Status",
                    subtitle: "openclaw gateway status",
                    icon: "waveform.path.ecg.rectangle.fill",
                    tint: .blue
                ) {
                    Task { await controller.statusGateway() }
                }
            }
        }
        .disabled(controller.isBusy)
        .opacity(controller.isBusy ? 0.55 : 1.0)
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    if controller.logLines.isEmpty {
                        Text("No output yet. Click a button above.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(controller.logLines) { line in
                            LogLineView(line: line)
                                .id(line.id)
                        }
                    }
                }
                .padding(12)
            }
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            .onChange(of: controller.logLines.count) { _, _ in
                if let last = controller.logLines.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if controller.isBusy {
                ProgressView().controlSize(.small)
                Text(controller.lastAction)
                    .font(.system(size: 11))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 11))
                Text("Ready")
                    .font(.system(size: 11))
            }
            Spacer()
            Text("Agent: \(settings.agentName)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear Log") {
                controller.clearLog()
            }
            .controlSize(.small)
            .disabled(controller.logLines.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    var badge: String? = nil
    var emphasized: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(tint)
                        .frame(height: 40)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 14, y: -4)
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: emphasized ? .semibold : .medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        emphasized
                            ? tint.opacity(hovering ? 0.22 : 0.15)
                            : tint.opacity(hovering ? 0.15 : 0.09)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        tint.opacity(emphasized ? 0.55 : 0.25),
                        lineWidth: emphasized ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct LogLineView: View {
    let line: GatewayController.LogLine

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var color: Color {
        switch line.level {
        case .info: return .primary
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .command: return .blue
        }
    }

    private var prefix: String {
        switch line.level {
        case .info: return " "
        case .success: return "\u{2713}"
        case .error: return "\u{2717}"
        case .warning: return "!"
        case .command: return "\u{203A}"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(Self.timeFormatter.string(from: line.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(prefix)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 10)
            Text(line.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(color)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
