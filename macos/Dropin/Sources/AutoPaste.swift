import AppKit
import CoreGraphics
import Carbon.HIToolbox   // kVK_ANSI_V (== 9), IsSecureEventInputEnabled

/// Writes the payload to the pasteboard, hands focus back to the target app, and
/// synthesizes ⌘V. The privilege that governs CGEvent.post is the "PostEvent" TCC
/// grant (surfaced under Privacy & Security > Accessibility), checked with
/// CGPreflightPostEventAccess — the accurate gate, distinct from AXIsProcessTrusted.
@MainActor
enum AutoPaste {
    enum Result { case pasted, needsPermission, secureInput }

    @discardableResult
    static func paste(_ text: String, into target: NSRunningApplication?) -> Result {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()               // MUST precede setString or the write is dropped
        pasteboard.setString(text, forType: .string)

        guard CGPreflightPostEventAccess() else {
            _ = CGRequestPostEventAccess()       // async system prompt; registers app in the list
            openAccessibilitySettings()
            return .needsPermission
        }

        // Secure input (password fields / Terminal secure entry) swallows posted events.
        if IsSecureEventInputEnabled() {
            return .secureInput                  // link is on the clipboard; user pastes manually
        }

        if let target {
            NSApp.yieldActivation(to: target)    // macOS 14+ cooperative activation
            target.activate()
        }

        // Activation + first-responder restore is async; post ⌘V after a short delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            postCommandV()
        }
        return .pasted
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        keyDown?.flags = .maskCommand            // Command on BOTH events (more reliable than a separate ⌘ press)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
