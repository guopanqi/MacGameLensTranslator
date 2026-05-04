import Foundation
import os

enum OverlayLevelMode: String, Codable, CaseIterable {
    case normal
    case strong
    case emergency

    var displayName: String {
        switch self {
        case .normal: return "Normal (Floating)"
        case .strong: return "Strong (Status Bar)"
        case .emergency: return "Emergency (ScreenSaver)"
        }
    }

    var description: String {
        switch self {
        case .normal: return "Default. Works for most windowed games."
        case .strong: return "Higher level. Try if normal doesn't cover the game."
        case .emergency: return "Highest level. May cover system UI like Dock."
        }
    }
}

struct AppSettings: Codable {
    var deepSeekAPIKey: String
    var targetLanguage: String
    var sourceLanguage: String
    var hotkey: String
    var fontSizeScale: Double
    var overlayOpacity: Double
    var overlayLevelMode: OverlayLevelMode
    var autoClearSeconds: Double?
    var maxTextBlocks: Int
    var maxTotalCharacters: Int
    var debugModeEnabled: Bool

    static let `default` = AppSettings(
        deepSeekAPIKey: "",
        targetLanguage: "Simplified Chinese",
        sourceLanguage: "Auto",
        hotkey: "Command + Shift + T",
        fontSizeScale: 1.0,
        overlayOpacity: 0.75,
        overlayLevelMode: .normal,
        autoClearSeconds: nil,
        maxTextBlocks: 50,
        maxTotalCharacters: 10000,
        debugModeEnabled: false
    )
}

final class SettingsStore {
    private let logger = Logger(subsystem: "com.macgamelens.translator", category: "settings")

    var settings: AppSettings {
        get {
            guard let data = UserDefaults.standard.data(forKey: "appSettings") else {
                return .default
            }
            do {
                return try JSONDecoder().decode(AppSettings.self, from: data)
            } catch {
                logger.error("Failed to decode settings: \(error.localizedDescription)")
                return .default
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: "appSettings")
            } catch {
                logger.error("Failed to encode settings: \(error.localizedDescription)")
            }
        }
    }
}
