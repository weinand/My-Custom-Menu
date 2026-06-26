// Handles file picker and drop-import conversion into menu items.
import AppKit
import Foundation
import UniformTypeIdentifiers

final class EditorItemImportService {
    private let fileManager = FileManager.default
    private let acceptedDropTypes = [
        UTType.fileURL.identifier,
        UTType.url.identifier,
        UTType.plainText.identifier,
        UTType.text.identifier,
        "public.utf8-plain-text",
        "public.url-name",
        "public.html"
    ]

    func chooseFileSystemURLs() -> [URL]? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.title = "Choose Files, Folders, or Apps"

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.urls
    }

    func makeMenuItems(from urls: [URL]) -> [MenuItemDefinition] {
        urls.map { url in
            MenuItemDefinition(
                title: suggestedTitle(for: url),
                path: storedPath(for: url),
                bookmarkData: bookmarkData(for: url)
            )
        }
    }

    func makeMenuItem(fromURLString text: String) -> MenuItemDefinition? {
        guard let url = parsedURL(from: text) else {
            return nil
        }

        return makeMenuItems(from: [url]).first
    }

    var supportedDropTypeIdentifiers: [String] {
        acceptedDropTypes
    }

    func loadDroppedItemURLs(
        from providers: [NSItemProvider],
        onURL: @escaping (URL) -> Void,
        onError: @escaping (String) -> Void
    ) -> Bool {
        let seenLock = NSLock()
        var seenURLStrings = Set<String>()
        let emitUniqueURL: (URL) -> Void = { url in
            seenLock.lock()
            defer { seenLock.unlock() }

            let key = url.absoluteString
            guard seenURLStrings.insert(key).inserted else {
                return
            }

            onURL(url)
        }

        var handledAnyProvider = false

        for provider in providers {
            guard let typeIdentifier = acceptedDropTypes.first(where: {
                provider.hasItemConformingToTypeIdentifier($0)
            }) else {
                continue
            }

            handledAnyProvider = true
            loadURLFromDataRepresentation(
                provider: provider,
                typeIdentifier: typeIdentifier,
                onURL: emitUniqueURL,
                onError: onError
            )
        }

        guard handledAnyProvider else {
            if let fallbackURL = urlFromDraggingPasteboard() {
                emitUniqueURL(fallbackURL)
                return true
            }

            onError(
                "Unsupported drop type(s): \(providerTypeSummary(for: providers)). Supported: \(acceptedDropTypes.joined(separator: ", "))."
            )
            return false
        }

        return true
    }

    private func loadURLFromDataRepresentation(
        provider: NSItemProvider,
        typeIdentifier: String,
        onURL: @escaping (URL) -> Void,
        onError: @escaping (String) -> Void
    ) {
        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
            guard let data else {
                if let error {
                    onError(error.localizedDescription)
                } else {
                    onError(
                        "Drop payload was empty for type '\(typeIdentifier)'. Provider types: \(self.providerTypeSummary(for: [provider]))."
                    )
                }
                return
            }

            if let url = URL(dataRepresentation: data, relativeTo: nil) {
                onURL(url)
                return
            }

            if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                    let url = self.parsedURL(from: text) {
                onURL(url)
                return
            }

            onError(
                "Dropped item is not a valid URL. Provider types: \(self.providerTypeSummary(for: [provider]))."
            )
        }
    }

    private func providerTypeSummary(for providers: [NSItemProvider]) -> String {
        let identifiers = providers.flatMap(\.registeredTypeIdentifiers)
        guard !identifiers.isEmpty else {
            return "(none)"
        }

        return identifiers.joined(separator: ", ")
    }

    private func urlFromDraggingPasteboard() -> URL? {
        let dragPasteboard = NSPasteboard(name: .drag)

        if let urlString = dragPasteboard.string(forType: .URL),
           let url = parsedURL(from: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }

        if let text = dragPasteboard.string(forType: .string),
           let url = parsedURL(from: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }

        return nil
    }

    private func suggestedTitle(for url: URL) -> String {
        guard url.isFileURL else {
            return url.host ?? url.absoluteString
        }

        let displayName = fileManager.displayName(atPath: url.path)
        let pathExtension = url.pathExtension

        guard !pathExtension.isEmpty else {
            return displayName
        }

        let extensionSuffix = ".\(pathExtension)"
        guard displayName.hasSuffix(extensionSuffix) else {
            return displayName
        }

        return String(displayName.dropLast(extensionSuffix.count))
    }

    private func storedPath(for url: URL) -> String {
        if url.isFileURL {
            return url.path
        }

        return url.absoluteString
    }

    private func parsedURL(from text: String) -> URL? {
        guard !text.isEmpty,
              let url = URL(string: text),
              url.scheme != nil else {
            return nil
        }

        return url
    }

    private func bookmarkData(for url: URL) -> Data? {
        guard url.isFileURL else {
            return nil
        }

        return try? url.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
