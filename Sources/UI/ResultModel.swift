import SwiftUI
import Translation

/// State for one result card/overlay: recognized text, detected language and translation progress.
final class ResultModel: ObservableObject {
    enum Status: Equatable {
        case translating, done, sameLanguage, needsDownload, unsupported, unavailableOS
        case failed(String)
    }

    let original: String
    let blocks: [TextBlock]
    let image: CGImage?
    let sourceLanguage: String?
    @Published var targetLanguage: String { didSet { if targetLanguage != oldValue { start() } } }
    @Published var translation: String?
    @Published var blockTranslations: [UUID: String] = [:]
    @Published var status: Status = .translating
    /// Bumped to ask the translation driver to (re)run; `allowDownload` lets it fetch language packs.
    @Published var requestID = 0
    var allowDownload = false

    var onClose: (() -> Void)?
    var onFinished: ((ResultModel) -> Void)?

    init(result: RecognitionResult, image: CGImage?, target: String) {
        original = result.text
        blocks = result.blocks
        self.image = image
        sourceLanguage = result.language
        targetLanguage = target
    }

    var sourceName: String {
        sourceLanguage.map(AppLanguage.displayName(for:)) ?? "Unknown language"
    }

    /// Decides whether translation is needed and kicks off the driver.
    func start() {
        translation = nil
        blockTranslations = [:]
        if let source = sourceLanguage, AppLanguage.matches(source, targetLanguage) {
            status = .sameLanguage
            onFinished?(self)
            return
        }
        guard #available(macOS 15.0, *) else {
            status = .unavailableOS
            onFinished?(self)
            return
        }
        status = .translating
        requestID += 1
    }

    func downloadLanguage() {
        allowDownload = true
        status = .translating
        requestID += 1
    }

    @available(macOS 15.0, *)
    @MainActor
    func run(_ session: TranslationSession) async {
        do {
            if allowDownload { try await session.prepareTranslation() }
            if blocks.isEmpty {
                translation = try await session.translate(original).targetText
            } else {
                let requests = blocks.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: $0.id.uuidString) }
                let responses = try await session.translations(from: requests)
                var map: [UUID: String] = [:]
                for response in responses {
                    if let id = response.clientIdentifier.flatMap(UUID.init(uuidString:)) { map[id] = response.targetText }
                }
                blockTranslations = map
                translation = try await session.translate(original).targetText
            }
            status = .done
            onFinished?(self)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}

/// Bridges `ResultModel` to the SwiftUI `translationTask` API (macOS 15+).
@available(macOS 15.0, *)
struct TranslationDriver: ViewModifier {
    @ObservedObject var model: ResultModel
    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .translationTask(configuration) { session in await model.run(session) }
            .task(id: model.requestID) { await prepare() }
    }

    @MainActor
    private func prepare() async {
        guard model.requestID > 0, model.status == .translating else { return }
        let source = model.sourceLanguage.map { Locale.Language(identifier: $0) }
        let target = Locale.Language(identifier: model.targetLanguage)
        if let source, !model.allowDownload {
            switch await LanguageAvailability().status(from: source, to: target) {
            case .installed: break
            case .supported: model.status = .needsDownload; return
            case .unsupported: model.status = .unsupported; return
            @unknown default: break
            }
        }
        if configuration?.source == source, configuration?.target == target {
            configuration?.invalidate()
        } else {
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }
}

extension View {
    /// Attaches the translation driver when the OS supports the Translation framework.
    @ViewBuilder func translationDriver(_ model: ResultModel) -> some View {
        if #available(macOS 15.0, *) { modifier(TranslationDriver(model: model)) } else { self }
    }
}
