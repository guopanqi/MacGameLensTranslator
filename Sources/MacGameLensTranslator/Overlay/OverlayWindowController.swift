import AppKit
import os

final class OverlayWindowController {
    private var window: NSWindow?
    private weak var canvasView: OverlayCanvasView?
    private let logger = Logger(subsystem: "com.macgamelens.translator", category: "overlay")

    var isShowing: Bool { window != nil }

    @MainActor
    func show(blocks: [OverlayTextBlock], displayFrame: CGRect, debugMode: Bool = false, opacity: Double = 0.75, fontSizeScale: Double = 1.0, levelMode: OverlayLevelMode = .normal) -> Bool {
        print("[MGLT] OverlayWindowController.show called, blocks=\(blocks.count), debug=\(debugMode)")
        if blocks.isEmpty {
            print("[MGLT] WARNING: No overlay blocks to show")
            return false
        }
        showSync(blocks: blocks, displayFrame: displayFrame, debugMode: debugMode, opacity: opacity, fontSizeScale: fontSizeScale, levelMode: levelMode)
        return window?.isVisible == true
    }

    private func showSync(blocks: [OverlayTextBlock], displayFrame: CGRect, debugMode: Bool, opacity: Double, fontSizeScale: Double, levelMode: OverlayLevelMode) {
        print("[MGLT] showSync: frame=\(displayFrame), level=\(levelMode), blocks=\(blocks.count)")
        hideSync()

        let windowLevel: NSWindow.Level = {
            switch levelMode {
            case .normal: return .floating
            case .strong: return .statusBar
            case .emergency: return .screenSaver
            }
        }()

        let contentRect = NSRect(x: displayFrame.origin.x, y: displayFrame.origin.y, width: displayFrame.width, height: displayFrame.height)
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = windowLevel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        let canvasView = OverlayCanvasView(frame: NSRect(x: 0, y: 0, width: displayFrame.width, height: displayFrame.height))
        canvasView.blocks = blocks
        canvasView.showDebugBounds = debugMode
        canvasView.overlayOpacity = opacity
        canvasView.fontSizeScale = fontSizeScale

        panel.contentView = canvasView
        self.canvasView = canvasView

        panel.orderFrontRegardless()
        self.window = panel

        print("[MGLT] Overlay window ordered front: \(panel.isVisible), frame=\(panel.frame)")
        logger.debug("Overlay shown with \(blocks.count) blocks, level=\(String(describing: levelMode))")
    }

    @MainActor
    func update(blocks: [OverlayTextBlock]) {
        canvasView?.blocks = blocks
    }

    @MainActor
    func hide() {
        hideSync()
    }

    private func hideSync() {
        print("[MGLT] Hiding overlay window")
        window?.close()
        window = nil
        canvasView = nil
        logger.debug("Overlay hidden")
    }
}
