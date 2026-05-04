import AppKit
import CoreGraphics
import os

final class LensTranslationCoordinator {
    struct StatusSnapshot {
        let title: String
        let detail: String
        let isWorking: Bool
        let isOverlayShowing: Bool
        let lastUpdated: Date
    }

    private let settingsStore: SettingsStore
    private let captureService: CaptureService
    private let ocrService: OCRService
    private let filter: TextBlockFilter
    private let merger: TextBlockMerger
    private let translationService: TranslationService
    private let layoutEngine: OverlayLayoutEngine
    private let overlayController: OverlayWindowController
    private let performanceMetrics: PerformanceMetrics
    private let debugModeStore: DebugModeStore
    private let logger: Logger

    private var currentTask: Task<Void, Never>?
    private var coordinatorState: CoordinatorState = .idle
    private var lastOverlaySnapshot: OverlaySnapshot?
    private var lastStatus = StatusSnapshot(
        title: "Idle",
        detail: "Ready",
        isWorking: false,
        isOverlayShowing: false,
        lastUpdated: Date()
    )

    var onStatusChanged: ((StatusSnapshot) -> Void)?

    var statusSnapshot: StatusSnapshot { lastStatus }

    var isIdle: Bool {
        if case .idle = coordinatorState { return true }
        return false
    }

    enum CoordinatorState {
        case idle
        case translating
        case showingOverlay
        case failed(Error)
    }

    private struct OverlaySnapshot {
        let blocks: [OverlayTextBlock]
        let displayFrame: CGRect
        let debugMode: Bool
        let opacity: Double
        let fontSizeScale: Double
        let levelMode: OverlayLevelMode
    }

    init(
        settingsStore: SettingsStore,
        captureService: CaptureService,
        ocrService: OCRService,
        filter: TextBlockFilter,
        merger: TextBlockMerger,
        translationService: TranslationService,
        layoutEngine: OverlayLayoutEngine,
        overlayController: OverlayWindowController,
        performanceMetrics: PerformanceMetrics,
        debugModeStore: DebugModeStore,
        logger: Logger
    ) {
        self.settingsStore = settingsStore
        self.captureService = captureService
        self.ocrService = ocrService
        self.filter = filter
        self.merger = merger
        self.translationService = translationService
        self.layoutEngine = layoutEngine
        self.overlayController = overlayController
        self.performanceMetrics = performanceMetrics
        self.debugModeStore = debugModeStore
        self.logger = logger
    }

    func toggleTranslation() async {
        print("[MGLT] toggleTranslation called, state=\(coordinatorState)")
        switch coordinatorState {
        case .idle:
            await startRegionTranslation()
        case .translating:
            cancelCurrentTask()
        case .showingOverlay:
            await clearOverlay()
        case .failed:
            clearError()
        }
    }

    func translateFullScreen() async {
        print("[MGLT] translateFullScreen called, state=\(coordinatorState)")
        switch coordinatorState {
        case .idle:
            await startSnapshotTranslation(selectedRegion: nil)
        case .translating:
            cancelCurrentTask()
        case .showingOverlay:
            await clearOverlay()
        case .failed:
            clearError()
        }
    }

    func showLastOverlay() async {
        guard let snapshot = lastOverlaySnapshot else {
            publishStatus(title: "No saved overlay", detail: "There is no previous overlay to show", isWorking: false, isOverlayShowing: false)
            return
        }

        let didShow = await MainActor.run {
            overlayController.show(
                blocks: snapshot.blocks,
                displayFrame: snapshot.displayFrame,
                debugMode: snapshot.debugMode,
                opacity: snapshot.opacity,
                fontSizeScale: snapshot.fontSizeScale,
                levelMode: snapshot.levelMode
            )
        }

        if didShow {
            coordinatorState = .showingOverlay
            publishStatus(title: "Overlay showing", detail: "Redisplayed \(snapshot.blocks.count) saved text blocks", isWorking: false, isOverlayShowing: true)
        } else {
            publishStatus(title: "Overlay failed", detail: "Saved overlay could not be shown", isWorking: false, isOverlayShowing: false)
        }
    }

    func clearOverlay() async {
        await MainActor.run { overlayController.hide() }
        coordinatorState = .idle
        publishStatus(title: "Idle", detail: "Overlay cleared", isWorking: false, isOverlayShowing: false)
        print("[MGLT] Overlay cleared")
    }

    private func startRegionTranslation() async {
        coordinatorState = .translating
        publishStatus(title: "Selecting region", detail: "Drag to choose the screen area to translate, or press Esc to cancel", isWorking: true, isOverlayShowing: false)

        guard let selectedRegion = await AreaSelectionWindowController.shared.selectRegion() else {
            coordinatorState = .idle
            publishStatus(title: "Idle", detail: "Region selection cancelled", isWorking: false, isOverlayShowing: false)
            return
        }

        await startSnapshotTranslation(selectedRegion: selectedRegion)
    }

    private func startSnapshotTranslation(selectedRegion: SelectedScreenRegion?) async {
        print("[MGLT] Starting snapshot translation...")
        let startTime = Date()
        var metrics = PerformanceMetrics.SnapshotMetrics()

        coordinatorState = .translating
        publishStatus(title: "Starting", detail: "Preparing translation pipeline", isWorking: true, isOverlayShowing: false)

        let task = Task {
            do {
                // Check API key
                publishStatus(title: "Checking API key", detail: "Loading DeepSeek API key from settings", isWorking: true, isOverlayShowing: false)
                let apiKey = settingsStore.settings.deepSeekAPIKey
                guard !apiKey.isEmpty else {
                    print("[MGLT] ERROR: No API key found")
                    await showError(CoordinatorError.noAPIKey)
                    return
                }
                print("[MGLT] API key loaded: \(apiKey.prefix(4))...")

                // Without full Screen Recording permission, macOS can return a
                // wallpaper-only capture that hides app windows. Treat preflight
                // failure as not usable for OCR.
                guard PermissionController.checkScreenRecordingPermission() else {
                    print("[MGLT] ERROR: Screen Recording preflight failed; capture would hide app windows")
                    await showError(CoordinatorError.noScreenRecordingPermission)
                    return
                }
                print("[MGLT] Screen Recording permission granted")

                let settings = settingsStore.settings
                print("[MGLT] Settings: targetLang=\(settings.targetLanguage), debug=\(settings.debugModeEnabled)")

                // Capture
                print("[MGLT] Capturing screen...")
                let captureDetail = selectedRegion == nil ? "Taking a screenshot of the target display" : "Taking a screenshot after region selection"
                publishStatus(title: "Capturing screen", detail: captureDetail, isWorking: true, isOverlayShowing: false)
                let captureStart = Date()
                let screenshot = try await captureService.captureMainDisplay()
                metrics.captureDuration = Date().timeIntervalSince(captureStart)
                print("[MGLT] Capture done: \(String(format: "%.0f", metrics.captureDuration * 1000))ms, size=\(Int(screenshot.pixelSize.width))x\(Int(screenshot.pixelSize.height))")

                // OCR
                print("[MGLT] Running OCR...")
                publishStatus(title: "Running OCR", detail: "Looking for text in the screenshot", isWorking: true, isOverlayShowing: false)
                let ocrStart = Date()
                let rawObservations = try await ocrService.recognizeText(in: screenshot.image)
                metrics.ocrDuration = Date().timeIntervalSince(ocrStart)
                metrics.rawOCRObservationCount = rawObservations.count
                print("[MGLT] OCR done: \(rawObservations.count) observations in \(String(format: "%.0f", metrics.ocrDuration * 1000))ms")

                guard !rawObservations.isEmpty else {
                    print("[MGLT] No text detected on screen")
                    publishStatus(title: "No text detected", detail: "Screenshot succeeded, but OCR found no text. Last screenshot: /tmp/mglt_last_capture.png", isWorking: false, isOverlayShowing: false)
                    await showAlert(title: "No text detected", message: "OCR did not find any text in the captured screen.\n\nLast screenshot: /tmp/mglt_last_capture.png\n\nMove the mouse over the game screen and trigger translation with the hotkey so the app captures that display.")
                    coordinatorState = .idle
                    return
                }

                // Filter
                publishStatus(title: "Filtering OCR", detail: "Cleaning up \(rawObservations.count) OCR observations", isWorking: true, isOverlayShowing: false)
                let filteredObservations = filter.filter(rawObservations)
                metrics.filteredBlockCount = filteredObservations.count
                print("[MGLT] Filtered: \(filteredObservations.count) blocks")

                // Merge
                publishStatus(title: "Merging text", detail: "Combining nearby text into translation blocks", isWorking: true, isOverlayShowing: false)
                var mergedBlocks = merger.merge(filteredObservations, pixelSize: screenshot.pixelSize, scaleFactor: screenshot.scaleFactor)
                if let selectedRegion {
                    mergedBlocks = filterBlocks(mergedBlocks, inside: selectedRegion, screenshot: screenshot)
                    print("[MGLT] Region filter: \(mergedBlocks.count) blocks inside selected region \(selectedRegion.localRect)")
                }
                metrics.mergedBlockCount = mergedBlocks.count
                print("[MGLT] Merged: \(mergedBlocks.count) blocks")

                guard !mergedBlocks.isEmpty else {
                    let detail = selectedRegion == nil ? "OCR found text, but no blocks survived filtering" : "No OCR text blocks were inside the selected region"
                    publishStatus(title: "No selected text", detail: detail, isWorking: false, isOverlayShowing: false)
                    await showAlert(title: "No selected text", message: "\(detail).\n\nLast screenshot: /tmp/mglt_last_capture.png")
                    coordinatorState = .idle
                    return
                }

                try Task.checkCancellation()

                // Translate
                print("[MGLT] Translating \(mergedBlocks.count) blocks via DeepSeek...")
                publishStatus(title: "Calling DeepSeek", detail: "Sending \(mergedBlocks.count) text blocks for translation", isWorking: true, isOverlayShowing: false)
                let translationStart = Date()
                let targetLanguage = settings.targetLanguage
                let translatedBlocks = try await translationService.translate(mergedBlocks, targetLanguage: targetLanguage)
                metrics.translationDuration = Date().timeIntervalSince(translationStart)
                let translatedCount = translatedBlocks.filter { $0.translatedText != nil }.count
                print("[MGLT] Translation done: \(translatedCount)/\(translatedBlocks.count) translated in \(String(format: "%.0f", metrics.translationDuration * 1000))ms")

                try Task.checkCancellation()

                // Layout
                publishStatus(title: "Laying out overlay", detail: "Preparing translated text positions", isWorking: true, isOverlayShowing: false)
                let layoutStart = Date()
                let overlayBlocks = layoutEngine.layout(translatedBlocks, displayFrame: screenshot.displayFrame)
                metrics.overlayLayoutDuration = Date().timeIntervalSince(layoutStart)
                print("[MGLT] Layout: \(overlayBlocks.count) overlay blocks")

                guard !overlayBlocks.isEmpty else {
                    let untranslatedCount = translatedBlocks.filter { ($0.translatedText ?? "").isEmpty }.count
                    publishStatus(title: "No overlay text", detail: "Translation returned no displayable text for \(untranslatedCount) blocks", isWorking: false, isOverlayShowing: false)
                    await showAlert(title: "No overlay text", message: "Translation finished, but no translated text was available to display. Check /tmp/mglt_debug.log for API parsing details.")
                    coordinatorState = .idle
                    return
                }

                // Show overlay
                let didShowOverlay = await MainActor.run {
                    print("[MGLT] Showing overlay at frame=\(screenshot.displayFrame)")
                    let didShow = overlayController.show(
                        blocks: overlayBlocks,
                        displayFrame: screenshot.displayFrame,
                        debugMode: settings.debugModeEnabled,
                        opacity: settings.overlayOpacity,
                        fontSizeScale: settings.fontSizeScale,
                        levelMode: settings.overlayLevelMode
                    )
                    print("[MGLT] Overlay shown! isShowing=\(overlayController.isShowing)")
                    return didShow
                }

                guard didShowOverlay else {
                    publishStatus(title: "Overlay failed", detail: "Overlay received no blocks or could not open its window", isWorking: false, isOverlayShowing: false)
                    await showAlert(title: "Overlay Failed", message: "Translation completed, but the overlay window did not open.")
                    coordinatorState = .idle
                    return
                }

                lastOverlaySnapshot = OverlaySnapshot(
                    blocks: overlayBlocks,
                    displayFrame: screenshot.displayFrame,
                    debugMode: settings.debugModeEnabled,
                    opacity: settings.overlayOpacity,
                    fontSizeScale: settings.fontSizeScale,
                    levelMode: settings.overlayLevelMode
                )
                coordinatorState = .showingOverlay
                publishStatus(title: "Overlay showing", detail: "Displayed \(overlayBlocks.count) translated text blocks", isWorking: false, isOverlayShowing: true)
                metrics.timestamp = Date()
                metrics.totalDuration = Date().timeIntervalSince(startTime)
                performanceMetrics.record(metrics)
                print("[MGLT] Total time: \(String(format: "%.0f", metrics.totalDuration * 1000))ms")

            } catch is CancellationError {
                print("[MGLT] Cancelled")
                coordinatorState = .idle
                publishStatus(title: "Cancelled", detail: "Translation was cancelled", isWorking: false, isOverlayShowing: false)
            } catch {
                print("[MGLT] ERROR: \(error.localizedDescription)")
                await showError(error)
                metrics.timestamp = Date()
                metrics.totalDuration = Date().timeIntervalSince(startTime)
                performanceMetrics.record(metrics)
            }
        }

        currentTask = task
    }

    private func filterBlocks(_ blocks: [TextBlock], inside selectedRegion: SelectedScreenRegion, screenshot: ScreenshotResult) -> [TextBlock] {
        guard screenshot.displayFrame.equalTo(selectedRegion.displayFrame) else {
            print("[MGLT] WARNING: Selected screen frame \(selectedRegion.displayFrame) differs from captured frame \(screenshot.displayFrame); applying local region anyway")
            return blocks.filter { $0.boundingBox.intersects(selectedRegion.localRect) }
        }

        return blocks.filter { block in
            block.boundingBox.intersects(selectedRegion.localRect)
        }
    }

    private func cancelCurrentTask() {
        Task { @MainActor in
            AreaSelectionWindowController.shared.cancelSelection()
        }
        currentTask?.cancel()
        currentTask = nil
        coordinatorState = .idle
        publishStatus(title: "Cancelled", detail: "Translation was cancelled by the user", isWorking: false, isOverlayShowing: false)
        print("[MGLT] Cancelled by user")
    }

    private func clearError() {
        coordinatorState = .idle
        publishStatus(title: "Idle", detail: "Previous error cleared", isWorking: false, isOverlayShowing: false)
        print("[MGLT] Error cleared")
    }

    private func showAlert(title: String, message: String) async {
        print("[MGLT] ALERT: \(title) - \(message)")
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func showError(_ error: Error) async {
        let message = error.localizedDescription
        print("[MGLT] ERROR: \(message)")
        coordinatorState = .failed(error)
        publishStatus(title: "Failed", detail: message, isWorking: false, isOverlayShowing: false)
        await showAlert(title: "Translation Failed", message: message)
    }

    private func publishStatus(title: String, detail: String, isWorking: Bool, isOverlayShowing: Bool) {
        let snapshot = StatusSnapshot(
            title: title,
            detail: detail,
            isWorking: isWorking,
            isOverlayShowing: isOverlayShowing,
            lastUpdated: Date()
        )
        lastStatus = snapshot
        print("[MGLT] STATUS: \(title) - \(detail)")
        DispatchQueue.main.async { [weak self] in
            self?.onStatusChanged?(snapshot)
        }
    }
}

enum CoordinatorError: LocalizedError {
    case noAPIKey
    case noScreenRecordingPermission

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key configured. Open Settings to add your DeepSeek API key."
        case .noScreenRecordingPermission:
            return "Screen Recording permission is required for the currently running app. If macOS only captures the wallpaper and hides windows, remove MacGameLensTranslator from System Settings > Privacy & Security > Screen & System Audio Recording, add /Users/usr/Documents/play/MacGameLensTranslator.app again, turn it on, then quit and reopen the app."
        }
    }
}
