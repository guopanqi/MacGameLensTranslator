import AppKit

enum PermissionController {
    struct ScreenRecordingStatus {
        let preflightGranted: Bool
        let testCaptureSucceeded: Bool

        var canCaptureScreen: Bool {
            preflightGranted
        }

        var summary: String {
            if preflightGranted {
                return "Screen Recording granted"
            }
            if testCaptureSucceeded {
                return "Not granted; macOS may return a wallpaper-only capture"
            }
            return "Screen Recording not granted"
        }
    }

    static func checkScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func screenRecordingStatus() -> ScreenRecordingStatus {
        let preflightGranted = CGPreflightScreenCaptureAccess()
        let testCaptureSucceeded = testMainDisplayCapture()
        print("[MGLT] Permission status: preflight=\(preflightGranted), testCapture=\(testCaptureSucceeded)")
        return ScreenRecordingStatus(
            preflightGranted: preflightGranted,
            testCaptureSucceeded: testCaptureSucceeded
        )
    }

    static func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }

    static func showPermissionAlert() {
        let status = screenRecordingStatus()
        let appPath = currentAppPath()

        if status.canCaptureScreen {
            let alert = NSAlert()
            alert.messageText = "Screen Capture OK"
            alert.informativeText = "The currently running app has Screen Recording permission.\n\nPreflight check: \(status.preflightGranted ? "Granted" : "False")\nCapture API returned image: \(status.testCaptureSucceeded ? "Yes" : "No")\n\nRunning app:\n\(appPath)"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Mac Game Lens Translator needs Screen Recording permission to capture game screens for OCR translation.\n\nRight now macOS is not granting full screen recording to this app. It may still return a wallpaper-only image, but app windows will be hidden.\n\nEnable this exact app in System Settings > Privacy & Security > Screen & System Audio Recording:\n\(appPath)\n\nIf it is already listed, remove it with the minus button, add this app again, turn it on, then quit and reopen Mac Game Lens Translator."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Ask macOS Again")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        } else if response == .alertSecondButtonReturn {
            requestScreenRecordingPermission()
        }
    }

    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    static func currentAppPath() -> String {
        Bundle.main.bundleURL.path
    }

    private static func testMainDisplayCapture() -> Bool {
        guard let mainScreen = NSScreen.main else {
            return false
        }

        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let displayID = mainScreen.deviceDescription[key] as? CGDirectDisplayID else {
            return false
        }

        guard let image = CGDisplayCreateImage(displayID) else {
            return false
        }

        return image.width > 1 && image.height > 1
    }
}
