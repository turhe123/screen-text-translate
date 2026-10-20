import Foundation

/// One completed recognition/translation, persisted in history.
struct HistoryItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var original: String
    var translation: String?
    var sourceLanguage: String?
    var targetLanguage: String

    var menuTitle: String {
        let text = (translation ?? original).replacingOccurrences(of: "\n", with: " ")
        return text.count > 40 ? String(text.prefix(40)) + "…" : text
    }
}

/// Keeps recent translations in a JSON file under Application Support.
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    static let lengthKey = "historyLength"

    @Published private(set) var items: [HistoryItem] = []

    private var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("ScreenTextTranslate", isDirectory: true).appendingPathComponent("history.json")
    }

    private var limit: Int {
        let value = UserDefaults.standard.integer(forKey: Self.lengthKey)
        return value > 0 ? value : 20
    }

    init() {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else { return }
        items = decoded
    }

    func add(_ item: HistoryItem) {
        items.removeAll { $0.original == item.original && $0.targetLanguage == item.targetLanguage }
        items.insert(item, at: 0)
        trimAndSave()
    }

    func clear() {
        items = []
        save()
    }

    func trimAndSave() {
        if items.count > limit { items = Array(items.prefix(limit)) }
        save()
    }

    private func save() {
        guard let url = fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(items).write(to: url, options: .atomic)
        } catch {
            NSLog("ScreenTextTranslate: failed to save history: \(error)")
        }
    }
}
