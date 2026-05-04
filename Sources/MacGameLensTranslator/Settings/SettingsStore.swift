import Foundation
import os

enum TranslationProvider: String, Codable, CaseIterable {
    case deepSeek
    case qwenMtLite

    var displayName: String {
        switch self {
        case .deepSeek: return "DeepSeek"
        case .qwenMtLite: return "Qwen MT Lite"
        }
    }
}

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
    var qwenAPIKey: String
    var selectedTranslationProvider: TranslationProvider
    var deepSeekModelName: String
    var qwenModelName: String
    var targetLanguage: String
    var sourceLanguage: String
    var fontSizeScale: Double
    var overlayOpacity: Double
    var overlayLevelMode: OverlayLevelMode
    var autoClearSeconds: Double?
    var maxTextBlocks: Int
    var maxTotalCharacters: Int
    var debugModeEnabled: Bool
    var regionHotkey: String
    var windowHotkey: String
    var fullScreenHotkey: String
    var clearOverlayHotkey: String
    var showLastOverlayHotkey: String

    private enum CodingKeys: String, CodingKey {
        case deepSeekAPIKey
        case qwenAPIKey
        case selectedTranslationProvider
        case deepSeekModelName
        case qwenModelName
        case targetLanguage
        case sourceLanguage
        case fontSizeScale
        case overlayOpacity
        case overlayLevelMode
        case autoClearSeconds
        case maxTextBlocks
        case maxTotalCharacters
        case debugModeEnabled
        case regionHotkey
        case windowHotkey
        case fullScreenHotkey
        case clearOverlayHotkey
        case showLastOverlayHotkey
    }

    static let `default` = AppSettings(
        deepSeekAPIKey: "",
        qwenAPIKey: "",
        selectedTranslationProvider: .deepSeek,
        deepSeekModelName: "deepseek-v4-flash",
        qwenModelName: "qwen-mt-lite",
        targetLanguage: "Simplified Chinese",
        sourceLanguage: "Auto",
        fontSizeScale: 1.0,
        overlayOpacity: 0.75,
        overlayLevelMode: .normal,
        autoClearSeconds: nil,
        maxTextBlocks: 50,
        maxTotalCharacters: 10000,
        debugModeEnabled: false,
        regionHotkey: "Command + Shift + T",
        windowHotkey: "Command + Shift + W",
        fullScreenHotkey: "",
        clearOverlayHotkey: "Command + Shift + C",
        showLastOverlayHotkey: ""
    )

    init(
        deepSeekAPIKey: String,
        qwenAPIKey: String,
        selectedTranslationProvider: TranslationProvider,
        deepSeekModelName: String,
        qwenModelName: String,
        targetLanguage: String,
        sourceLanguage: String,
        fontSizeScale: Double,
        overlayOpacity: Double,
        overlayLevelMode: OverlayLevelMode,
        autoClearSeconds: Double?,
        maxTextBlocks: Int,
        maxTotalCharacters: Int,
        debugModeEnabled: Bool,
        regionHotkey: String,
        windowHotkey: String,
        fullScreenHotkey: String,
        clearOverlayHotkey: String,
        showLastOverlayHotkey: String
    ) {
        self.deepSeekAPIKey = deepSeekAPIKey
        self.qwenAPIKey = qwenAPIKey
        self.selectedTranslationProvider = selectedTranslationProvider
        self.deepSeekModelName = deepSeekModelName
        self.qwenModelName = qwenModelName
        self.targetLanguage = targetLanguage
        self.sourceLanguage = sourceLanguage
        self.fontSizeScale = fontSizeScale
        self.overlayOpacity = overlayOpacity
        self.overlayLevelMode = overlayLevelMode
        self.autoClearSeconds = autoClearSeconds
        self.maxTextBlocks = maxTextBlocks
        self.maxTotalCharacters = maxTotalCharacters
        self.debugModeEnabled = debugModeEnabled
        self.regionHotkey = regionHotkey
        self.windowHotkey = windowHotkey
        self.fullScreenHotkey = fullScreenHotkey
        self.clearOverlayHotkey = clearOverlayHotkey
        self.showLastOverlayHotkey = showLastOverlayHotkey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default

        deepSeekAPIKey = try container.decodeIfPresent(String.self, forKey: .deepSeekAPIKey) ?? d.deepSeekAPIKey
        qwenAPIKey = try container.decodeIfPresent(String.self, forKey: .qwenAPIKey) ?? d.qwenAPIKey
        selectedTranslationProvider = try container.decodeIfPresent(TranslationProvider.self, forKey: .selectedTranslationProvider) ?? d.selectedTranslationProvider
        deepSeekModelName = try container.decodeIfPresent(String.self, forKey: .deepSeekModelName) ?? d.deepSeekModelName
        qwenModelName = try container.decodeIfPresent(String.self, forKey: .qwenModelName) ?? d.qwenModelName
        targetLanguage = try container.decodeIfPresent(String.self, forKey: .targetLanguage) ?? d.targetLanguage
        sourceLanguage = try container.decodeIfPresent(String.self, forKey: .sourceLanguage) ?? d.sourceLanguage
        fontSizeScale = try container.decodeIfPresent(Double.self, forKey: .fontSizeScale) ?? d.fontSizeScale
        overlayOpacity = try container.decodeIfPresent(Double.self, forKey: .overlayOpacity) ?? d.overlayOpacity
        overlayLevelMode = try container.decodeIfPresent(OverlayLevelMode.self, forKey: .overlayLevelMode) ?? d.overlayLevelMode
        autoClearSeconds = try container.decodeIfPresent(Double.self, forKey: .autoClearSeconds)
        maxTextBlocks = try container.decodeIfPresent(Int.self, forKey: .maxTextBlocks) ?? d.maxTextBlocks
        maxTotalCharacters = try container.decodeIfPresent(Int.self, forKey: .maxTotalCharacters) ?? d.maxTotalCharacters
        debugModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .debugModeEnabled) ?? d.debugModeEnabled
        regionHotkey = try container.decodeIfPresent(String.self, forKey: .regionHotkey) ?? d.regionHotkey
        windowHotkey = try container.decodeIfPresent(String.self, forKey: .windowHotkey) ?? d.windowHotkey
        fullScreenHotkey = try container.decodeIfPresent(String.self, forKey: .fullScreenHotkey) ?? d.fullScreenHotkey
        clearOverlayHotkey = try container.decodeIfPresent(String.self, forKey: .clearOverlayHotkey) ?? d.clearOverlayHotkey
        showLastOverlayHotkey = try container.decodeIfPresent(String.self, forKey: .showLastOverlayHotkey) ?? d.showLastOverlayHotkey
    }
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
