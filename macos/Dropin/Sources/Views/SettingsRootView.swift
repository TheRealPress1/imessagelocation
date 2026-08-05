import SwiftUI
import KeyboardShortcuts

struct SettingsRootView: View {
    var body: some View {
        TabView {
            MapsSettings().tabItem { Label("Maps", systemImage: "map") }
            SearchSettings().tabItem { Label("Search", systemImage: "location.magnifyingglass") }
            HotkeySettings().tabItem { Label("Hotkey", systemImage: "command") }
        }
        .frame(width: 480, height: 300)
    }
}

private struct MapsSettings: View {
    @AppStorage(SettingsStore.Key.provider) private var provider: MapProvider = .apple
    @AppStorage(SettingsStore.Key.format) private var format: OutputFormat = .link

    private let sample = Place(id: "s", name: "Switchyards",
                               address: "151 Ted Turner Dr NW, Atlanta",
                               lat: 33.7489954, lon: -84.3879824)

    var body: some View {
        Form {
            Picker("Map links", selection: $provider) {
                ForEach(MapProvider.allCases) { Text($0.label).tag($0) }
            }
            Picker("What to send", selection: $format) {
                ForEach(OutputFormat.allCases) { Text($0.title).tag($0) }
            }
            LabeledContent("Preview") {
                Text(LinkBuilder.payload(sample, PlaceSettings(provider: provider, outputFormat: format)))
                    .font(.callout)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
    }
}

private struct SearchSettings: View {
    @AppStorage(SettingsStore.Key.near) private var near: String = ""
    @AppStorage(SettingsStore.Key.unit) private var unit: DistanceUnit = .km

    private var valid: Bool { near.isEmpty || LinkBuilder.parseBias(near) != nil }

    var body: some View {
        Form {
            TextField("Search near (lat,lon)", text: $near, prompt: Text("33.749,-84.388"))
            if !valid {
                Text("Enter coordinates as lat,lon").font(.caption).foregroundStyle(.red)
            }
            Picker("Distance units", selection: $unit) {
                ForEach(DistanceUnit.allCases) { Text($0.label).tag($0) }
            }
        }
        .formStyle(.grouped)
    }
}

private struct HotkeySettings: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Summon Dropin:", name: .togglePanel)
            Text("Include ⌘ or ⌃ — ⌥/⇧-only combos are blocked by macOS.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Reset to default") { KeyboardShortcuts.reset(.togglePanel) }
        }
        .formStyle(.grouped)
    }
}
