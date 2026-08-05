import AppKit
import SwiftUI
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?

    private let panelController = PanelController()
    private var prefsWindow: NSWindow?
    private var statusItem: NSStatusItem?   // retained for the app's lifetime, or the icon vanishes

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A freshly-launched build wins: terminate any older Dropin instance still running
        // in the menu bar, so a stale build can't shadow a new run during development.
        if let bundleID = Bundle.main.bundleIdentifier {
            let me = NSRunningApplication.current
            for other in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            where other.processIdentifier != me.processIdentifier {
                other.terminate()
            }
        }

        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)   // no Dock icon (also LSUIElement in Info.plist)

        // Global hotkey → summon/dismiss the panel. Registered once, for the app's lifetime.
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
            self?.panelController.toggle()
        }

        setUpStatusItem()
    }

    func togglePanel() { panelController.toggle() }

    // MARK: - Menu-bar status item (single left-click opens the panel)

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "mappin.and.ellipse", accessibilityDescription: "Dropin")
            image?.isTemplate = true   // adapt to light/dark menu bar
            button.image = image
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            // Receive both mouse buttons so we can branch left- vs right-click ourselves.
            // (No persistent statusItem.menu — that would open a menu on every click.)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isSecondaryClick = event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false)
        if isSecondaryClick {
            showStatusMenu()
        } else {
            togglePanel()   // one click → straight to the search panel
        }
    }

    private func showStatusMenu() {
        guard let statusItem else { return }

        let menu = NSMenu()
        menu.addItem(withTitle: "Preferences…", action: #selector(preferencesMenuItemSelected), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Dropin", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Attach the menu transiently, pop it, then detach so left-click stays an action.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func preferencesMenuItemSelected() { openPreferences() }

    /// macOS 26: SwiftUI's openSettings/SettingsLink are unreliable from a menu-bar
    /// app, so we own the preferences window in AppKit. Flip to .regular so it can
    /// take focus and show in the switcher; revert to .accessory when it closes.
    func openPreferences() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        if prefsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
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
