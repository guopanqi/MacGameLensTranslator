import AppKit

@MainActor
final class RegionControlWindowController {
    static let shared = RegionControlWindowController()

    private var editWindow: NSWindow?
    private var toolbarWindow: NSWindow?
    private var screen: NSScreen?
    private var selectionRect: CGRect?
    private let storageKey = "regionControlSelectionRect"

    var onTranslate: ((SelectedScreenRegion) -> Void)?
    var onClear: (() -> Void)?
    var onShowLast: (() -> Void)?
    var onClose: (() -> Void)?

    var selectedRegion: SelectedScreenRegion? {
        guard let screen, let selectionRect else { return nil }
        return SelectedScreenRegion(displayFrame: screen.frame, localRect: selectionRect)
    }

    func show() {
        if toolbarWindow != nil || editWindow != nil {
            enterEditingMode()
            return
        }

        screen = screenUnderMouse() ?? NSScreen.main
        selectionRect = loadStoredSelectionRect()
        enterEditingMode()
    }

    private func enterEditingMode() {
        toolbarWindow?.close()
        toolbarWindow = nil

        guard let screen else { return }
        if selectionRect == nil {
            selectionRect = defaultSelectionRect(for: screen.frame.size)
        }

        let panel = RegionEditPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true

        let view = RegionEditView(frame: NSRect(origin: .zero, size: screen.frame.size), selectionRect: selectionRect ?? defaultSelectionRect(for: screen.frame.size))
        view.onSelectionChanged = { [weak self] rect in
            self?.selectionRect = rect
            self?.storeSelectionRect(rect)
        }
        view.onConfirm = { [weak self] rect in
            self?.selectionRect = rect
            self?.storeSelectionRect(rect)
            self?.enterFloatingMode()
        }
        view.onCancel = { [weak self] in
            self?.close()
        }

        panel.contentView = view
        panel.orderFrontRegardless()
        editWindow = panel
        print("[MGLT] Region control edit mode shown: frame=\(screen.frame)")
    }

    private func enterFloatingMode() {
        editWindow?.close()
        editWindow = nil

        guard let screen, let selectionRect else { return }

        let toolbarFrame = toolbarGlobalFrame(for: selectionRect, on: screen)
        let panel = RegionToolbarPanel(
            contentRect: toolbarFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false

        let view = RegionToolbarView(frame: NSRect(origin: .zero, size: toolbarFrame.size))
        view.onTranslate = { [weak self] in
            guard let self, let selectedRegion else { return }
            onTranslate?(selectedRegion)
        }
        view.onClear = { [weak self] in self?.onClear?() }
        view.onShowLast = { [weak self] in self?.onShowLast?() }
        view.onResize = { [weak self] in self?.enterEditingMode() }
        view.onClose = { [weak self] in self?.close() }

        panel.contentView = view
        panel.orderFrontRegardless()
        toolbarWindow = panel
        print("[MGLT] Region control floating toolbar shown: frame=\(toolbarFrame)")
    }

    func close() {
        editWindow?.close()
        toolbarWindow?.close()
        editWindow = nil
        toolbarWindow = nil
        print("[MGLT] Region control mode closed")
        onClose?()
    }

    private func toolbarGlobalFrame(for selectionRect: CGRect, on screen: NSScreen) -> CGRect {
        let size = CGSize(width: 240, height: 48)
        let margin: CGFloat = 12
        var localX = selectionRect.maxX - size.width
        var localY = selectionRect.maxY + margin
        if localY + size.height > screen.frame.height - margin {
            localY = selectionRect.minY - size.height - margin
        }
        localX = min(max(localX, margin), screen.frame.width - size.width - margin)
        localY = min(max(localY, margin), screen.frame.height - size.height - margin)

        return CGRect(
            x: screen.frame.minX + localX,
            y: screen.frame.maxY - localY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func loadStoredSelectionRect() -> CGRect? {
        guard let screen else { return nil }
        guard let string = UserDefaults.standard.string(forKey: storageKey) else {
            return defaultSelectionRect(for: screen.frame.size)
        }

        let rect = NSRectFromString(string)
        guard rect.width >= 120,
              rect.height >= 80,
              CGRect(origin: .zero, size: screen.frame.size).contains(CGPoint(x: rect.midX, y: rect.midY)) else {
            return defaultSelectionRect(for: screen.frame.size)
        }
        return rect.intersection(CGRect(origin: .zero, size: screen.frame.size))
    }

    private func storeSelectionRect(_ rect: CGRect) {
        UserDefaults.standard.set(NSStringFromRect(rect), forKey: storageKey)
    }

    private func defaultSelectionRect(for size: CGSize) -> CGRect {
        let width = max(320, size.width * 0.55)
        let height = max(220, size.height * 0.55)
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }
}

private final class RegionEditPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class RegionToolbarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class RegionEditView: NSView {
    private enum DragMode {
        case move(start: CGPoint, original: CGRect)
        case resize(edgeMask: EdgeMask, start: CGPoint, original: CGRect)
    }

    private struct EdgeMask: OptionSet {
        let rawValue: Int
        static let left = EdgeMask(rawValue: 1 << 0)
        static let right = EdgeMask(rawValue: 1 << 1)
        static let top = EdgeMask(rawValue: 1 << 2)
        static let bottom = EdgeMask(rawValue: 1 << 3)
    }

    var onSelectionChanged: ((CGRect) -> Void)?
    var onConfirm: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var selectionRect: CGRect
    private var dragMode: DragMode?
    private let minimumSize = CGSize(width: 120, height: 80)
    private let handleTolerance: CGFloat = 14
    private let toolbar = NSVisualEffectView()

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(frame frameRect: NSRect, selectionRect: CGRect) {
        self.selectionRect = selectionRect
        super.init(frame: frameRect)
        setupToolbar()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.46).setFill()
        bounds.fill()

        let dimmer = NSBezierPath(rect: bounds)
        dimmer.append(NSBezierPath(rect: selectionRect).reversed)
        dimmer.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.25).setFill()
        dimmer.fill()

        let border = NSBezierPath(rect: selectionRect)
        NSColor.white.withAlphaComponent(0.95).setStroke()
        border.lineWidth = 2
        border.stroke()
        drawCornerTicks()
    }

    override func layout() {
        super.layout()
        positionToolbar()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let edgeMask = edgeMask(at: point) {
            dragMode = .resize(edgeMask: edgeMask, start: point, original: selectionRect)
        } else if selectionRect.contains(point) {
            dragMode = .move(start: point, original: selectionRect)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragMode else { return }
        let point = convert(event.locationInWindow, from: nil)
        switch dragMode {
        case .move(let start, let original):
            selectionRect.origin.x = original.origin.x + point.x - start.x
            selectionRect.origin.y = original.origin.y + point.y - start.y
        case .resize(let edgeMask, let start, let original):
            let dx = point.x - start.x
            let dy = point.y - start.y
            var next = original
            if edgeMask.contains(.left) {
                next.origin.x += dx
                next.size.width -= dx
            }
            if edgeMask.contains(.right) {
                next.size.width += dx
            }
            if edgeMask.contains(.top) {
                next.origin.y += dy
                next.size.height -= dy
            }
            if edgeMask.contains(.bottom) {
                next.size.height += dy
            }
            selectionRect = next
        }

        clampSelectionRect()
        onSelectionChanged?(selectionRect)
        needsDisplay = true
        needsLayout = true
    }

    override func mouseUp(with event: NSEvent) {
        dragMode = nil
        onSelectionChanged?(selectionRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else if event.keyCode == 36 {
            onConfirm?(selectionRect)
        } else {
            super.keyDown(with: event)
        }
    }

    private func setupToolbar() {
        toolbar.material = .hudWindow
        toolbar.blendingMode = .withinWindow
        toolbar.state = .active
        toolbar.wantsLayer = true
        toolbar.layer?.cornerRadius = 12
        toolbar.layer?.masksToBounds = true

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(makeButton(symbol: "checkmark", tooltip: "Confirm region", action: #selector(confirmRegion)))
        stack.addArrangedSubview(makeButton(symbol: "xmark", tooltip: "Close region mode", action: #selector(cancelRegion)))

        toolbar.addSubview(stack)
        addSubview(toolbar)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            stack.topAnchor.constraint(equalTo: toolbar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor)
        ])
    }

    private func makeButton(symbol: String, tooltip: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) ?? NSImage(), target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.toolTip = tooltip
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])
        return button
    }

    private func positionToolbar() {
        let size = CGSize(width: 108, height: 48)
        let margin: CGFloat = 12
        var x = selectionRect.maxX - size.width
        var y = selectionRect.maxY + margin
        if y + size.height > bounds.height - margin {
            y = selectionRect.minY - size.height - margin
        }
        x = min(max(x, margin), bounds.width - size.width - margin)
        y = min(max(y, margin), bounds.height - size.height - margin)
        toolbar.frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private func drawCornerTicks() {
        let length: CGFloat = 28
        let path = NSBezierPath()
        let r = selectionRect
        path.move(to: CGPoint(x: r.minX, y: r.minY + length))
        path.line(to: CGPoint(x: r.minX, y: r.minY))
        path.line(to: CGPoint(x: r.minX + length, y: r.minY))
        path.move(to: CGPoint(x: r.maxX - length, y: r.minY))
        path.line(to: CGPoint(x: r.maxX, y: r.minY))
        path.line(to: CGPoint(x: r.maxX, y: r.minY + length))
        path.move(to: CGPoint(x: r.maxX, y: r.maxY - length))
        path.line(to: CGPoint(x: r.maxX, y: r.maxY))
        path.line(to: CGPoint(x: r.maxX - length, y: r.maxY))
        path.move(to: CGPoint(x: r.minX + length, y: r.maxY))
        path.line(to: CGPoint(x: r.minX, y: r.maxY))
        path.line(to: CGPoint(x: r.minX, y: r.maxY - length))
        NSColor.white.setStroke()
        path.lineWidth = 3
        path.stroke()
    }

    private func edgeMask(at point: CGPoint) -> EdgeMask? {
        guard selectionRect.insetBy(dx: -handleTolerance, dy: -handleTolerance).contains(point) else { return nil }
        var mask: EdgeMask = []
        if abs(point.x - selectionRect.minX) <= handleTolerance { mask.insert(.left) }
        if abs(point.x - selectionRect.maxX) <= handleTolerance { mask.insert(.right) }
        if abs(point.y - selectionRect.minY) <= handleTolerance { mask.insert(.top) }
        if abs(point.y - selectionRect.maxY) <= handleTolerance { mask.insert(.bottom) }
        return mask.isEmpty ? nil : mask
    }

    private func clampSelectionRect() {
        selectionRect.size.width = max(selectionRect.width, minimumSize.width)
        selectionRect.size.height = max(selectionRect.height, minimumSize.height)
        selectionRect.origin.x = min(max(selectionRect.minX, 0), bounds.width - selectionRect.width)
        selectionRect.origin.y = min(max(selectionRect.minY, 0), bounds.height - selectionRect.height)
    }

    @objc private func confirmRegion() {
        onConfirm?(selectionRect)
    }

    @objc private func cancelRegion() {
        onCancel?()
    }
}

private final class RegionToolbarView: NSVisualEffectView {
    var onTranslate: (() -> Void)?
    var onClear: (() -> Void)?
    var onShowLast: (() -> Void)?
    var onResize: (() -> Void)?
    var onClose: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        setupButtons()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setupButtons() {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(makeButton(symbol: "text.viewfinder", tooltip: "Translate selected region", action: #selector(translateRegion)))
        stack.addArrangedSubview(makeButton(symbol: "trash", tooltip: "Clear overlay", action: #selector(clearOverlay)))
        stack.addArrangedSubview(makeButton(symbol: "arrow.counterclockwise", tooltip: "Show last overlay", action: #selector(showLastOverlay)))
        stack.addArrangedSubview(makeButton(symbol: "rectangle.and.pencil.and.ellipsis", tooltip: "Resize region", action: #selector(resizeRegion)))
        stack.addArrangedSubview(makeButton(symbol: "xmark", tooltip: "Close region mode", action: #selector(closeRegionMode)))

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func makeButton(symbol: String, tooltip: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) ?? NSImage(), target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.toolTip = tooltip
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])
        return button
    }

    @objc private func translateRegion() { onTranslate?() }
    @objc private func clearOverlay() { onClear?() }
    @objc private func showLastOverlay() { onShowLast?() }
    @objc private func resizeRegion() { onResize?() }
    @objc private func closeRegionMode() { onClose?() }
}
