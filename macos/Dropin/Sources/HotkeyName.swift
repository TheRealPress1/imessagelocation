import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The global summon shortcut. Default ⌘⇧Space — includes ⌘, satisfying the
    /// macOS 15+ rule that a global hotkey must carry a modifier other than ⌥/⇧.
    static let togglePanel = Self("togglePanel", initial: .init(.space, modifiers: [.command, .shift]))
}
