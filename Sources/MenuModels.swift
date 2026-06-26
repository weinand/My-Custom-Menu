// Defines Codable models for persisted menu configuration, groups, and items.
import Foundation

struct MenuConfiguration: Codable {
    var menuTitle: String
    var groups: [MenuGroupDefinition]

    static let `default` = MenuConfiguration(
        menuTitle: "MCM",
        groups: []
    )
}

struct MenuGroupDefinition: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var items: [MenuItemDefinition]

    init(id: UUID = UUID(), title: String, items: [MenuItemDefinition] = []) {
        self.id = id
        self.title = title
        self.items = items
    }
}

struct MenuItemDefinition: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var path: String
    var bookmarkData: Data?

    init(id: UUID = UUID(), title: String, path: String, bookmarkData: Data? = nil) {
        self.id = id
        self.title = title
        self.path = path
        self.bookmarkData = bookmarkData
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case path
        case bookmarkData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)

        if let persistedPath = try container.decodeIfPresent(String.self, forKey: .path) {
            path = persistedPath
            return
        }

        if bookmarkData != nil {
            path = ""
            return
        }

        throw DecodingError.keyNotFound(
            CodingKeys.path,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing required key 'path'.")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
    }

    func resolvedURL() -> URL? {
        if let bookmarkData,
           let bookmarkURL = resolveBookmarkURL(from: bookmarkData) {
            return bookmarkURL
        }

        guard !path.isEmpty else {
            return nil
        }

        if let parsedURL = URL(string: path), parsedURL.isFileURL || path.contains("://") {
            return parsedURL
        }

        return URL(fileURLWithPath: path)
    }

    func resolvedFilePath() -> String? {
        guard let url = resolvedURL(), url.isFileURL else {
            return nil
        }

        return url.path
    }

    private func resolveBookmarkURL(from bookmarkData: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
