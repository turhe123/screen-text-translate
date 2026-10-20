import SwiftUI
import AppKit

/// App entry point: a menu-bar-only app exposing capture, history, settings and support actions.
@main
struct ScreenTextTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController.shared
    @StateObject private var history = HistoryStore.shared

    var body: some Scene {
        MenuBarExtra("ScreenTextTranslate", systemImage: "character.bubble") {
            Button("Translate Region  (\(HotKeyManager.displayString))") { controller.startCapture() }
            Divider()
            Text("Recent translations")
            if history.items.isEmpty {
                Text("Nothing translated yet")
            } else {
                ForEach(history.items) { item in
                    Menu(item.menuTitle) {
                        Button("Copy Original") { Pasteboard.copy(item.original) }
                        if let translation = item.translation {
                            Button("Copy Translation") { Pasteboard.copy(translation) }
                        }
                    }
                }
                Button("Clear History") { history.clear() }
            }
            Divider()
            Button("Settings…") { controller.openSettings() }.keyboardShortcut(",")
            Button("Support / Donate ❤️") { AppController.openDonation() }
            Divider()
            Button("Quit ScreenTextTranslate") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}

/// Registers the global hotkey once the app has finished launching.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HotKeyManager.shared.onPress = { AppController.shared.startCapture() }
        HotKeyManager.shared.registerFromDefaults()
    }
}

/// Small helper around the general pasteboard.
enum Pasteboard {
    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
