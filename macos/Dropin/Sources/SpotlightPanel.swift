import AppKit
import SwiftUI

/// Spotlight-style floating panel: becomes key (so the search field types and the
/// map is clickable) WITHOUT activating the app, so the frontmost app stays the
/// paste target. The two overrides below are what make that work.
final class SpotlightPanel: NSPanel {
    private var keyMonitor: Any?

    init<Content: View>(rootView: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false            // accessory apps deactivate constantly; we dismiss ourselves
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        for button: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }

        let hosting = NSHostingView(rootView: rootView)
        hosting.safeAreaRegions = []         // macOS 13.3+: kill the titled-panel top inset
        contentView = hosting
    }

    // The two lines that make typing work while the app stays .accessory.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func present() {
        positionInTopThird()
        makeKeyAndOrderFront(nil)            // NOTE: no NSApp.activate() — do not steal focus
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        orderOut(nil)
    }

    // Clicked away / another window became key → dismiss (no paste).
    override func resignKey() {
        super.resignKey()
        hide()
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {         // Esc
                self?.hide()
                return nil                   // consume so it doesn't beep
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func positionInTopThird() {
        guard let screen = NSScreen.main else { center(); return }
        let visible = screen.visibleFrame
        let size = frame.size
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - visible.height * 0.18   // Spotlight-style top third
        setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }
}
