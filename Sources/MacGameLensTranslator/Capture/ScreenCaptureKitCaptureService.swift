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

    func captureFocusedWindow() async throws -> ScreenshotResult {
        print("[MGLT] Capturing focused window...")

        guard let candidate = focusedWindowCandidate() else {
            print("[MGLT] ERROR: No focused window candidate found")
            throw CaptureError.noFocusedWindowFound
        }

        print("[MGLT] Focused window candidate: id=\(candidate.windowID), owner=\(candidate.ownerName), bounds=\(candidate.cgBounds)")

        let imageOptions: CGWindowImageOption = [.boundsIgnoreFraming, .bestResolution]
        guard let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, candidate.windowID, imageOptions) else {
            print("[MGLT] ERROR: CGWindowListCreateImage returned nil")
            throw CaptureError.noImageData
        }

        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scaleFactor = scaleFactor(forWindowBounds: candidate.cgBounds, pixelSize: pixelSize)
        let displayFrame = appKitFrame(fromCGWindowBounds: candidate.cgBounds)
        saveDebugCapture(cgImage)

        print("[MGLT] Focused window capture done: points=\(displayFrame), pixels=\(Int(pixelSize.width))x\(Int(pixelSize.height)), scale=\(scaleFactor)")

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

    private struct WindowCandidate {
        let windowID: CGWindowID
        let ownerPID: pid_t
        let ownerName: String
        let cgBounds: CGRect
        let area: CGFloat
    }

    private func focusedWindowCandidate() -> WindowCandidate? {
        guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let candidates = windows.compactMap(windowCandidate(from:))

        if let frontPID, frontPID != currentPID,
           let frontWindow = candidates.first(where: { $0.ownerPID == frontPID }) {
            return frontWindow
        }

        return candidates.first { $0.ownerPID != currentPID }
    }

    private func windowCandidate(from info: [String: Any]) -> WindowCandidate? {
        guard let windowIDNumber = info[kCGWindowNumber as String] as? NSNumber,
              let ownerPIDNumber = info[kCGWindowOwnerPID as String] as? NSNumber,
              let layerNumber = info[kCGWindowLayer as String] as? NSNumber,
              let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
            return nil
        }

        guard layerNumber.intValue == 0 else { return nil }
        guard bounds.width >= 80, bounds.height >= 80 else { return nil }

        if let alpha = info[kCGWindowAlpha as String] as? NSNumber, alpha.doubleValue <= 0 {
            return nil
        }

        let ownerName = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
        let excludedOwners: Set<String> = ["Dock", "Window Server", "SystemUIServer", "Control Center"]
        guard !excludedOwners.contains(ownerName) else { return nil }

        return WindowCandidate(
            windowID: CGWindowID(windowIDNumber.uint32Value),
            ownerPID: pid_t(ownerPIDNumber.intValue),
            ownerName: ownerName,
            cgBounds: bounds,
            area: bounds.width * bounds.height
        )
    }

    private func scaleFactor(forWindowBounds bounds: CGRect, pixelSize: CGSize) -> CGFloat {
        guard bounds.width > 0, bounds.height > 0 else { return NSScreen.main?.backingScaleFactor ?? 1.0 }
        let widthScale = pixelSize.width / bounds.width
        let heightScale = pixelSize.height / bounds.height
        let scale = (widthScale + heightScale) / 2
        if scale.isFinite, scale > 0 {
            return scale
        }
        return NSScreen.main?.backingScaleFactor ?? 1.0
    }

    private func appKitFrame(fromCGWindowBounds bounds: CGRect) -> CGRect {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let screen = NSScreen.screens.first { screen in
            let cgFrame = cgFrame(for: screen)
            return cgFrame.contains(center)
        } ?? NSScreen.main

        guard let screen else {
            return bounds
        }

        let cgScreenFrame = cgFrame(for: screen)
        let appKitY = screen.frame.minY + (cgScreenFrame.maxY - bounds.maxY)
        return CGRect(x: bounds.minX, y: appKitY, width: bounds.width, height: bounds.height)
    }

    private func cgFrame(for screen: NSScreen) -> CGRect {
        let appFrame = screen.frame
        let mainMaxY = NSScreen.screens.map { $0.frame.maxY }.max() ?? appFrame.maxY
        let y = mainMaxY - appFrame.maxY
        return CGRect(x: appFrame.minX, y: y, width: appFrame.width, height: appFrame.height)
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
    case noFocusedWindowFound
    case noImageData

    var errorDescription: String? {
        switch self {
        case .noDisplayFound: return "No display found to capture"
        case .noFocusedWindowFound:
            return "No focused window found to capture. Bring the target game or app window to the front and try again."
        case .noImageData:
            return "Screenshot returned no image data. Screen Recording permission may be missing for the exact app currently running: \(PermissionController.currentAppPath())"
        }
    }
}
