import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @ObservedObject var controller: GatewayController
    @ObservedObject var settings: AppSettings
    let openWindow: OpenWindowAction
    @Binding var showSettings: Bool
    @Binding var showSetupWizard: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .foregroundStyle(.tint)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("OpenClaw Gateway")
                        .font(.system(size: 13, weight: .semibold))
                    Text(controller.lastAction)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if controller.isBusy {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 4)

            Divider()

            VStack(spacing: 2) {
                menuButton(
                    title: "Stop Gateway",
                    icon: "stop.circle.fill",
                    tint: .orange
                ) {
                    Task { await controller.stopGateway() }
                }

                menuButton(
                    title: "Clear Sessions (\(controller.sessionCount))",
                    icon: "trash.circle.fill",
                    tint: .red
                ) {
                    Task { await controller.clearSessions() }
                }

                menuButton(
                    title: "Restart Gateway",
                    icon: "arrow.clockwise.circle.fill",
                    tint: .green
                ) {
                    Task { await controller.restartGateway() }
                }

                Divider().padding(.vertical, 4)

                menuButton(
                    title: "Full Reset (stop \u{2192} clear \u{2192} restart)",
                    icon: "bolt.circle.fill",
                    tint: .purple,
                    bold: true
                ) {
                    Task { await controller.fullReset() }
                }
            }
            .padding(.horizontal, 6)
            .disabled(controller.isBusy)

            Divider().padding(.top, 4)

            VStack(spacing: 2) {
                menuButton(
                    title: "Check Status",
                    icon: "waveform.path.ecg",
                    tint: .blue
                ) {
                    Task { await controller.statusGateway() }
                }

                menuButton(
                    title: "Open Window",
                    icon: "macwindow",
                    tint: .secondary
                ) {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }

                menuButton(
                    title: "Settings…",
                    icon: "gearshape",
                    tint: .secondary
                ) {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showSettings = true
                    }
                }
            }
            .padding(.horizontal, 6)

            Divider().padding(.top, 4)

            HStack(spacing: 2) {
                menuButton(
                    title: "Quit",
                    icon: "power",
                    tint: .secondary
                ) {
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .frame(width: 260)
    }

    @ViewBuilder
    private func menuButton(
        title: String,
        icon: String,
        tint: Color,
        bold: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: bold ? .semibold : .regular))
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(MenuRowButtonStyle())
    }
}

private struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.25) : Color.clear)
            )
    }
}
