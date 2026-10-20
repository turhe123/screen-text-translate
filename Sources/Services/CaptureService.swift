import AppKit
import ScreenCaptureKit

/// Captures a screen region with ScreenCaptureKit and manages the Screen Recording permission.
enum CaptureService {
    /// Longest edge, in pixels, of a captured image; larger regions are downscaled.
    static let maxPixelEdge: CGFloat = 3000

    enum CaptureError: LocalizedError {
        case displayNotFound
        var errorDescription: String? { "The selected display is not available for capture." }
    }

    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// Requests permission if needed; returns whether capture is allowed.
    static func ensurePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return CGRequestScreenCaptureAccess()
    }

    static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Captures `rect` (global AppKit coordinates) on `screen`, excluding this app's own windows.
    static func capture(rect: CGRect, on screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])

        // ScreenCaptureKit uses a top-left origin relative to the display.
        let frame = screen.frame
        let source = CGRect(x: rect.minX - frame.minX, y: frame.maxY - rect.maxY,
                            width: rect.width, height: rect.height)
        var scale = screen.backingScaleFactor
        let longest = max(rect.width, rect.height) * scale
        if longest > maxPixelEdge { scale *= maxPixelEdge / longest }

        let config = SCStreamConfiguration()
        config.sourceRect = source
        config.width = max(1, Int(rect.width * scale))
        config.height = max(1, Int(rect.height * scale))
        config.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}
