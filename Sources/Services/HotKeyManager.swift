import AppKit
import Carbon.HIToolbox

/// Registers a single system-wide hotkey through Carbon's RegisterEventHotKey.
final class HotKeyManager {
    static let shared = HotKeyManager()
    static let keyCodeKey = "hotKeyCode"
    static let modifiersKey = "hotKeyModifiers"
    static let labelKey = "hotKeyLabel"

    var onPress: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false

    /// Human-readable shortcut, e.g. "⌃⌥T".
    static var displayString: String {
        let defaults = UserDefaults.standard
        let mods = defaults.object(forKey: modifiersKey) as? Int ?? (controlKey | optionKey)
        let label = defaults.string(forKey: labelKey) ?? "T"
        return symbols(for: mods) + label
    }

    static func symbols(for carbonModifiers: Int) -> String {
        var s = ""
        if carbonModifiers & controlKey != 0 { s += "⌃" }
        if carbonModifiers & optionKey != 0 { s += "⌥" }
        if carbonModifiers & shiftKey != 0 { s += "⇧" }
        if carbonModifiers & cmdKey != 0 { s += "⌘" }
        return s
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.control) { m |= controlKey }
        if flags.contains(.option) { m |= optionKey }
        if flags.contains(.shift) { m |= shiftKey }
        if flags.contains(.command) { m |= cmdKey }
        return m
    }

    func registerFromDefaults() {
        let defaults = UserDefaults.standard
        let code = defaults.object(forKey: Self.keyCodeKey) as? Int ?? kVK_ANSI_T
        let mods = defaults.object(forKey: Self.modifiersKey) as? Int ?? (controlKey | optionKey)
        register(keyCode: UInt32(code), modifiers: UInt32(mods))
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        installHandlerIfNeeded()
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        let id = EventHotKeyID(signature: OSType(0x53545454), id: 1) // 'STTT'
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr { NSLog("ScreenTextTranslate: hotkey registration failed (\(status))") }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKeyManager.shared.onPress?() }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = true
    }
}
