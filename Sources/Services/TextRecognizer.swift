import Vision
import NaturalLanguage
import CoreGraphics
import ImageIO

/// A recognized line of text and its normalized Vision bounding box (origin bottom-left).
struct TextBlock: Identifiable {
    let id = UUID()
    let text: String
    let box: CGRect
}

/// Output of OCR: the joined paragraph text plus per-line blocks for overlay mode.
struct RecognitionResult {
    let text: String
    let blocks: [TextBlock]
    let language: String?
}

/// Runs Vision text recognition and NaturalLanguage language detection.
enum TextRecognizer {
    static func recognize(_ image: CGImage, favorites: [AppLanguage]) -> RecognitionResult {
        var blocks = run(image, orientation: .up, favorites: favorites)
        var rotated = false
        if blocks.isEmpty {
            // Vertical text (e.g. Japanese/Chinese columns): retry with a rotated orientation.
            blocks = run(image, orientation: .right, favorites: favorites)
            rotated = true
        }
        let text = joinLines(blocks.map(\.text))
        return RecognitionResult(text: text, blocks: rotated ? [] : blocks,
                                 language: detectLanguage(text, favorites: favorites))
    }

    private static func run(_ image: CGImage, orientation: CGImagePropertyOrientation,
                            favorites: [AppLanguage]) -> [TextBlock] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        if !favorites.isEmpty {
            let supported = Set((try? request.supportedRecognitionLanguages()) ?? [])
            let preferred = favorites.map(\.visionCode).filter { supported.contains($0) }
            if !preferred.isEmpty { request.recognitionLanguages = preferred }
        }
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)
        do { try handler.perform([request]) } catch { return [] }
        return (request.results ?? []).compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : TextBlock(text: text, box: obs.boundingBox)
        }
    }

    /// Joins lines into paragraphs: spaces between wrapped lines, newlines after sentence punctuation.
    static func joinLines(_ lines: [String]) -> String {
        let terminators: Set<Character> = [".", "!", "?", ":", ";", "。", "！", "？", "：", "；", "…"]
        var result = ""
        for (index, line) in lines.enumerated() {
            result += line
            guard index < lines.count - 1 else { break }
            if let last = line.last, terminators.contains(last) { result += "\n" } else { result += " " }
        }
        return result
    }

    static func detectLanguage(_ text: String, favorites: [AppLanguage]) -> String? {
        let recognizer = NLLanguageRecognizer()
        if !favorites.isEmpty {
            var hints: [NLLanguage: Double] = [:]
            for lang in favorites { hints[NLLanguage(rawValue: lang.code)] = 0.6 }
            recognizer.languageHints = hints
        }
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
        return language.rawValue
    }
}
