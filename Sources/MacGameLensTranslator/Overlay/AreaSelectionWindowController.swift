import AppKit

struct SelectedScreenRegion {
    let displayFrame: CGRect
    let localRect: CGRect
}

@MainActor
final class AreaSelectionWindowController {
    static let shared = AreaSelectionWindowController()

    private var window: NSWindow?
    private var continuation: CheckedContinuation<SelectedScreenRegion?, Never>?

    func selectRegion() async -> SelectedScreenRegion? {
        cancelSelection()
        guard let screen = screenUnderMouse() ?? NSScreen.main else { return nil }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            showSelectionWindow(on: screen)
        }
    }

    private func showSelectionWindow(on screen: NSScreen) {
        let panel = SelectionPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true

        let selectionView = AreaSelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
        selectionView.onComplete = { [weak self] rect in
            self?.finishSelection(screen: screen, rect: rect)
        }
        selectionView.onCancel = { [weak self] in
            self?.cancelSelection()
        }

        panel.contentView = selectionView
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(selectionView)
        window = panel
        print("[MGLT] Selection window shown: visible=\(panel.isVisible), frame=\(panel.frame), level=\(panel.level.rawValue)")
    }

    private func finishSelection(screen: NSScreen, rect: CGRect) {
        cleanup()
        continuation?.resume(returning: SelectedScreenRegion(displayFrame: screen.frame, localRect: rect))
        continuation = nil
    }

    func cancelSelection() {
        cleanup()
        continuation?.resume(returning: nil)
        continuation = nil
    }

    private func cleanup() {
        window?.close()
        window = nil
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }
}

private final class SelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class AreaSelectionView: NSView {
    var onComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.28).setFill()
        bounds.fill()

        guard let selectionRect else { return }

        NSColor.systemYellow.withAlphaComponent(0.18).setFill()
        selectionRect.fill()

        NSColor.systemYellow.setStroke()
        let path = NSBezierPath(rect: selectionRect)
        path.lineWidth = 2
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStart = point
        dragCurrent = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        dragCurrent = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        dragCurrent = convert(event.locationInWindow, from: nil)
        guard let rect = selectionRect, rect.width >= 8, rect.height >= 8 else {
            onCancel?()
            return
        }
        onComplete?(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    private var selectionRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }
}
