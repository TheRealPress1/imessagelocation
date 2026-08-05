import SwiftUI

@main
struct DropinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Status-bar item + pull-down menu. The floating search panel and the
        // preferences window are managed imperatively by the AppDelegate.
        MenuBarExtra("Dropin", systemImage: "mappin.and.ellipse") {
            Button("Open Dropin") { AppDelegate.shared?.togglePanel() }
            Divider()
            Button("Preferences…") { AppDelegate.shared?.openPreferences() }
                .keyboardShortcut(",", modifiers: .command)
            Button("Quit Dropin") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
    }
}
