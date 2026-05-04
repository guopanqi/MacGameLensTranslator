import CoreGraphics

protocol CaptureService {
    func captureMainDisplay() async throws -> ScreenshotResult
    func captureFocusedWindow() async throws -> ScreenshotResult
}
