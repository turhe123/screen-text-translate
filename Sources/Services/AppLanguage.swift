import Foundation

/// A language the app offers as a translation target or favorite OCR source.
struct AppLanguage: Identifiable, Hashable {
    /// BCP-47 code used by Translation and NaturalLanguage (e.g. "zh-Hans").
    let code: String
    /// Identifier used by Vision text recognition (e.g. "ja-JP").
    let visionCode: String
    var id: String { code }

    var name: String { Self.displayName(for: code) }

    static func displayName(for code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }

    static let all: [AppLanguage] = [
        ("en", "en-US"), ("es", "es-ES"), ("fr", "fr-FR"), ("de", "de-DE"), ("it", "it-IT"),
        ("pt", "pt-BR"), ("nl", "nl-NL"), ("pl", "pl-PL"), ("ru", "ru-RU"), ("uk", "uk-UA"),
        ("tr", "tr-TR"), ("ar", "ar-SA"), ("hi", "hi-IN"), ("th", "th-TH"), ("vi", "vi-VT"),
        ("id", "id-ID"), ("ja", "ja-JP"), ("ko", "ko-KR"), ("zh-Hans", "zh-Hans"), ("zh-Hant", "zh-Hant"),
    ].map { AppLanguage(code: $0.0, visionCode: $0.1) }

    static func language(for code: String) -> AppLanguage? { all.first { $0.code == code } }

    /// Favorite source languages stored as a comma-separated list in UserDefaults.
    static let favoritesKey = "favoriteSourceLanguages"
    static var favorites: [AppLanguage] {
        (UserDefaults.standard.string(forKey: favoritesKey) ?? "")
            .split(separator: ",").compactMap { language(for: String($0)) }
    }

    /// Whether two codes refer to the same base language ("zh-Hans" vs "zh-Hant" differ).
    static func matches(_ a: String, _ b: String) -> Bool {
        if a.hasPrefix("zh") || b.hasPrefix("zh") { return a == b }
        return a.split(separator: "-").first == b.split(separator: "-").first
    }
}
