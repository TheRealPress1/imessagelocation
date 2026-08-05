import SwiftUI

@main
struct DropinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No visible scene. The menu-bar status item, the floating search panel,
        // and the preferences window are all managed imperatively by AppDelegate
        // (an NSStatusItem, so a single left-click opens the panel directly).
        // `Settings { EmptyView() }` just satisfies App's "some Scene" requirement;
        // for an .accessory/LSUIElement agent it never auto-opens anything.
        Settings {
            EmptyView()
        }
    }
}
