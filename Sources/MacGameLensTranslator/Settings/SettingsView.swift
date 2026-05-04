import SwiftUI
import Foundation

extension Notification.Name {
    static let shortcutsDidChange = Notification.Name("MGLTShortcutsDidChange")
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            APISettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("API Key", systemImage: "key")
                }

            GeneralSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            TranslationSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Translation", systemImage: "globe")
                }

            OverlaySettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Overlay", systemImage: "rectangle.on.rectangle")
                }

            ShortcutsTab(viewModel: viewModel)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    let settingsStore = SettingsStore()

    @Published var deepSeekAPIKey: String
    @Published var qwenAPIKey: String
    @Published var selectedTranslationProvider: TranslationProvider
    @Published var deepSeekModelName: String
    @Published var qwenModelName: String
    @Published var targetLanguage: String
    @Published var sourceLanguage: String
    @Published var fontSizeScale: Double
    @Published var overlayOpacity: Double
    @Published var overlayLevelMode: OverlayLevelMode
    @Published var maxTextBlocks: Int
    @Published var maxTotalCharacters: Int
    @Published var debugModeEnabled: Bool
    @Published var regionHotkey: String
    @Published var windowHotkey: String
    @Published var fullScreenHotkey: String
    @Published var clearOverlayHotkey: String
    @Published var showLastOverlayHotkey: String

    private var previousShortcuts: [String] = []

    init() {
        let s = SettingsStore().settings
        deepSeekAPIKey = s.deepSeekAPIKey
        qwenAPIKey = s.qwenAPIKey
        selectedTranslationProvider = s.selectedTranslationProvider
        deepSeekModelName = s.deepSeekModelName
        qwenModelName = s.qwenModelName
        targetLanguage = s.targetLanguage
        sourceLanguage = s.sourceLanguage
        fontSizeScale = s.fontSizeScale
        overlayOpacity = s.overlayOpacity
        overlayLevelMode = s.overlayLevelMode
        maxTextBlocks = s.maxTextBlocks
        maxTotalCharacters = s.maxTotalCharacters
        debugModeEnabled = s.debugModeEnabled
        regionHotkey = s.regionHotkey
        windowHotkey = s.windowHotkey
        fullScreenHotkey = s.fullScreenHotkey
        clearOverlayHotkey = s.clearOverlayHotkey
        showLastOverlayHotkey = s.showLastOverlayHotkey
        previousShortcuts = [regionHotkey, windowHotkey, fullScreenHotkey, clearOverlayHotkey, showLastOverlayHotkey]
    }

    func save() {
        let currentShortcuts = [regionHotkey, windowHotkey, fullScreenHotkey, clearOverlayHotkey, showLastOverlayHotkey]
        let shortcutsChanged = currentShortcuts != previousShortcuts

        var s = settingsStore.settings
        s.deepSeekAPIKey = deepSeekAPIKey
        s.qwenAPIKey = qwenAPIKey
        s.selectedTranslationProvider = selectedTranslationProvider
        s.deepSeekModelName = deepSeekModelName
        s.qwenModelName = qwenModelName
        s.targetLanguage = targetLanguage
        s.sourceLanguage = sourceLanguage
        s.fontSizeScale = fontSizeScale
        s.overlayOpacity = overlayOpacity
        s.overlayLevelMode = overlayLevelMode
        s.maxTextBlocks = maxTextBlocks
        s.maxTotalCharacters = maxTotalCharacters
        s.debugModeEnabled = debugModeEnabled
        s.regionHotkey = regionHotkey
        s.windowHotkey = windowHotkey
        s.fullScreenHotkey = fullScreenHotkey
        s.clearOverlayHotkey = clearOverlayHotkey
        s.showLastOverlayHotkey = showLastOverlayHotkey
        settingsStore.settings = s
        if shortcutsChanged {
            previousShortcuts = currentShortcuts
            NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
        }
    }
}

struct GeneralSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Picker("Source Language", selection: $viewModel.sourceLanguage) {
                Text("Auto").tag("Auto")
                Text("English").tag("en")
                Text("Japanese").tag("ja")
                Text("Korean").tag("ko")
                Text("French").tag("fr")
                Text("German").tag("de")
            }
            .onChange(of: viewModel.sourceLanguage) { _ in viewModel.save() }

            Picker("Target Language", selection: $viewModel.targetLanguage) {
                Text("Simplified Chinese").tag("Simplified Chinese")
                Text("Traditional Chinese").tag("Traditional Chinese")
                Text("English").tag("English")
                Text("Japanese").tag("Japanese")
                Text("Korean").tag("Korean")
            }
            .onChange(of: viewModel.targetLanguage) { _ in viewModel.save() }
        }
    }
}

struct TranslationSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Stepper("Max Text Blocks: \(viewModel.maxTextBlocks)", value: $viewModel.maxTextBlocks, in: 10...100, step: 5)
                .onChange(of: viewModel.maxTextBlocks) { _ in viewModel.save() }

            Stepper("Max Characters: \(viewModel.maxTotalCharacters)", value: $viewModel.maxTotalCharacters, in: 1000...20000, step: 1000)
                .onChange(of: viewModel.maxTotalCharacters) { _ in viewModel.save() }
        }
    }
}

struct OverlaySettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Slider(value: $viewModel.fontSizeScale, in: 0.5...2.0, step: 0.1) {
                Text("Font Size Scale: \(viewModel.fontSizeScale, specifier: "%.1f")")
            }
            .onChange(of: viewModel.fontSizeScale) { _ in viewModel.save() }

            Slider(value: $viewModel.overlayOpacity, in: 0.25...1.0, step: 0.05) {
                Text("Overlay Opacity: \(viewModel.overlayOpacity, specifier: "%.2f")")
            }
            .onChange(of: viewModel.overlayOpacity) { _ in viewModel.save() }

            Picker("Overlay Level", selection: $viewModel.overlayLevelMode) {
                ForEach(OverlayLevelMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .onChange(of: viewModel.overlayLevelMode) { _ in viewModel.save() }

            if let desc = viewModel.overlayLevelMode.description as String? {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Toggle("Debug Mode", isOn: $viewModel.debugModeEnabled)
                .onChange(of: viewModel.debugModeEnabled) { _ in viewModel.save() }
                .help("Shows OCR bounding boxes, confidence scores, and timing info")
        }
    }
}

struct ShortcutsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            ShortcutRecorder(title: "Translate Region", shortcut: $viewModel.regionHotkey, onChange: viewModel.save)
            ShortcutRecorder(title: "Translate Window", shortcut: $viewModel.windowHotkey, onChange: viewModel.save)
            ShortcutRecorder(title: "Translate Full Screen", shortcut: $viewModel.fullScreenHotkey, onChange: viewModel.save)
            ShortcutRecorder(title: "Clear Overlay", shortcut: $viewModel.clearOverlayHotkey, onChange: viewModel.save)
            ShortcutRecorder(title: "Show Last Overlay", shortcut: $viewModel.showLastOverlayHotkey, onChange: viewModel.save)
        }
        .padding(.top, 8)
    }
}

struct ShortcutRecorder: View {
    let title: String
    @Binding var shortcut: String
    var onChange: () -> Void

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 160, alignment: .trailing)

            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isRecording ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: 180, height: 26)

                if isRecording {
                    Text("Type shortcut...")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else if shortcut.isEmpty {
                    Text("None")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    Text(shortcutDisplayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .onTapGesture {
                isRecording = true
            }

            if isRecording {
                Button("Cancel") { stopRecording() }
            } else if !shortcut.isEmpty {
                Button("Clear") { shortcut = ""; onChange() }
            }
        }
        .onChange(of: isRecording) { recording in
            if recording { startRecording() } else { stopRecording() }
        }
    }

    private func startRecording() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers != [] else { return event }

            let keyCode = event.keyCode
            guard let char = ShortcutRecorder.keyCodeToChar[keyCode] else {
                return event
            }

            var parts: [String] = []
            if modifiers.contains(.command) { parts.append("Command") }
            if modifiers.contains(.shift) { parts.append("Shift") }
            if modifiers.contains(.option) { parts.append("Option") }
            if modifiers.contains(.control) { parts.append("Control") }
            parts.append(char)

            shortcut = parts.joined(separator: " + ")
            isRecording = false
            onChange()
            return nil
        }
    }

    static let keyCodeToChar: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G",
        6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        49: "Space",
    ]

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
    }

    private var shortcutDisplayName: String {
        let parts = shortcut.components(separatedBy: " + ").map { $0.trimmingCharacters(in: .whitespaces) }
        var result = ""
        for part in parts.dropLast() {
            switch part.lowercased() {
            case "command": result += "⌘"
            case "shift": result += "⇧"
            case "option", "alt": result += "⌥"
            case "control", "ctrl": result += "⌃"
            default: result += part
            }
        }
        if let key = parts.last {
            result += key.uppercased()
        }
        return result
    }
}

struct APISettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section(header: Text("Translation Provider")) {
                Picker("Provider", selection: $viewModel.selectedTranslationProvider) {
                    ForEach(TranslationProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: viewModel.selectedTranslationProvider) { _ in viewModel.save() }
            }

            Section(header: Text("DeepSeek")) {
                TextField("Model", text: $viewModel.deepSeekModelName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.deepSeekModelName) { _ in viewModel.save() }

                TextField("Enter API Key", text: $viewModel.deepSeekAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.deepSeekAPIKey) { _ in viewModel.save() }

                if !viewModel.deepSeekAPIKey.isEmpty {
                    Text("API Key saved (\(viewModel.deepSeekAPIKey.count) chars)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No API Key configured")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section(header: Text("Qwen MT Lite (Bailian)")) {
                TextField("Model", text: $viewModel.qwenModelName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.qwenModelName) { _ in viewModel.save() }

                TextField("Enter API Key", text: $viewModel.qwenAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.qwenAPIKey) { _ in viewModel.save() }

                if !viewModel.qwenAPIKey.isEmpty {
                    Text("API Key saved (\(viewModel.qwenAPIKey.count) chars)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No API Key configured")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section(header: Text("Get API Key")) {
                Link("DeepSeek Platform", destination: URL(string: "https://platform.deepseek.com/api_keys")!)
                    .font(.caption)
                Link("Qwen MT Lite (Bailian)", destination: URL(string: "https://bailian.console.aliyun.com/cn-beijing?tab=model#/model-market/detail/qwen-mt-lite?serviceSite=asia-pacific-china")!)
                    .font(.caption)
            }
        }
    }
}
