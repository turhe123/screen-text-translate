import AppKit

/// Presents a dimmed crosshair overlay on every display and reports the dragged rectangle.
final class RegionSelector {
    static let shared = RegionSelector()
    private var windows: [NSWindow] = []
    private var completion: ((CGRect, NSScreen) -> Void)?

    var isActive: Bool { !windows.isEmpty }

    func begin(completion: @escaping (CGRect, NSScreen) -> Void) {
        guard !isActive else { return }
        self.completion = completion
        for screen in NSScreen.screens {
            let window = SelectionWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.setFrame(screen.frame, display: false)
            let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.onFinish = { [weak self] rect in self?.finish(rect: rect, screen: screen) }
            view.onCancel = { [weak self] in self?.cancel() }
            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        let mouse = NSEvent.mouseLocation
        let key = windows.first { $0.frame.contains(mouse) } ?? windows.first
        key?.makeKey()
        key?.makeFirstResponder(key?.contentView)
        NSCursor.crosshair.set()
    }

    func cancel() {
        tearDown()
        completion = nil
    }

    private func finish(rect: CGRect, screen: NSScreen) {
        let done = completion
        tearDown()
        completion = nil
        guard rect.width >= 8, rect.height >= 8 else { return }
        done?(rect, screen)
    }

    private func tearDown() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        NSCursor.arrow.set()
    }
}

/// Borderless window that can become key so it receives Escape.
private final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Draws the dimmed backdrop and the selection rectangle; handles mouse and Escape.
private final class SelectionView: NSView {
    var onFinish: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    private var start: CGPoint?
    private var current: CGPoint?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    private var selection: CGRect? {
        guard let s = start, let c = current else { return nil }
        return CGRect(x: min(s.x, c.x), y: min(s.y, c.y), width: abs(s.x - c.x), height: abs(s.y - c.y))
            .intersection(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        guard let rect = selection else { return }
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        path.lineWidth = 1.5
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        guard let rect = selection, let window else { onCancel?(); return }
        onFinish?(rect.offsetBy(dx: window.frame.minX, dy: window.frame.minY))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
    }

    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
