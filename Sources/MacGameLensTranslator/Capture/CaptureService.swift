import CoreGraphics

protocol CaptureService {
    func captureMainDisplay() async throws -> ScreenshotResult
}
