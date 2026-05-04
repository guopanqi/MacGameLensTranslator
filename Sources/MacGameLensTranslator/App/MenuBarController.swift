import AppKit
import os

final class MenuBarController {
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var detailMenuItem: NSMenuItem?
    private var permissionMenuItem: NSMenuItem?
    private weak var coordinator: LensTranslationCoordinator?
    private var latestStatus: LensTranslationCoordinator.StatusSnapshot?

    func configure(coordinator: LensTranslationCoordinator) {
        self.coordinator = coordinator
        setupStatusItem()
        coordinator.onStatusChanged = { [weak self] snapshot in
            self?.updateStatus(snapshot)
        }
        updateStatus(coordinator.statusSnapshot)
        print("[MacGameLens] Menu bar configured")
    }

    func reloadShortcuts(from settings: AppSettings) {
        applyShortcut(settings.regionHotkey, to: translateRegionItem)
        applyShortcut(settings.fullScreenHotkey, to: translateFullScreenItem)
        applyShortcut(settings.windowHotkey, to: translateWindowItem)
        applyShortcut(settings.clearOverlayHotkey, to: clearOverlayItem)
        applyShortcut(settings.showLastOverlayHotkey, to: showLastOverlayItem)
    }

    private func applyShortcut(_ shortcut: String, to item: NSMenuItem?) {
        guard let item = item else { return }
        if shortcut.isEmpty {
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
        } else {
            let parts = shortcut.components(separatedBy: " + ").map { $0.trimmingCharacters(in: .whitespaces) }
            item.keyEquivalent = parts.last?.lowercased() ?? ""
            var mask: NSEvent.ModifierFlags = []
            for part in parts.dropLast() {
                switch part.lowercased() {
                case "command": mask.insert(.command)
                case "shift": mask.insert(.shift)
                case "option", "alt": mask.insert(.option)
                case "control", "ctrl": mask.insert(.control)
                default: break
                }
            }
            item.keyEquivalentModifierMask = mask
        }
    }

    func checkPermissionsOnLaunch() {
        let preflightGranted = PermissionController.checkScreenRecordingPermission()
        print("[MacGameLens] Screen recording preflight: \(preflightGranted)")
        updatePermissionStatus(useCaptureTest: false)
    }

    private var translateRegionItem: NSMenuItem?
    private var translateFullScreenItem: NSMenuItem?
    private var translateWindowItem: NSMenuItem?
    private var clearOverlayItem: NSMenuItem?
    private var showLastOverlayItem: NSMenuItem?

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "译"
            button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            button.toolTip = "Mac Game Lens Translator"
        }

        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "Status: Starting", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        self.statusMenuItem = statusMenuItem
        menu.addItem(statusMenuItem)

        let detailMenuItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        detailMenuItem.isEnabled = false
        self.detailMenuItem = detailMenuItem
        menu.addItem(detailMenuItem)

        menu.addItem(NSMenuItem.separator())

        let translateItem = NSMenuItem(title: "Translate Region", action: #selector(triggerTranslate), keyEquivalent: "t")
        translateItem.keyEquivalentModifierMask = [.command, .shift]
        translateItem.target = self
        self.translateRegionItem = translateItem
        menu.addItem(translateItem)

        let fullScreenItem = NSMenuItem(title: "Translate Full Screen", action: #selector(triggerFullScreenTranslate), keyEquivalent: "f")
        fullScreenItem.keyEquivalentModifierMask = [.command, .shift]
        fullScreenItem.target = self
        self.translateFullScreenItem = fullScreenItem
        menu.addItem(fullScreenItem)

        let focusedWindowItem = NSMenuItem(title: "Translate Focused Window", action: #selector(triggerFocusedWindowTranslate), keyEquivalent: "w")
        focusedWindowItem.keyEquivalentModifierMask = [.command, .shift]
        focusedWindowItem.target = self
        self.translateWindowItem = focusedWindowItem
        menu.addItem(focusedWindowItem)

        let regionControlItem = NSMenuItem(title: "Region Control Mode", action: #selector(triggerRegionControlMode), keyEquivalent: "r")
        regionControlItem.keyEquivalentModifierMask = [.command, .shift]
        regionControlItem.target = self
        menu.addItem(regionControlItem)

        let clearItem = NSMenuItem(title: "Clear Overlay", action: #selector(triggerClear), keyEquivalent: "c")
        clearItem.keyEquivalentModifierMask = [.command, .shift]
        clearItem.target = self
        self.clearOverlayItem = clearItem
        menu.addItem(clearItem)

        let showLastItem = NSMenuItem(title: "Show Last Overlay", action: #selector(triggerShowLastOverlay), keyEquivalent: "")
        showLastItem.target = self
        self.showLastOverlayItem = showLastItem
        menu.addItem(showLastItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let permissionItem = NSMenuItem(title: "Screen Capture: Checking", action: #selector(checkPermissions), keyEquivalent: "")
        permissionItem.target = self
        self.permissionMenuItem = permissionItem
        menu.addItem(permissionItem)

        let diagnosticsItem = NSMenuItem(title: "Show Diagnostics", action: #selector(showDiagnostics), keyEquivalent: "")
        diagnosticsItem.target = self
        menu.addItem(diagnosticsItem)

        let logItem = NSMenuItem(title: "Open Debug Log", action: #selector(openDebugLog), keyEquivalent: "")
        logItem.target = self
        menu.addItem(logItem)

        let debugItem = NSMenuItem(title: "Debug Mode", action: #selector(toggleDebugMode), keyEquivalent: "")
        debugItem.target = self
        menu.addItem(debugItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        print("[MacGameLens] Status bar item created")
    }

    @objc private func triggerTranslate() {
        print("[MacGameLens] Region translate triggered from menu")
        statusItem?.button?.title = "⟳"
        Task { 
            await coordinator?.toggleTranslation()
            await MainActor.run {
                if let latestStatus {
                    updateStatus(latestStatus)
                } else {
                    statusItem?.button?.title = coordinator?.isIdle == true ? "译" : "..."
                }
            }
        }
    }

    @objc private func triggerFullScreenTranslate() {
        print("[MacGameLens] Full screen translate triggered from menu")
        statusItem?.button?.title = "⟳"
        Task {
            await coordinator?.translateFullScreen()
            await MainActor.run {
                if let latestStatus {
                    updateStatus(latestStatus)
                } else {
                    statusItem?.button?.title = coordinator?.isIdle == true ? "译" : "..."
                }
            }
        }
    }

    @objc private func triggerFocusedWindowTranslate() {
        print("[MacGameLens] Focused window translate triggered from menu")
        statusItem?.button?.title = "⟳"
        Task {
            await coordinator?.translateFocusedWindow()
            await MainActor.run {
                if let latestStatus {
                    updateStatus(latestStatus)
                } else {
                    statusItem?.button?.title = coordinator?.isIdle == true ? "译" : "..."
                }
            }
        }
    }

    @objc private func triggerRegionControlMode() {
        print("[MacGameLens] Region control mode triggered from menu")
        coordinator?.showRegionControlMode()
    }

    @objc private func triggerClear() {
        print("[MacGameLens] Clear triggered")
        Task { 
            await coordinator?.clearOverlay()
            await MainActor.run {
                statusItem?.button?.title = "译"
            }
        }
    }

    @objc private func triggerShowLastOverlay() {
        print("[MacGameLens] Show last overlay triggered")
        Task {
            await coordinator?.showLastOverlay()
            await MainActor.run {
                if let latestStatus {
                    updateStatus(latestStatus)
                }
            }
        }
    }

    @objc private func openSettings() {
        print("[MacGameLens] Opening settings")
        SettingsWindowController.shared.show()
    }

    @objc private func checkPermissions() {
        PermissionController.showPermissionAlert()
        updatePermissionStatus(useCaptureTest: true)
    }

    @objc private func toggleDebugMode() {
        DebugModeStore.shared.isDebugMode.toggle()
        print("[MacGameLens] Debug mode: \(DebugModeStore.shared.isDebugMode)")
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func showDiagnostics() {
        let status = latestStatus ?? coordinator?.statusSnapshot
        let permission = PermissionController.screenRecordingStatus()
        let appPath = PermissionController.currentAppPath()
        let bundleID = Bundle.main.bundleIdentifier ?? "Unknown"
        let detail = status?.detail ?? "Ready"
        let title = status?.title ?? "Idle"

        let alert = NSAlert()
        alert.messageText = "Mac Game Lens Translator Diagnostics"
        alert.informativeText = """
        Status: \(title)
        Detail: \(detail)
        Screen capture: \(permission.summary)
        Preflight check: \(permission.preflightGranted ? "Granted" : "False")
        Real capture test: \(permission.testCaptureSucceeded ? "Succeeded" : "Failed")
        Bundle ID: \(bundleID)
        Running app: \(appPath)
        Log: /tmp/mglt_debug.log
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        updatePermissionStatus(useCaptureTest: true)
    }

    @objc private func openDebugLog() {
        let url = URL(fileURLWithPath: "/tmp/mglt_debug.log")
        NSWorkspace.shared.open(url)
    }

    private func updateStatus(_ snapshot: LensTranslationCoordinator.StatusSnapshot) {
        latestStatus = snapshot
        statusMenuItem?.title = "Status: \(snapshot.title)"
        detailMenuItem?.title = snapshot.detail

        if snapshot.isWorking {
            statusItem?.button?.title = "..."
        } else if snapshot.isOverlayShowing {
            statusItem?.button?.title = "◇"
        } else {
            statusItem?.button?.title = "译"
        }
    }

    private func updatePermissionStatus(useCaptureTest: Bool) {
        if useCaptureTest {
            let status = PermissionController.screenRecordingStatus()
            permissionMenuItem?.title = status.canCaptureScreen ? "Screen Capture: Works" : "Screen Capture: Fix..."
        } else {
            let preflightGranted = PermissionController.checkScreenRecordingPermission()
            permissionMenuItem?.title = preflightGranted ? "Screen Capture: Preflight OK" : "Screen Capture: Check..."
        }
    }
}
