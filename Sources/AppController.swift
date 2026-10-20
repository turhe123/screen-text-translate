import AppKit
import SwiftUI

/// Orchestrates the capture → OCR → translate flow and owns the app's windows.
@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()
    static let targetKey = "targetLanguage"
    static let overlayKey = "overlayMode"
    static let autoCopyKey = "autoCopyTranslation"

    private var panel: ResultPanel?
    private var settingsWindow: NSWindow?

    static func openDonation() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
    }

    func startCapture() {
        guard !RegionSelector.shared.isActive else { return }
        guard CaptureService.ensurePermission() else { showPermissionGuide(); return }
        panel?.close()
        RegionSelector.shared.begin { [weak self] rect, screen in
            Task { @MainActor in await self?.process(rect: rect, screen: screen) }
        }
    }

    private func process(rect: CGRect, screen: NSScreen) async {
        let image: CGImage
        do {
            // Give the overlay windows a moment to leave the screen.
            try await Task.sleep(nanoseconds: 80_000_000)
            image = try await CaptureService.capture(rect: rect, on: screen)
        } catch {
            if !CaptureService.hasPermission { showPermissionGuide() } else { showError(error.localizedDescription) }
            return
        }
        let favorites = AppLanguage.favorites
        let result = await Task.detached(priority: .userInitiated) {
            TextRecognizer.recognize(image, favorites: favorites)
        }.value

        guard !result.text.isEmpty else {
            let toast = ResultPanel(content: NoTextView(), translucent: true)
            toast.place(near: rect, on: screen)
            toast.orderFrontRegardless()
            toast.dismiss(after: 2)
            return
        }

        let defaults = UserDefaults.standard
        let target = defaults.string(forKey: Self.targetKey) ?? Self.defaultTarget
        let model = ResultModel(result: result, image: image, target: target)
        model.onFinished = { model in
            HistoryStore.shared.add(HistoryItem(original: model.original, translation: model.translation,
                                                sourceLanguage: model.sourceLanguage, targetLanguage: model.targetLanguage))
            if let translation = model.translation, defaults.bool(forKey: Self.autoCopyKey) {
                Pasteboard.copy(translation)
            }
        }

        let useOverlay: Bool
        if #available(macOS 15.0, *) { useOverlay = defaults.bool(forKey: Self.overlayKey) && !result.blocks.isEmpty }
        else { useOverlay = false }

        let newPanel: ResultPanel
        if useOverlay {
            newPanel = ResultPanel(content: OverlayResultView(model: model, size: rect.size), translucent: false)
            newPanel.setFrame(rect, display: false)
        } else {
            newPanel = ResultPanel(content: ResultCardView(model: model), translucent: true)
            newPanel.place(near: rect, on: screen)
        }
        model.onClose = { [weak newPanel] in newPanel?.close() }
        newPanel.onClosed = { [weak self, weak newPanel] in
            if self?.panel === newPanel { self?.panel = nil }
        }
        panel = newPanel
        newPanel.present()
        model.start()
    }

    /// Default target: the user's preferred language if we offer it, otherwise English.
    static var defaultTarget: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return AppLanguage.all.first { AppLanguage.matches($0.code, preferred) }?.code ?? "en"
    }

    func showPermissionGuide() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Screen Recording permission needed"
        alert.informativeText = """
        ScreenTextTranslate needs Screen Recording access to read text from the area you select. \
        Open System Settings → Privacy & Security → Screen & System Audio Recording, enable \
        ScreenTextTranslate, then quit and reopen the app.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { CaptureService.openPrivacySettings() }
    }

    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Capture failed"
        alert.informativeText = message
        alert.runModal()
    }

    func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "ScreenTextTranslate Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
