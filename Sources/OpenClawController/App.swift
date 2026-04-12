import SwiftUI
import AppKit

@main
struct OpenClawControllerApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var controller: GatewayController

    @Environment(\.openWindow) private var openWindow
    @State private var showSetupWizard: Bool = false
    @State private var showSettings: Bool = false

    init() {
        let s = AppSettings.shared
        _settings = StateObject(wrappedValue: s)
        _controller = StateObject(wrappedValue: GatewayController(settings: s))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                controller: controller,
                settings: settings,
                openWindow: openWindow,
                showSettings: $showSettings,
                showSetupWizard: $showSetupWizard
            )
        } label: {
            Image(systemName: controller.isBusy ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle")
        }
        .menuBarExtraStyle(.window)

        Window("OpenClaw Controller", id: "main") {
            MainWindowView(showSettings: $showSettings)
                .environmentObject(controller)
                .environmentObject(settings)
                .frame(minWidth: 720, minHeight: 520)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .sheet(isPresented: $showSetupWizard) {
                    SetupWizardView(
                        settings: settings,
                        controller: controller,
                        isPresented: $showSetupWizard
                    )
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView(settings: settings)
                }
                .task {
                    if !settings.hasCompletedSetup {
                        showSetupWizard = true
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 820, height: 620)
    }
}
