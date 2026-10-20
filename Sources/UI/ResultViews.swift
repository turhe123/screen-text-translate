import SwiftUI
import AppKit

/// Floating card with the original text, translation, language badge and copy actions.
struct ResultCardView: View {
    @ObservedObject var model: ResultModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.sourceName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $model.targetLanguage) {
                    ForEach(AppLanguage.all) { Text($0.name).tag($0.code) }
                }
                .labelsHidden().fixedSize()
                Spacer()
            }
            ScrollView {
                Text(model.original)
                    .font(.callout).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 90)
            Divider()
            statusSection
            HStack {
                Button("Copy Original") { Pasteboard.copy(model.original) }
                Button("Copy Translation") { if let t = model.translation { Pasteboard.copy(t) } }
                    .disabled(model.translation == nil)
                Spacer()
                Button("Close") { model.onClose?() }.keyboardShortcut(.cancelAction)
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 400)
        .translationDriver(model)
    }

    @ViewBuilder private var statusSection: some View {
        switch model.status {
        case .translating:
            HStack { ProgressView().controlSize(.small); Text("Translating…").foregroundStyle(.secondary) }
        case .done:
            ScrollView {
                Text(model.translation ?? "")
                    .font(.body).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 40, maxHeight: 220)
        case .sameLanguage:
            Label("Text is already in \(AppLanguage.displayName(for: model.targetLanguage)).", systemImage: "checkmark.circle")
                .font(.callout).foregroundStyle(.secondary)
        case .needsDownload:
            HStack {
                Label("Language pack not installed.", systemImage: "arrow.down.circle")
                Spacer()
                Button("Download Language") { model.downloadLanguage() }
            }
        case .unsupported:
            Label("This language pair isn't supported for on-device translation.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        case .unavailableOS:
            VStack(alignment: .leading, spacing: 6) {
                Label("Translation requires macOS 15 or newer. You can still copy the text or look it up.",
                      systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Look Up in Dictionary") { lookUp(model.original) }
            }
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon").foregroundStyle(.red)
        }
    }

    private func lookUp(_ text: String) {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ScreenTextTranslateLookUp"))
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        if !NSPerformService("Look Up in Dictionary", pasteboard),
           let query = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "dict://\(query)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Snapshot of the captured region with translated text painted over each recognized line.
struct OverlayResultView: View {
    @ObservedObject var model: ResultModel
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let image = model.image {
                Image(decorative: image, scale: 1).resizable().frame(width: size.width, height: size.height)
            }
            ForEach(model.blocks) { block in
                let frame = CGRect(x: block.box.minX * size.width, y: (1 - block.box.maxY) * size.height,
                                   width: block.box.width * size.width, height: block.box.height * size.height)
                Text(model.blockTranslations[block.id] ?? block.text)
                    .font(.system(size: max(8, frame.height * 0.8)))
                    .minimumScaleFactor(0.3).lineLimit(1)
                    .foregroundStyle(.black)
                    .frame(width: frame.width + 6, height: frame.height + 2, alignment: .leading)
                    .background(Color.white.opacity(0.92))
                    .offset(x: frame.minX - 3, y: frame.minY - 1)
            }
            HStack(spacing: 4) {
                if model.status == .translating { ProgressView().controlSize(.mini) }
                Button { if let t = model.translation { Pasteboard.copy(t) } } label: { Image(systemName: "doc.on.doc") }
                    .help("Copy Translation")
                Button { model.onClose?() } label: { Image(systemName: "xmark") }.help("Close")
            }
            .buttonStyle(.borderless).padding(4)
            .background(.regularMaterial, in: Capsule())
            .frame(width: size.width, height: size.height, alignment: .topTrailing)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .translationDriver(model)
    }
}

/// Small toast shown when no text was recognized.
struct NoTextView: View {
    var body: some View {
        Label("No text detected", systemImage: "text.viewfinder")
            .padding(.horizontal, 16).padding(.vertical, 10)
    }
}
