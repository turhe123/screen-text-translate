import AppKit
import SwiftUI

/// Floating panel hosting a result view; closes on Escape or a click outside the app.
final class ResultPanel: NSPanel {
    private var monitors: [Any] = []
    var onClosed: (() -> Void)?

    init<Content: View>(content: Content, translucent: Bool) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let host = NSHostingView(rootView: content)
        let container: NSView
        if translucent {
            let effect = NSVisualEffectView()
            effect.material = .popover
            effect.state = .active
            effect.addSubview(host)
            container = effect
        } else {
            let plain = NSView()
            plain.addSubview(host)
            container = plain
        }
        container.wantsLayer = true
        container.layer?.cornerRadius = translucent ? 12 : 4
        container.layer?.masksToBounds = true
        host.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container
        setContentSize(host.fittingSize)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { close() }

    /// Shows the panel and starts watching for Escape / outside clicks.
    func present() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            self?.close()
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == 53, self?.isVisible == true { self?.close(); return nil }
            return event
        }) { monitors.append(local) }
    }

    /// Fades out and closes after `delay` seconds.
    func dismiss(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                self?.animator().alphaValue = 0
            }, completionHandler: { self?.close() })
        }
    }

    override func close() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        super.close()
        onClosed?()
        onClosed = nil
    }

    /// Positions the panel below `selection` (or above if there is no room), kept on-screen.
    func place(near selection: CGRect, on screen: NSScreen) {
        let visible = screen.visibleFrame
        let size = frame.size
        var origin = CGPoint(x: selection.minX, y: selection.minY - size.height - 8)
        if origin.y < visible.minY { origin.y = selection.maxY + 8 }
        if origin.y + size.height > visible.maxY { origin.y = visible.maxY - size.height }
        origin.x = min(max(origin.x, visible.minX + 4), visible.maxX - size.width - 4)
        origin.y = max(origin.y, visible.minY + 4)
        setFrameOrigin(origin)
    }
}
