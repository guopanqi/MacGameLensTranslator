import Foundation

final class DebugModeStore {
    static let shared = DebugModeStore()

    var isDebugMode: Bool {
        get { SettingsStore().settings.debugModeEnabled }
        set {
            var settings = SettingsStore().settings
            settings.debugModeEnabled = newValue
            SettingsStore().settings = settings
        }
    }
}
