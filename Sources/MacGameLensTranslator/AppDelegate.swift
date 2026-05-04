import AppKit
import os
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    let logger = Logger(subsystem: "com.macgamelens.translator", category: "app")
    let menuBarController = MenuBarController()
    let hotkeyManager = HotkeyManager()
    let coordinator: LensTranslationCoordinator

    override init() {
        // Redirect stdout and stderr to a log file for debugging
        let logPath = "/tmp/mglt_debug.log"
        if let logFile = fopen(logPath, "a") {
            dup2(fileno(logFile), STDOUT_FILENO)
            dup2(fileno(logFile), STDERR_FILENO)
            fclose(logFile)
        }
        // Also flush after every print
        setbuf(stdout, nil)

        let settingsStore = SettingsStore()
        let captureService = ScreenCaptureKitCaptureService()
        let ocrService = VisionOCRService()
        let filter = TextBlockFilter()
        let merger = TextBlockMerger()
        let batcher = TranslationBatcher(maxBlocks: settingsStore.settings.maxTextBlocks, maxCharacters: settingsStore.settings.maxTotalCharacters)
        let cache = TranslationCache()
        let promptBuilder = TranslationPromptBuilder()
        let parser = TranslationResultParser()
        let deepSeekTranslationService = DeepSeekTranslationService(
            promptBuilder: promptBuilder,
            resultParser: parser,
            batcher: batcher,
            cache: cache,
            settingsStore: settingsStore
        )
        let qwenMTTranslationService = QwenMTTranslationService(
            batcher: batcher,
            cache: cache,
            settingsStore: settingsStore
        )
        let translationService = ProviderTranslationService(
            settingsStore: settingsStore,
            deepSeekService: deepSeekTranslationService,
            qwenMTService: qwenMTTranslationService
        )
        let layoutEngine = OverlayLayoutEngine()
        let overlayController = OverlayWindowController()
        let performanceMetrics = PerformanceMetrics()
        let debugModeStore = DebugModeStore()

        coordinator = LensTranslationCoordinator(
            settingsStore: settingsStore,
            captureService: captureService,
            ocrService: ocrService,
            filter: filter,
            merger: merger,
            translationService: translationService,
            layoutEngine: layoutEngine,
            overlayController: overlayController,
            performanceMetrics: performanceMetrics,
            debugModeStore: debugModeStore,
            logger: Logger(subsystem: "com.macgamelens.translator", category: "coordinator")
        )

        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[MGLT] === Mac Game Lens Translator v0.1 started ===")
        print("[MGLT] Log file: /tmp/mglt_debug.log")
        logger.info("Mac Game Lens Translator launching")
        menuBarController.configure(coordinator: coordinator)
        hotkeyManager.configure(coordinator: coordinator)
        menuBarController.checkPermissionsOnLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Mac Game Lens Translator terminating")
    }
}
