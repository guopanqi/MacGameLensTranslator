import CoreGraphics
import AppKit
import ImageIO
import os
import UniformTypeIdentifiers

final class ScreenCaptureKitCaptureService: CaptureService {
    private let logger = Logger(subsystem: "com.macgamelens.translator", category: "capture")

    func captureMainDisplay() async throws -> ScreenshotResult {
        print("[MGLT] Capturing main display...")

        guard let screen = targetScreen() else {
            print("[MGLT] ERROR: No main screen found")
            throw CaptureError.noDisplayFound
        }

        let displayID = screen.displayID
        let scaleFactor = screen.backingScaleFactor
        let displayFrame = screen.frame

        print("[MGLT] Display: \(Int(displayFrame.width))x\(Int(displayFrame.height)), scale=\(scaleFactor), id=\(displayID)")

        guard let cgImage = CGDisplayCreateImage(displayID) else {
            print("[MGLT] ERROR: CGDisplayCreateImage returned nil - likely no screen recording permission")
            throw CaptureError.noImageData
        }

        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        saveDebugCapture(cgImage)

        logger.debug("Capture complete: pixelSize=\(Int(pixelSize.width))x\(Int(pixelSize.height))")

        return ScreenshotResult(
            image: cgImage,
            displayFrame: displayFrame,
            scaleFactor: scaleFactor,
            pixelSize: pixelSize,
            capturedAt: Date()
        )
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let screenUnderMouse = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            print("[MGLT] Target screen selected from mouse location: \(mouseLocation)")
            return screenUnderMouse
        }

        print("[MGLT] Target screen fallback: main")
        return NSScreen.main
    }

    private func saveDebugCapture(_ image: CGImage) {
        let url = URL(fileURLWithPath: "/tmp/mglt_last_capture.png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            print("[MGLT] WARNING: Could not create debug screenshot destination")
            return
        }

        CGImageDestinationAddImage(destination, image, nil)
        if CGImageDestinationFinalize(destination) {
            print("[MGLT] Debug screenshot saved: \(url.path)")
        } else {
            print("[MGLT] WARNING: Could not save debug screenshot")
        }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}

enum CaptureError: LocalizedError {
    case noDisplayFound
    case noImageData

    var errorDescription: String? {
        switch self {
        case .noDisplayFound: return "No display found to capture"
        case .noImageData:
            return "Screenshot returned no image data. Screen Recording permission may be missing for the exact app currently running: \(PermissionController.currentAppPath())"
        }
    }
}
