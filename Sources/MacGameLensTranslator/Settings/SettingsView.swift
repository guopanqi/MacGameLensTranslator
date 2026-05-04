import SwiftUI

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
        }
        .frame(width: 480, height: 360)
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
    }

    func save() {
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
        settingsStore.settings = s
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
