import SwiftUI
import AppKit
import ServiceManagement

/// Settings window: hotkey, target language, favorites, overlay/auto-copy, history and login item.
struct SettingsView: View {
    @AppStorage(AppController.targetKey) private var target = AppController.defaultTarget
    @AppStorage(AppController.overlayKey) private var overlayMode = false
    @AppStorage(AppController.autoCopyKey) private var autoCopy = false
    @AppStorage(HistoryStore.lengthKey) private var historyLength = 20
    @AppStorage(AppLanguage.favoritesKey) private var favoritesRaw = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var hasPermission = CaptureService.hasPermission

    var body: some View {
        Form {
            Section("Shortcut") {
                LabeledContent("Translate Region") { HotKeyRecorder() }
            }
            Section("Translation") {
                Picker("Target language", selection: $target) {
                    ForEach(AppLanguage.all) { Text($0.name).tag($0.code) }
                }
                Toggle("Overlay translation on top of the original text", isOn: $overlayMode)
                Toggle("Automatically copy translation", isOn: $autoCopy)
                if #unavailable(macOS 15.0) {
                    Text("On-device translation requires macOS 15. On this Mac, recognized text can be copied or looked up.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Favorite source languages (improves recognition)") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading) {
                    ForEach(AppLanguage.all) { lang in
                        Toggle(lang.name, isOn: favoriteBinding(lang.code)).toggleStyle(.checkbox)
                    }
                }
            }
            Section("General") {
                Stepper("History length: \(historyLength)", value: $historyLength, in: 5...100, step: 5)
                    .onChange(of: historyLength) { HistoryStore.shared.trimAndSave() }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                HStack {
                    Label(hasPermission ? "Screen Recording allowed" : "Screen Recording not allowed",
                          systemImage: hasPermission ? "checkmark.shield" : "exclamationmark.shield")
                        .foregroundStyle(hasPermission ? Color.green : Color.orange)
                    Spacer()
                    if !hasPermission {
                        Button("Open Privacy Settings") { CaptureService.openPrivacySettings() }
                    }
                }
            }
            Section {
                HStack {
                    Text("ScreenTextTranslate is free and open source.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Support / Donate ❤️") { AppController.openDonation() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 640)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasPermission = CaptureService.hasPermission
        }
    }

    private func favoriteBinding(_ code: String) -> Binding<Bool> {
        Binding(
            get: { favoritesRaw.split(separator: ",").contains { String($0) == code } },
            set: { on in
                var codes = favoritesRaw.split(separator: ",").map(String.init).filter { $0 != code }
                if on { codes.append(code) }
                favoritesRaw = codes.joined(separator: ",")
            })
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't update login item: \(error.localizedDescription)"
        }
    }
}

/// Click-to-record control that captures a modifier+key combination for the global hotkey.
struct HotKeyRecorder: View {
    @State private var recording = false
    @State private var label = HotKeyManager.displayString
    @State private var monitor: Any?

    var body: some View {
        Button(recording ? "Press shortcut… (Esc to cancel)" : label) {
            recording ? stop() : start()
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }
            let mods = HotKeyManager.carbonModifiers(from: event.modifierFlags)
            guard mods != 0, let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return nil }
            let defaults = UserDefaults.standard
            defaults.set(Int(event.keyCode), forKey: HotKeyManager.keyCodeKey)
            defaults.set(mods, forKey: HotKeyManager.modifiersKey)
            defaults.set(chars.uppercased(), forKey: HotKeyManager.labelKey)
            HotKeyManager.shared.registerFromDefaults()
            label = HotKeyManager.displayString
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}
