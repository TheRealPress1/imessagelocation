import AppKit
import SwiftUI
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?

    private let panelController = PanelController()
    private var prefsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)   // no Dock icon (also LSUIElement in Info.plist)

        // Global hotkey → summon/dismiss the panel. Registered once, for the app's lifetime.
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
            self?.panelController.toggle()
        }
    }

    func togglePanel() { panelController.toggle() }

    /// macOS 26: SwiftUI's openSettings/SettingsLink are unreliable from a menu-bar
    /// app, so we own the preferences window in AppKit. Flip to .regular so it can
    /// take focus and show in the switcher; revert to .accessory when it closes.
    func openPreferences() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        if prefsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Dropin Preferences"
            window.contentViewController = NSHostingController(rootView: SettingsRootView())
            window.isReleasedWhenClosed = false
            window.center()
            window.delegate = self
            prefsWindow = window
        }
        prefsWindow?.makeKeyAndOrderFront(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Back to a background agent once Preferences is dismissed.
        NSApp.setActivationPolicy(.accessory)
    }
}
