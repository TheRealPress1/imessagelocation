import AppKit

/// Owns the floating search panel and the capture→paste hand-off.
@MainActor
final class PanelController {
    private var panel: SpotlightPanel?
    /// The app that was frontmost when the panel was summoned — the paste target.
    private var target: NSRunningApplication?

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    private func show() {
        // Capture the paste target BEFORE the panel appears. Because the panel is a
        // non-activating panel and we never call NSApp.activate(), this app stays a
        // background agent and `target` remains the frontmost (Messages/Slack/…).
        target = NSWorkspace.shared.frontmostApplication

        let fresh = makePanel()   // fresh each summon → clean state, current bias
        panel?.hide()
        panel = fresh
        fresh.present()
    }

    func hide() {
        panel?.hide()
    }

    private func makePanel() -> SpotlightPanel {
        let root = SpotlightView(
            initialBias: LinkBuilder.parseBias(SettingsStore.current.searchNear),
            onCommit: { [weak self] place in self?.commit(place) },
            onCancel: { [weak self] in self?.hide() }
        )
        return SpotlightPanel(rootView: root)
    }

    private func commit(_ place: Place) {
        let text = LinkBuilder.payload(place, SettingsStore.current)
        hide()                                   // order the panel out first
        AutoPaste.paste(text, into: target)      // reactivate target + synthesize ⌘V
    }
}
